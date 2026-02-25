import Foundation
import SwiftUI
import SwiftData
import Observation

// MARK: - ActiveWorkoutViewModel
//
// Manages a single live workout session from start to finish.
//
// This is the most interaction-heavy ViewModel in the app. During a workout
// the user is tapping rapidly between sets, so the API is designed for minimal
// friction: logSet() is a single call that creates the PerformedSet, timestamps
// it, and auto-starts the rest timer.
//
// Two entry points:
//   - startFromTemplate(_:) — copies a template's exercises and set goals
//     into new session objects. The user can deviate freely.
//   - startAdHoc(name:) — creates an empty session with no exercises.
//
// Timer state (rest countdown, elapsed time) is purely UI-only and never
// persisted. If the app is killed mid-workout, the session persists
// (completedAt == nil) but timers reset on relaunch.
//
// Concurrency model:
//   This class is implicitly @MainActor via SWIFT_DEFAULT_ACTOR_ISOLATION.
//   All property access and method calls happen on the main actor.
//   Timer.scheduledTimer callbacks fire on the main run loop (== main thread
//   == MainActor), so they can safely mutate observed properties without
//   explicit dispatch.
//
// Observation model:
//   Uses @Observable (iOS 17+) for per-property view invalidation.
//   Views that only read `restTimerRemaining` won't re-render when
//   `elapsedTime` ticks — unlike ObservableObject which would fire
//   objectWillChange for any @Published mutation.
//
// Persistence model:
//   All model writes go through the injected ModelContext.
//   Explicit save() calls are made after batch operations (session creation,
//   finish, discard) for crash safety. Individual set/effort mutations rely
//   on SwiftData's auto-save on scene-phase transitions.

// MARK: - PR Support Types

struct PRBaseline {
    var maxWeightKg: Double?
    /// Highest reps recorded at maxWeightKg across all past sessions.
    /// Used to detect PRs when weight ties but reps increase.
    var maxRepsAtMaxWeight: Int?
    var bestVolumeKg: Double?
}

struct PRAlert: Equatable {
    var exerciseName: String
    var metric: String
}

@Observable
final class ActiveWorkoutViewModel: Identifiable {

    // MARK: - Dependencies

    // `let` constants are not tracked by @Observable — reading these in a
    // view won't subscribe to changes (there are none to subscribe to).
    let id = UUID()
    private let modelContext: ModelContext
    private let user: User

    // MARK: - Persisted State

    /// The live workout session. Nil before `start*()` is called.
    /// `private(set)` because only this ViewModel creates and clears the session;
    /// views read it but never assign it.
    private(set) var session: WorkoutSession?

    /// Optional link to a scheduled workout that triggered this session.
    private var scheduledWorkout: ScheduledWorkout?

    // MARK: - UI-Only State
    //
    // None of these properties are persisted. They exist solely to drive
    // the SwiftUI view layer during an active workout.

    /// Index of the exercise the user is currently focused on.
    /// The view uses this to scroll-to and highlight the active exercise card.
    /// Writable by the view (e.g. on tap) so it's not `private(set)`.
    var currentExerciseIndex: Int = 0

    /// Seconds remaining on the rest timer. 0 when inactive.
    private(set) var restTimerRemaining: Int = 0

    /// Whether the rest timer is actively counting down.
    /// Separate from `restTimerRemaining > 0` so the view can distinguish
    /// "timer finished naturally" (remaining == 0, running == false) from
    /// "no timer was ever started."
    private(set) var restTimerIsRunning: Bool = false

    /// Elapsed wall-clock time since workout started, in seconds.
    /// Recomputed from `session.startedAt` on every tick so it stays
    /// accurate even after app backgrounding or timer drift.
    /// The 1-second timer is just a trigger for the UI to re-read this value.
    private(set) var elapsedTime: TimeInterval = 0

    // MARK: - Timer Internals
    //
    // @ObservationIgnored prevents the observation system from tracking these.
    // The view never reads the Timer objects directly — it reads the derived
    // values (restTimerRemaining, elapsedTime). Without this annotation,
    // setting `restTimer = Timer.scheduled...` would trigger a view update
    // even though no visible state changed.

    @ObservationIgnored private var restTimer: Timer?
    @ObservationIgnored private var elapsedTimer: Timer?

    // MARK: - PR Detection State

    /// Pre-workout baselines keyed by ExerciseDefinition.id.
    /// Loaded lazily when an exercise is added. @ObservationIgnored because
    /// views never read this dictionary directly.
    @ObservationIgnored private var prBaselines: [UUID: PRBaseline] = [:]

    /// Non-nil when the user just set a new PR. The view observes this
    /// and clears it after showing the banner.
    private(set) var latestPRAlert: PRAlert?

    // MARK: - Refresh Trigger
    //
    // SwiftData relationship mutations (inserting/deleting child objects) do not
    // reliably fire @Observable notifications on the parent ViewModel because the
    // change is on the child's relationship, not a direct property of this object.
    // Incrementing this counter forces any view that reads it to re-render.

    var refreshCounter: Int = 0

    // MARK: - User Preferences

    /// The user's preferred weight display unit. Read by the view layer for conversions.
    var preferredWeightUnit: WeightUnit { user.preferredWeightUnit }

    /// When true, this session is a manual log (no live timer). The user will
    /// provide the workout duration explicitly when finishing.
    private(set) var isManualEntry: Bool = false

    // MARK: - Derived Properties

    /// Exercises in display order.
    ///
    /// SwiftData does not guarantee the order of relationship arrays
    /// (`session.exercises` may return elements in any order). We always
    /// sort by the explicit `order` field that we maintain ourselves.
    /// This computed property re-evaluates on every access, which is fine
    /// because a workout typically has 5–8 exercises.
    var exercises: [ExerciseSession] {
        guard let session else { return [] }
        return session.exercises.sorted { $0.order < $1.order }
    }

    /// Stretches in display order.
    var stretches: [StretchEntry] {
        guard let session else { return [] }
        return session.stretches.sorted { $0.order < $1.order }
    }

    /// Whether the workout has been completed (completedAt is non-nil).
    var isFinished: Bool {
        session?.completedAt != nil
    }

    /// Target workout duration in seconds, if set on the session.
    var targetDurationSeconds: TimeInterval? {
        guard let minutes = session?.targetDurationMinutes else { return nil }
        return TimeInterval(minutes * 60)
    }

    // MARK: - Init

    /// - Parameters:
    ///   - modelContext: The SwiftData context for all persistence operations.
    ///   - user: The current user, used to associate the session with an owner.
    init(modelContext: ModelContext, user: User) {
        self.modelContext = modelContext
        self.user = user
    }

    deinit {
        // Invalidate timers to prevent zombie callbacks after deallocation.
        // Safe to call here because:
        // 1. The VM is owned by a SwiftUI view and deallocated on the main thread.
        // 2. The timers were scheduled on the main run loop (same thread).
        // 3. Under SWIFT_VERSION = 5.0, nonisolated deinit can access
        //    MainActor-isolated stored properties without compiler errors.
        restTimer?.invalidate()
        elapsedTimer?.invalidate()
    }

    // MARK: - Starting a Workout

    /// Start a workout by copying a template's structure into a new session.
    ///
    /// This is the primary entry point when the user taps "Start Workout"
    /// on a template. The copy process works in three layers:
    ///
    /// 1. **WorkoutSession** — created from the template's name/notes,
    ///    linked to the user and (optionally) back to the template.
    ///
    /// 2. **ExerciseSession** — one per ExerciseTemplate, copying name,
    ///    notes, order, and restSeconds. Also links to the same
    ///    ExerciseDefinition for progress tracking continuity.
    ///
    /// 3. **PerformedSet** — one per SetGoal, pre-populated with the
    ///    target reps/weight but marked `isCompleted = false`. This lets
    ///    the user tap through their planned sets one-by-one rather than
    ///    entering everything from scratch.
    ///
    /// The session is fully independent of the template after creation.
    /// Editing the template later does NOT change this session's data.
    /// The `session.template` back-reference is informational only (and
    /// nullified if the template is deleted).
    func startFromTemplate(_ template: WorkoutTemplate, scheduledWorkout: ScheduledWorkout? = nil) {
        self.scheduledWorkout = scheduledWorkout
        // 1. Create the session shell.
        let session = WorkoutSession(
            name: template.name,
            notes: template.notes,
            user: user,
            template: template
        )
        modelContext.insert(session)

        // 2. Copy exercises in order.
        // Sort first — SwiftData relationship arrays have no guaranteed order.
        let sortedExercises = template.exercises.sorted { $0.order < $1.order }

        for templateExercise in sortedExercises {
            let exerciseSession = ExerciseSession(
                name: templateExercise.name,
                notes: templateExercise.notes,
                order: templateExercise.order,
                restSeconds: templateExercise.restSeconds,
                workoutSession: session,
                exerciseTemplate: templateExercise
            )
            // Link the canonical ExerciseDefinition so progress queries
            // ("show me all bench press sessions") work across the template
            // and session graphs via a shared identity.
            exerciseSession.exerciseDefinition = templateExercise.exerciseDefinition
            modelContext.insert(exerciseSession)

            // 3. Copy set goals into pre-populated PerformedSets.
            let sortedGoals = templateExercise.setGoals.sorted { $0.order < $1.order }
            for goal in sortedGoals {
                let performedSet = PerformedSet(
                    order: goal.order,
                    reps: goal.targetReps,
                    weight: goal.targetWeight,
                    isCompleted: false,     // Not done yet — user must confirm.
                    exerciseSession: exerciseSession
                )
                modelContext.insert(performedSet)
            }
        }

        // Copy stretch goals into pre-populated StretchEntries.
        let sortedStretchGoals = template.stretches.sorted { $0.order < $1.order }
        for goal in sortedStretchGoals {
            let stretchEntry = StretchEntry(
                name: goal.name,
                durationSeconds: goal.targetDurationSeconds,
                order: goal.order,
                workoutSession: session
            )
            modelContext.insert(stretchEntry)
        }

        // Copy the template's target duration so the timer ring knows the goal.
        // Fall back to the user's default session duration goal if the template has none.
        session.targetDurationMinutes = template.targetDurationMinutes ?? user.targetWorkoutMinutes

        self.session = session

        // Explicit save after the batch insert. SwiftData auto-saves on
        // scene-phase transitions, but if the app crashes mid-workout
        // before the first auto-save, the session would be lost. This
        // ensures the initial state is durable immediately.
        persistChanges()

        startElapsedTimer()

        // Load pre-workout baselines for all exercises for live PR detection.
        for exerciseSession in exercises {
            loadBaseline(for: exerciseSession)
        }
    }

    /// Start a blank ad-hoc workout with no pre-populated exercises.
    /// The user will add exercises manually via addExercise(from:).
    func startAdHoc(name: String) {
        let session = WorkoutSession(
            name: name,
            user: user
        )
        session.targetDurationMinutes = user.targetWorkoutMinutes
        modelContext.insert(session)

        self.session = session
        persistChanges()
        startElapsedTimer()
    }

    /// Start a manual-entry workout: same as ad-hoc but the timer does not run.
    /// The user provides the final duration when calling finishWorkout(manualDurationMinutes:).
    /// - Parameters:
    ///   - name: Display name for the session.
    ///   - startedAt: When the workout took place. Defaults to now; pass a past
    ///     date when the user is logging a workout after the fact.
    func startManualEntry(name: String, startedAt: Date = .now) {
        let session = WorkoutSession(name: name, startedAt: startedAt, user: user)
        session.targetDurationMinutes = user.targetWorkoutMinutes
        modelContext.insert(session)
        self.session = session
        isManualEntry = true
        persistChanges()
        // Timer intentionally not started — user will supply duration on finish.
    }

    /// Start a manual-entry workout pre-populated from a template's exercise structure.
    /// Copies exercises, set goals, and stretches exactly like startFromTemplate(), but
    /// does NOT start the elapsed timer and does NOT load PR baselines (manual entry).
    /// - Parameters:
    ///   - template: The template whose structure to copy.
    ///   - name: Display name for the session (may differ from the template's name).
    ///   - startedAt: When the workout took place.
    func startManualEntryFromTemplate(_ template: WorkoutTemplate, name: String, startedAt: Date) {
        let session = WorkoutSession(
            name: name,
            notes: template.notes,
            startedAt: startedAt,
            user: user,
            template: template
        )
        modelContext.insert(session)

        let sortedExercises = template.exercises.sorted { $0.order < $1.order }
        for templateExercise in sortedExercises {
            let exerciseSession = ExerciseSession(
                name: templateExercise.name,
                notes: templateExercise.notes,
                order: templateExercise.order,
                restSeconds: templateExercise.restSeconds,
                workoutSession: session,
                exerciseTemplate: templateExercise
            )
            exerciseSession.exerciseDefinition = templateExercise.exerciseDefinition
            modelContext.insert(exerciseSession)

            let sortedGoals = templateExercise.setGoals.sorted { $0.order < $1.order }
            for goal in sortedGoals {
                // All sets start as completed in a manual-entry-from-template session.
                // The user can de-select any set they didn't actually perform.
                let performedSet = PerformedSet(
                    order: goal.order,
                    reps: goal.targetReps,
                    weight: goal.targetWeight,
                    isCompleted: true,
                    completedAt: startedAt,
                    exerciseSession: exerciseSession
                )
                modelContext.insert(performedSet)
            }
        }

        let sortedStretchGoals = template.stretches.sorted { $0.order < $1.order }
        for goal in sortedStretchGoals {
            let stretchEntry = StretchEntry(
                name: goal.name,
                durationSeconds: goal.targetDurationSeconds,
                order: goal.order,
                workoutSession: session
            )
            modelContext.insert(stretchEntry)
        }

        session.targetDurationMinutes = template.targetDurationMinutes ?? user.targetWorkoutMinutes

        self.session = session
        isManualEntry = true
        persistChanges()
        // Timer intentionally not started — user will supply duration on finish.
        // PR baselines are not loaded — no live PR detection in manual entry.
    }

    // MARK: - Exercise Management

    /// Add a new exercise to the session from the exercise catalog.
    ///
    /// Appended at the end — order is set to one past the current maximum.
    /// The exercise starts with zero sets; the user adds them via logSet().
    func addExercise(from definition: ExerciseDefinition) {
        guard let session else { return }

        // Compute next order from the current max. Using the sorted array's
        // last element is O(n) but n ≤ ~10 exercises, so this is fine.
        let nextOrder = exercises.last.map { $0.order + 1 } ?? 0

        let exerciseSession = ExerciseSession(
            name: definition.name,
            order: nextOrder,
            workoutSession: session
        )
        exerciseSession.exerciseDefinition = definition
        modelContext.insert(exerciseSession)

        session.updatedAt = .now
        refreshCounter += 1

        // Load pre-workout baseline for live PR detection.
        loadBaseline(for: exerciseSession)
    }

    /// Remove an exercise at the given display index.
    ///
    /// After deletion, remaining exercises have their `order` values
    /// recomputed to stay contiguous (0, 1, 2, ...). This prevents gaps
    /// that would confuse sorting. SwiftData cascade-deletes the exercise's
    /// PerformedSets automatically via the relationship delete rule.
    func removeExercise(at index: Int) {
        guard let session else { return }

        let sorted = exercises
        guard sorted.indices.contains(index) else { return }

        let target = sorted[index]

        // Capture the survivors BEFORE deleting from the context.
        // After modelContext.delete(), the target may become a fault and
        // its id could behave unpredictably in comparisons.
        let remaining = sorted.filter { $0.id != target.id }

        modelContext.delete(target)

        // Recompute contiguous order values on survivors.
        for (newOrder, exercise) in remaining.enumerated() {
            exercise.order = newOrder
        }

        // Clamp the focused exercise index so it doesn't point past the end.
        if currentExerciseIndex >= remaining.count {
            currentExerciseIndex = max(0, remaining.count - 1)
        }

        session.updatedAt = .now
        refreshCounter += 1
    }

    /// Move an exercise from one display position to another.
    ///
    /// Updates `order` on all affected exercises. This is called from
    /// List's .onMove modifier, which provides source and destination
    /// indices in the sorted array.
    func reorderExercise(from source: Int, to destination: Int) {
        guard session != nil else { return }
        guard source != destination else { return }

        var sorted = exercises
        guard sorted.indices.contains(source) else { return }

        // Clamp destination to valid range (List.onMove can pass count as destination).
        let clamped = min(destination, sorted.count - 1)

        let moving = sorted.remove(at: source)
        sorted.insert(moving, at: clamped)

        // Rewrite order on every element. This is O(n) but n ≤ ~10 exercises.
        for (newOrder, exercise) in sorted.enumerated() {
            exercise.order = newOrder
        }

        session?.updatedAt = .now
    }

    // MARK: - Set Logging

    /// Log a brand-new completed set on the exercise at `exerciseIndex`.
    ///
    /// Creates a new PerformedSet, marks it completed, timestamps it, and
    /// auto-starts the rest timer if the exercise has a configured rest
    /// duration. This is the primary "one-tap log" path during a workout.
    ///
    /// - Parameters:
    ///   - exerciseIndex: Index into the `exercises` array (sorted by order).
    ///   - reps: Number of reps completed.
    ///   - weight: Weight used, in kilograms (canonical storage unit).
    ///     The view layer converts from the user's preferred display unit
    ///     (via `User.preferredWeightUnit`) before calling this method.
    ///     Pass nil for bodyweight exercises.
    func logSet(exerciseIndex: Int, reps: Int, weight: Double?) {
        let sorted = exercises
        guard sorted.indices.contains(exerciseIndex) else { return }

        let exercise = sorted[exerciseIndex]

        // Next order = one past the current max. If no sets exist yet, start at 0.
        let nextOrder = exercise.performedSets
            .map(\.order)
            .max()
            .map { $0 + 1 } ?? 0

        let set = PerformedSet(
            order: nextOrder,
            reps: reps,
            weight: weight,
            isCompleted: true,
            completedAt: .now,
            exerciseSession: exercise
        )
        modelContext.insert(set)
        session?.updatedAt = .now

        // Auto-start the rest timer so the user doesn't have to tap again.
        // If the exercise has no rest duration configured, this is a no-op.
        autoStartRestTimer(for: exercise)

        // Check if this set is a new personal record.
        checkForPR(exerciseIndex: exerciseIndex, reps: reps, weight: weight)
    }

    /// Log a cardio set (distance + duration) on the exercise at `exerciseIndex`.
    ///
    /// - Parameters:
    ///   - exerciseIndex: Index into the `exercises` array (sorted by order).
    ///   - distanceMeters: Distance in meters (stored in the `reps` field).
    ///   - durationSeconds: Elapsed time in seconds.
    func logSet(exerciseIndex: Int, distanceMeters: Int, durationSeconds: Int) {
        let sorted = exercises
        guard sorted.indices.contains(exerciseIndex) else { return }

        let exercise = sorted[exerciseIndex]
        let nextOrder = exercise.performedSets
            .map(\.order)
            .max()
            .map { $0 + 1 } ?? 0

        let set = PerformedSet(
            order: nextOrder,
            reps: distanceMeters,
            weight: nil,
            isCompleted: true,
            completedAt: .now,
            exerciseSession: exercise
        )
        set.durationSeconds = durationSeconds
        modelContext.insert(set)
        session?.updatedAt = .now

        autoStartRestTimer(for: exercise)
    }

    /// Mark a pre-populated set (copied from a SetGoal) as completed.
    ///
    /// When starting from a template, PerformedSets are created with
    /// `isCompleted = false` and pre-filled with the goal's target reps/weight.
    /// The user may adjust the values before confirming. This method stamps
    /// the set as done with the actual reps/weight and starts the rest timer.
    ///
    /// This is a separate path from logSet() because the PerformedSet already
    /// exists — we're updating it, not creating it.
    func completeSet(_ set: PerformedSet, reps: Int, weight: Double?, durationSeconds: Int? = nil) {
        set.reps = reps
        set.weight = weight
        if let dur = durationSeconds {
            set.durationSeconds = dur
        }
        set.isCompleted = true
        set.completedAt = .now
        session?.updatedAt = .now

        if let exercise = set.exerciseSession {
            autoStartRestTimer(for: exercise)

            let sorted = exercises
            if let idx = sorted.firstIndex(where: { $0.id == exercise.id }) {
                checkForPR(exerciseIndex: idx, reps: reps, weight: weight)
            }
        }
    }

    /// Edit an existing set's reps and/or weight.
    ///
    /// Works on both completed and incomplete sets. Does NOT change
    /// the completion status — use completeSet() to mark as done.
    func updateSet(_ set: PerformedSet, reps: Int, weight: Double?) {
        set.reps = reps
        set.weight = weight
        session?.updatedAt = .now
    }

    /// Delete a set and recompute order on the remaining sets.
    ///
    /// After deletion, surviving sets in the same exercise have their
    /// `order` recomputed to stay contiguous. The exercise's relationship
    /// array is the source of truth (filtered to exclude the deleted set).
    func removeSet(_ set: PerformedSet) {
        guard let exercise = set.exerciseSession else { return }

        // Capture survivors before deleting to avoid stale references.
        let remaining = exercise.performedSets
            .filter { $0.id != set.id }
            .sorted { $0.order < $1.order }

        modelContext.delete(set)

        // Recompute contiguous order on survivors.
        for (newOrder, survivingSet) in remaining.enumerated() {
            survivingSet.order = newOrder
        }

        session?.updatedAt = .now
        refreshCounter += 1
    }

    /// Mark a completed set as incomplete (de-select it).
    ///
    /// Used in manual-entry-from-template mode where all sets start as
    /// pre-completed and the user un-checks sets they didn't actually perform.
    func uncompleteSet(_ set: PerformedSet) {
        set.isCompleted = false
        set.completedAt = nil
        session?.updatedAt = .now
    }

    // MARK: - Effort Rating

    /// Set perceived effort (1–10) for the exercise at `exerciseIndex`.
    ///
    /// Values outside 1–10 are clamped to the valid range. The effort
    /// rating is stored on the ExerciseSession, not on individual sets,
    /// because it represents the overall difficulty of the exercise as
    /// a whole during this workout.
    func setEffort(exerciseIndex: Int, effort: Int) {
        let sorted = exercises
        guard sorted.indices.contains(exerciseIndex) else { return }

        sorted[exerciseIndex].effort = max(1, min(effort, 10))
        session?.updatedAt = .now
    }

    // MARK: - Stretch Management

    /// Add a new stretch to the session.
    ///
    /// Appended at the end — order is set to one past the current maximum.
    func addStretch(name: String, durationSeconds: Int? = nil) {
        guard let session else { return }
        let nextOrder = stretches.last.map { $0.order + 1 } ?? 0
        let stretch = StretchEntry(
            name: name,
            durationSeconds: durationSeconds,
            order: nextOrder,
            workoutSession: session
        )
        modelContext.insert(stretch)
        session.updatedAt = .now
    }

    /// Remove a stretch at the given display index and recompute order on survivors.
    func removeStretch(at index: Int) {
        guard let session else { return }
        let sorted = stretches
        guard sorted.indices.contains(index) else { return }

        let target = sorted[index]
        let remaining = sorted.filter { $0.id != target.id }

        modelContext.delete(target)

        for (newOrder, stretch) in remaining.enumerated() {
            stretch.order = newOrder
        }

        session.updatedAt = .now
    }

    /// Update the name and/or hold duration of an existing stretch entry.
    func updateStretch(_ stretch: StretchEntry, name: String, durationSeconds: Int?) {
        stretch.name = name
        stretch.durationSeconds = durationSeconds
        session?.updatedAt = .now
    }

    // MARK: - Rest Timer
    //
    // The rest timer is purely UI state. It counts down seconds for the user
    // and is never persisted. If the app is killed, the timer simply stops.
    // On relaunch, the user can manually start a new rest timer.
    //
    // Implementation: Timer.scheduledTimer on the main run loop. Since this
    // class is implicitly @MainActor (via SWIFT_DEFAULT_ACTOR_ISOLATION),
    // and Timer callbacks on the main run loop execute on the main thread
    // (which IS the MainActor), the callbacks can safely mutate @Observable
    // properties without explicit dispatch.

    /// Start (or restart) the rest timer with the given number of seconds.
    ///
    /// If a timer is already running, it is cancelled and replaced.
    /// When the countdown reaches zero, the timer stops automatically
    /// and `restTimerIsRunning` becomes false.
    func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }

        // Cancel any existing timer before starting a new one.
        stopRestTimer()

        restTimerRemaining = seconds
        restTimerIsRunning = true

        restTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            // [weak self] prevents a retain cycle between Timer and the VM.
            // The guard-let promotes to a strong reference for the duration
            // of this closure body, which is fine — it's a single tick.
            guard let self else { return }
            self.restTimerRemaining -= 1
            if self.restTimerRemaining <= 0 {
                self.stopRestTimer()
            }
        }
    }

    /// Dismiss the rest timer early (user tapped "Skip Rest").
    func skipRestTimer() {
        stopRestTimer()
    }

    /// Auto-start the rest timer from an exercise's configured rest duration.
    /// Called after logging or completing a set. No-op if the exercise has
    /// no rest duration configured (restSeconds == nil or 0).
    private func autoStartRestTimer(for exercise: ExerciseSession) {
        if let restSeconds = exercise.restSeconds, restSeconds > 0 {
            startRestTimer(seconds: restSeconds)
        }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimerRemaining = 0
        restTimerIsRunning = false
    }

    // MARK: - Elapsed Time
    //
    // The elapsed time display is driven by a 1-second repeating timer.
    // On each tick, the value is RECOMPUTED from `Date.now - session.startedAt`
    // rather than accumulated. This approach has two advantages:
    //
    // 1. Accuracy after backgrounding: if the app is suspended for 5 minutes,
    //    the timer won't fire, but the next tick after resuming will show the
    //    correct elapsed time because it's derived from wall-clock timestamps.
    //
    // 2. No drift: accumulated timers drift ~1ms per tick due to scheduling
    //    jitter. Over a 90-minute workout that's ~5 seconds of drift. The
    //    recomputation approach is always accurate to the current second.

    private func startElapsedTimer() {
        guard let session else { return }

        // Set initial value immediately so the UI doesn't flash 00:00 for one frame.
        elapsedTime = Date.now.timeIntervalSince(session.startedAt)

        elapsedTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self, let session = self.session else { return }
            self.elapsedTime = Date.now.timeIntervalSince(session.startedAt)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Finishing / Discarding

    /// Complete the workout.
    ///
    /// Sets `completedAt` on the session, freezes the elapsed time display
    /// at the final value, and stops all timers. After this call, `isFinished`
    /// returns true and the view should transition to a summary/detail state.
    ///
    /// Idempotent: calling on an already-finished workout is a no-op.
    func finishWorkout() {
        guard let session, !isFinished else { return }

        let now = Date.now
        session.completedAt = now
        session.updatedAt = now

        // Mark the scheduled workout as completed if one exists.
        scheduledWorkout?.status = .completed
        scheduledWorkout?.workoutSession = session

        // Freeze elapsed time so the UI shows a stable number after the
        // timer stops. Without this, elapsedTime would show whatever value
        // was computed on the last tick before stopElapsedTimer().
        elapsedTime = now.timeIntervalSince(session.startedAt)

        stopRestTimer()
        stopElapsedTimer()

        // Explicit save: the completed session should be durable immediately.
        // If the app crashes after this point, the workout is preserved.
        persistChanges()

        // Evaluate and store personal records, then calendar status.
        PersonalRecordService(modelContext: modelContext).evaluatePRs(for: session)
        CalendarComputationService(modelContext: modelContext).evaluateSession(session)
    }

    /// Finish a manual-entry workout with a user-supplied duration.
    /// Sets completedAt = startedAt + duration so history shows the correct time.
    func finishWorkout(manualDurationMinutes: Int) {
        guard let session, !isFinished else { return }

        let duration = TimeInterval(max(1, manualDurationMinutes) * 60)
        let completed = session.startedAt.addingTimeInterval(duration)
        session.completedAt = completed
        session.updatedAt = completed
        elapsedTime = duration

        stopRestTimer()
        persistChanges()

        // Evaluate and store personal records, then calendar status.
        PersonalRecordService(modelContext: modelContext).evaluatePRs(for: session)
        CalendarComputationService(modelContext: modelContext).evaluateSession(session)
    }

    /// Save the current workout's exercises as a new template.
    /// - Parameter targetDurationMinutes: Optional target duration in minutes to store on the template.
    func saveAsTemplate(targetDurationMinutes: Int? = nil) {
        guard let session else { return }

        let template = WorkoutTemplate(name: session.name, owner: user)
        template.targetDurationMinutes = targetDurationMinutes
        modelContext.insert(template)

        for (i, exerciseSession) in exercises.enumerated() {
            let exerciseTemplate = ExerciseTemplate(
                name: exerciseSession.name,
                order: i,
                workoutTemplate: template
            )
            exerciseTemplate.exerciseDefinition = exerciseSession.exerciseDefinition
            exerciseTemplate.restSeconds = exerciseSession.restSeconds
            modelContext.insert(exerciseTemplate)

            let completedSets = exerciseSession.performedSets
                .filter(\.isCompleted)
                .sorted { $0.order < $1.order }

            for (j, set) in completedSets.enumerated() {
                let goal = SetGoal(order: j, targetReps: set.reps, exerciseTemplate: exerciseTemplate)
                goal.targetWeight = set.weight
                modelContext.insert(goal)
            }
        }

        // Copy stretch entries to stretch goals so the template preserves the stretch routine.
        for (i, stretchEntry) in stretches.enumerated() {
            let stretchGoal = StretchGoal(
                name: stretchEntry.name,
                targetDurationSeconds: stretchEntry.durationSeconds,
                order: i,
                workoutTemplate: template
            )
            modelContext.insert(stretchGoal)
        }

        persistChanges()
    }

    /// Discard the workout entirely.
    ///
    /// Deletes the session from the SwiftData store. The cascade delete rule
    /// on WorkoutSession → ExerciseSession → PerformedSet handles cleanup
    /// of all child objects automatically.
    ///
    /// Resets all UI state to initial values.
    func discardWorkout() {
        stopRestTimer()
        stopElapsedTimer()

        if let session {
            modelContext.delete(session)
            // Explicit save: ensure the deletion is committed before the
            // UI navigates away. Otherwise the deleted session could
            // briefly reappear if SwiftData hasn't auto-saved yet.
            persistChanges()
        }

        session = nil
        currentExerciseIndex = 0
        elapsedTime = 0
    }

    // MARK: - PR Detection

    /// Load the pre-workout baseline for an exercise so we can detect new PRs during the session.
    private func loadBaseline(for exerciseSession: ExerciseSession) {
        guard let definition = exerciseSession.exerciseDefinition else { return }
        let defId = definition.id
        guard prBaselines[defId] == nil else { return } // already loaded

        // Only strength exercises use weight-based PR tracking.
        guard definition.exerciseType != .cardio else { return }

        let completedSessions = definition.exerciseSessions.filter {
            $0.workoutSession?.completedAt != nil
        }

        var maxWeight: Double?
        var maxRepsAtMaxWeight: Int?
        var bestVolume: Double?

        for session in completedSessions {
            let sets = session.performedSets.filter(\.isCompleted)

            if let sessionMax = sets.compactMap(\.weight).max() {
                if maxWeight == nil || sessionMax > maxWeight! {
                    maxWeight = sessionMax
                    // Reset reps tracking for the new heavier weight.
                    maxRepsAtMaxWeight = sets
                        .filter { abs(($0.weight ?? 0) - sessionMax) < 0.001 }
                        .map(\.reps).max()
                } else if let mw = maxWeight, abs(sessionMax - mw) < 0.001 {
                    // Same max weight — see if this session achieved more reps at that weight.
                    let repsHere = sets
                        .filter { abs(($0.weight ?? 0) - mw) < 0.001 }
                        .map(\.reps).max() ?? 0
                    maxRepsAtMaxWeight = max(maxRepsAtMaxWeight ?? 0, repsHere)
                }
            }

            let vol = sets.reduce(0.0) { $0 + (($1.weight ?? 0) * Double($1.reps)) }
            if vol > 0, (bestVolume == nil || vol > bestVolume!) {
                bestVolume = vol
            }
        }

        prBaselines[defId] = PRBaseline(maxWeightKg: maxWeight, maxRepsAtMaxWeight: maxRepsAtMaxWeight, bestVolumeKg: bestVolume)
    }

    /// Check if the most recent set for the exercise at `exerciseIndex` is a new PR.
    /// Sets `latestPRAlert` if a new max weight or best volume is detected.
    private func checkForPR(exerciseIndex: Int, reps: Int, weight: Double?) {
        let sorted = exercises
        guard sorted.indices.contains(exerciseIndex) else { return }
        let exercise = sorted[exerciseIndex]
        guard let definition = exercise.exerciseDefinition else { return }
        let defId = definition.id
        guard var baseline = prBaselines[defId] else { return }

        // Max weight check — also fires when weight ties but reps increase.
        if let weight = weight, weight > 0 {
            let isNewMaxWeight = baseline.maxWeightKg == nil || weight > baseline.maxWeightKg!
            let isMoreRepsAtSameWeight = baseline.maxWeightKg.map { abs(weight - $0) < 0.001 } == true
                && reps > (baseline.maxRepsAtMaxWeight ?? 0)

            if isNewMaxWeight || isMoreRepsAtSameWeight {
                let unit = preferredWeightUnit
                let displayWeight = unit.fromKilograms(weight)
                let metric = isNewMaxWeight
                    ? "Max weight: \(formatWeightForAlert(displayWeight)) \(unit.rawValue)"
                    : "Max weight: \(formatWeightForAlert(displayWeight)) \(unit.rawValue) × \(reps) reps"
                latestPRAlert = PRAlert(exerciseName: exercise.name, metric: metric)
                if isNewMaxWeight { baseline.maxWeightKg = weight }
                baseline.maxRepsAtMaxWeight = reps
                prBaselines[defId] = baseline
                return
            }
        }

        // Best volume check (sum of completed sets for this exercise so far this session)
        let completedSets = exercise.performedSets.filter(\.isCompleted)
        let sessionVolume = completedSets.reduce(0.0) { total, set in
            guard let w = set.weight else { return total }
            return total + Double(set.reps) * w
        }
        if sessionVolume > 0, (baseline.bestVolumeKg == nil || sessionVolume > baseline.bestVolumeKg!) {
            let unit = preferredWeightUnit
            let displayVolume = unit.fromKilograms(sessionVolume)
            latestPRAlert = PRAlert(
                exerciseName: exercise.name,
                metric: "Best volume: \(formatWeightForAlert(displayVolume)) \(unit.rawValue)"
            )
            baseline.bestVolumeKg = sessionVolume
            prBaselines[defId] = baseline
        }
    }

    /// Called by the view after the PR banner has been displayed.
    func clearPRAlert() {
        latestPRAlert = nil
    }

    private func formatWeightForAlert(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    // MARK: - Persistence Helper

    /// Explicitly saves the ModelContext to disk.
    ///
    /// SwiftData auto-saves on scene-phase transitions (background, inactive)
    /// and when the context is dealloc'd. However, for critical operations
    /// (session creation, finish, discard), an explicit save provides crash
    /// safety: if the app is force-killed before the next auto-save, the
    /// user's workout data is already persisted.
    ///
    /// Individual set/effort mutations intentionally do NOT call this method.
    /// They happen frequently during a workout (every few seconds) and auto-save
    /// is sufficient — the worst case is losing the last ~1-2 sets logged
    /// before a crash, which is an acceptable tradeoff for performance.
    private func persistChanges() {
        do {
            try modelContext.save()
        } catch {
            // In a production app this would be reported to a crash/analytics
            // service. For now, log to the console. The auto-save mechanism
            // will retry on the next scene-phase transition.
            print("[ActiveWorkoutViewModel] Failed to save context: \(error)")
        }
    }
}
