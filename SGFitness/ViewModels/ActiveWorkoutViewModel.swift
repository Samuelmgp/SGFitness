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

@Observable
final class ActiveWorkoutViewModel {

    // MARK: - Dependencies

    // `let` constants are not tracked by @Observable — reading these in a
    // view won't subscribe to changes (there are none to subscribe to).
    private let modelContext: ModelContext
    private let user: User

    // MARK: - Persisted State

    /// The live workout session. Nil before `start*()` is called.
    /// `private(set)` because only this ViewModel creates and clears the session;
    /// views read it but never assign it.
    private(set) var session: WorkoutSession?

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

    /// Whether the workout has been completed (completedAt is non-nil).
    var isFinished: Bool {
        session?.completedAt != nil
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
    func startFromTemplate(_ template: WorkoutTemplate) {
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

        self.session = session

        // Explicit save after the batch insert. SwiftData auto-saves on
        // scene-phase transitions, but if the app crashes mid-workout
        // before the first auto-save, the session would be lost. This
        // ensures the initial state is durable immediately.
        persistChanges()

        startElapsedTimer()
    }

    /// Start a blank ad-hoc workout with no pre-populated exercises.
    /// The user will add exercises manually via addExercise(from:).
    func startAdHoc(name: String) {
        let session = WorkoutSession(
            name: name,
            user: user
        )
        modelContext.insert(session)

        self.session = session
        persistChanges()
        startElapsedTimer()
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
    func completeSet(_ set: PerformedSet, reps: Int, weight: Double?) {
        set.reps = reps
        set.weight = weight
        set.isCompleted = true
        set.completedAt = .now
        session?.updatedAt = .now

        if let exercise = set.exerciseSession {
            autoStartRestTimer(for: exercise)
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

        // Freeze elapsed time so the UI shows a stable number after the
        // timer stops. Without this, elapsedTime would show whatever value
        // was computed on the last tick before stopElapsedTimer().
        elapsedTime = now.timeIntervalSince(session.startedAt)

        stopRestTimer()
        stopElapsedTimer()

        // Explicit save: the completed session should be durable immediately.
        // If the app crashes after this point, the workout is preserved.
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
