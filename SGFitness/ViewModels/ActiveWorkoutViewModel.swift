import Foundation
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
// Architecture notes:
// - Uses @Observable (iOS 17+) instead of ObservableObject. This gives
//   per-property tracking: views that only read `restTimerRemaining` won't
//   re-render when `elapsedTime` changes.
// - Timer callbacks fire on the main run loop (the run loop they were
//   scheduled on). Since views create this VM on the main thread, the
//   timers are always main-run-loop. No explicit MainActor dispatch needed.
// - All model writes go through the injected ModelContext.

@Observable
final class ActiveWorkoutViewModel {

    // MARK: - Dependencies

    // `let` constants are not tracked by @Observable — no spurious view updates.
    private let modelContext: ModelContext
    private let user: User

    // MARK: - Persisted State

    /// The live workout session. Nil before `start*()` is called.
    private(set) var session: WorkoutSession?

    // MARK: - UI-Only State

    /// Index of the exercise the user is currently focused on.
    /// The view uses this to scroll/highlight the active exercise.
    var currentExerciseIndex: Int = 0

    /// Seconds remaining on the rest timer. 0 when inactive.
    private(set) var restTimerRemaining: Int = 0

    /// Whether the rest timer is actively counting down.
    private(set) var restTimerIsRunning: Bool = false

    /// Elapsed wall-clock time since workout started, in seconds.
    /// Recomputed from `session.startedAt` on every tick so it stays
    /// accurate even after app backgrounding or timer drift.
    private(set) var elapsedTime: TimeInterval = 0

    // MARK: - Timer Internals

    // Excluded from observation — the view never reads these directly.
    // It reads the derived values (restTimerRemaining, elapsedTime) instead.
    @ObservationIgnored private var restTimer: Timer?
    @ObservationIgnored private var elapsedTimer: Timer?

    // MARK: - Derived Properties

    /// Exercises in display order. SwiftData does not guarantee relationship
    /// array ordering, so we always sort by the explicit `order` field.
    var exercises: [ExerciseSession] {
        guard let session else { return [] }
        return session.exercises.sorted { $0.order < $1.order }
    }

    /// Whether the workout has been completed.
    var isFinished: Bool {
        session?.completedAt != nil
    }

    // MARK: - Init

    init(modelContext: ModelContext, user: User) {
        self.modelContext = modelContext
        self.user = user
    }

    deinit {
        // Timer.invalidate() is safe here because the VM is owned by a SwiftUI
        // view and will be deallocated on the main thread — the same thread the
        // timers were scheduled on.
        restTimer?.invalidate()
        elapsedTimer?.invalidate()
    }

    // MARK: - Starting a Workout

    /// Start a workout by copying a template's structure into a new session.
    ///
    /// What gets copied:
    /// - Template name and notes → session name and notes
    /// - Each ExerciseTemplate → an ExerciseSession (same name, order, rest)
    /// - Each SetGoal → a PerformedSet with `isCompleted = false`
    ///
    /// The pre-populated PerformedSets let the user tap through their plan
    /// set-by-set rather than entering reps/weight from scratch each time.
    /// The session holds a reference to the template, but the data is fully
    /// independent — template edits never affect past sessions.
    func startFromTemplate(_ template: WorkoutTemplate) {
        let session = WorkoutSession(
            name: template.name,
            notes: template.notes,
            user: user,
            template: template
        )
        modelContext.insert(session)

        // Sort template exercises by `order` before copying, since SwiftData
        // relationship arrays have no guaranteed order.
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

            // Copy set goals into pre-populated PerformedSets.
            // isCompleted = false marks them as "planned but not yet done."
            let sortedGoals = templateExercise.setGoals.sorted { $0.order < $1.order }
            for goal in sortedGoals {
                let performedSet = PerformedSet(
                    order: goal.order,
                    reps: goal.targetReps,
                    weight: goal.targetWeight,
                    isCompleted: false,
                    exerciseSession: exerciseSession
                )
                modelContext.insert(performedSet)
            }
        }

        self.session = session
        startElapsedTimer()
    }

    /// Start a blank ad-hoc workout with no pre-populated exercises.
    func startAdHoc(name: String) {
        let session = WorkoutSession(
            name: name,
            user: user
        )
        modelContext.insert(session)

        self.session = session
        startElapsedTimer()
    }

    // MARK: - Exercise Management

    /// Add a new exercise from the exercise catalog.
    /// Appended at the end with the next available order index.
    func addExercise(from definition: ExerciseDefinition) {
        guard let session else { return }

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

    /// Remove an exercise and recompute order on the survivors.
    /// SwiftData cascade-deletes the exercise's PerformedSets.
    func removeExercise(at index: Int) {
        guard let session else { return }
        let sorted = exercises
        guard sorted.indices.contains(index) else { return }

        let target = sorted[index]
        modelContext.delete(target)

        // Recompute contiguous order values on remaining exercises.
        let remaining = sorted.filter { $0.id != target.id }
        for (newOrder, exercise) in remaining.enumerated() {
            exercise.order = newOrder
        }

        // Clamp focused index so it doesn't point past the end.
        if currentExerciseIndex >= remaining.count {
            currentExerciseIndex = max(0, remaining.count - 1)
        }

        session.updatedAt = .now
    }

    /// Move an exercise from one position to another.
    /// Only updates `order` on affected rows.
    func reorderExercise(from source: Int, to destination: Int) {
        guard session != nil else { return }
        guard source != destination else { return }

        var sorted = exercises
        guard sorted.indices.contains(source) else { return }

        let clamped = min(destination, sorted.count - 1)
        let moving = sorted.remove(at: source)
        sorted.insert(moving, at: clamped)

        for (newOrder, exercise) in sorted.enumerated() {
            exercise.order = newOrder
        }

        session?.updatedAt = .now
    }

    // MARK: - Set Logging

    /// Log a brand-new completed set on the exercise at `exerciseIndex`.
    ///
    /// Creates a PerformedSet, marks it completed, timestamps it, and
    /// auto-starts the rest timer if the exercise has a configured rest
    /// duration. This is the primary "tap to log" path during a workout.
    ///
    /// Weight is in the canonical storage unit (kg). The view layer converts
    /// from the user's preferred display unit before calling this method.
    func logSet(exerciseIndex: Int, reps: Int, weight: Double?) {
        let sorted = exercises
        guard sorted.indices.contains(exerciseIndex) else { return }

        let exercise = sorted[exerciseIndex]
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

        autoStartRestTimer(for: exercise)
    }

    /// Mark a pre-populated set (copied from a SetGoal) as completed.
    ///
    /// Template-based workouts create PerformedSets with `isCompleted = false`.
    /// When the user finishes the set, this method stamps it as done with
    /// the actual reps/weight and starts the rest timer.
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
    /// Works on both completed and incomplete sets.
    func updateSet(_ set: PerformedSet, reps: Int, weight: Double?) {
        set.reps = reps
        set.weight = weight
        session?.updatedAt = .now
    }

    /// Delete a set and recompute order on the remaining sets.
    func removeSet(_ set: PerformedSet) {
        guard let exercise = set.exerciseSession else { return }

        modelContext.delete(set)

        // Recompute contiguous order on survivors.
        let remaining = exercise.performedSets
            .filter { $0.id != set.id }
            .sorted { $0.order < $1.order }
        for (newOrder, s) in remaining.enumerated() {
            s.order = newOrder
        }

        session?.updatedAt = .now
    }

    // MARK: - Effort Rating

    /// Set perceived effort (1–10) for the exercise at `exerciseIndex`.
    /// Values outside 1–10 are clamped.
    func setEffort(exerciseIndex: Int, effort: Int) {
        let sorted = exercises
        guard sorted.indices.contains(exerciseIndex) else { return }

        sorted[exerciseIndex].effort = max(1, min(effort, 10))
        session?.updatedAt = .now
    }

    // MARK: - Rest Timer
    //
    // Purely UI state. Not persisted. If the app is killed, the timer
    // simply disappears — the user can restart it manually.

    /// Start (or restart) the rest timer with the given number of seconds.
    func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }

        stopRestTimer()
        restTimerRemaining = seconds
        restTimerIsRunning = true

        restTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            self.restTimerRemaining -= 1
            if self.restTimerRemaining <= 0 {
                self.stopRestTimer()
            }
        }
    }

    /// Dismiss the rest timer early (user tapped "Skip").
    func skipRestTimer() {
        stopRestTimer()
    }

    /// Auto-start the rest timer from an exercise's configured rest duration.
    /// Does nothing if the exercise has no rest duration set.
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
    // The elapsed time is recomputed from session.startedAt on every tick
    // rather than accumulated. This approach stays accurate even if:
    // - The app is backgrounded and the timer doesn't fire
    // - The timer drifts slightly over time
    // The 1-second tick is just a trigger for the UI to re-read the value.

    private func startElapsedTimer() {
        guard let session else { return }
        // Set initial value immediately so the UI doesn't show 0 for a frame.
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

    /// Complete the workout. Sets `completedAt`, freezes the elapsed time
    /// display, and stops all timers.
    func finishWorkout() {
        guard let session, !isFinished else { return }

        let now = Date.now
        session.completedAt = now
        session.updatedAt = now

        // Freeze elapsed time at the final value so the UI shows a stable
        // number after the timer stops.
        elapsedTime = now.timeIntervalSince(session.startedAt)

        stopRestTimer()
        stopElapsedTimer()
    }

    /// Discard the workout entirely. Deletes the session from the store.
    /// SwiftData cascade delete handles ExerciseSessions and PerformedSets.
    func discardWorkout() {
        stopRestTimer()
        stopElapsedTimer()

        if let session {
            modelContext.delete(session)
        }

        session = nil
        currentExerciseIndex = 0
        elapsedTime = 0
    }
}
