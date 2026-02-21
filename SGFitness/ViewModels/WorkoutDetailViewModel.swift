import Foundation
import SwiftData
import Observation

// MARK: - WorkoutDetailViewModel
// Displays a single completed session with full drill-down.
// Supports edit mode for correcting past data.

@Observable
final class WorkoutDetailViewModel {

    private let modelContext: ModelContext

    /// The session being viewed/edited.
    let session: WorkoutSession

    /// Read vs edit mode toggle. UI-only.
    var isEditing: Bool = false

    /// Exercises sorted by order.
    var exercises: [ExerciseSession] {
        session.exercises.sorted { $0.order < $1.order }
    }

    /// Stretches sorted by order.
    var stretches: [StretchEntry] {
        session.stretches.sorted { $0.order < $1.order }
    }

    /// Workout duration derived from timestamps.
    var duration: TimeInterval {
        guard let completedAt = session.completedAt else { return 0 }
        return completedAt.timeIntervalSince(session.startedAt)
    }

    /// Sum of (reps * weight) across all completed sets.
    var totalVolume: Double {
        exercises.flatMap(\.performedSets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + Double($1.reps) * ($1.weight ?? 0) }
    }

    /// Template name if this session was based on one.
    var templateName: String? {
        session.template?.name
    }

    /// User's preferred weight display unit, derived from the session owner.
    var preferredWeightUnit: WeightUnit {
        session.user?.preferredWeightUnit ?? .kg
    }

    init(modelContext: ModelContext, session: WorkoutSession) {
        self.modelContext = modelContext
        self.session = session
    }

    func toggleEditing() {
        isEditing.toggle()
    }

    func updateSet(_ set: PerformedSet, reps: Int, weight: Double?) {
        set.reps = reps
        set.weight = weight
        session.updatedAt = .now
    }

    /// Append a completed set to the given exercise.
    func addSet(to exercise: ExerciseSession, reps: Int, weight: Double?) {
        let nextOrder = exercise.performedSets.map(\.order).max().map { $0 + 1 } ?? 0
        let set = PerformedSet(
            order: nextOrder,
            reps: reps,
            weight: weight,
            isCompleted: true,
            completedAt: .now,
            exerciseSession: exercise
        )
        modelContext.insert(set)
        session.updatedAt = .now
    }

    /// Delete a set and recompute contiguous order on survivors.
    func removeSet(_ set: PerformedSet) {
        guard let exercise = set.exerciseSession else { return }
        let remaining = exercise.performedSets
            .filter { $0.id != set.id }
            .sorted { $0.order < $1.order }
        modelContext.delete(set)
        for (newOrder, s) in remaining.enumerated() { s.order = newOrder }
        session.updatedAt = .now
    }

    /// Add an exercise from the catalog to this session.
    func addExercise(from definition: ExerciseDefinition) {
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

    /// Delete an exercise and all its sets, recomputing order on survivors.
    func removeExercise(_ exercise: ExerciseSession) {
        let remaining = exercises.filter { $0.id != exercise.id }
        modelContext.delete(exercise)
        for (newOrder, ex) in remaining.enumerated() { ex.order = newOrder }
        session.updatedAt = .now
    }

    func updateEffort(_ exercise: ExerciseSession, effort: Int) {
        exercise.effort = max(1, min(effort, 10))
        session.updatedAt = .now
    }

    func updateNotes(_ notes: String) {
        session.notes = notes
        session.updatedAt = .now
    }

    func save() {
        session.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            print("[WorkoutDetailViewModel] Failed to save: \(error)")
        }
    }

    /// Create a new WorkoutTemplate from this session's exercises and sets.
    /// The template owner is derived from the session's user relationship.
    func saveAsTemplate() {
        guard let owner = session.user else { return }

        let template = WorkoutTemplate(name: session.name, owner: owner)
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

        for (i, stretchEntry) in stretches.enumerated() {
            let stretchGoal = StretchGoal(
                name: stretchEntry.name,
                targetDurationSeconds: stretchEntry.durationSeconds,
                order: i,
                workoutTemplate: template
            )
            modelContext.insert(stretchGoal)
        }

        save()
    }
}
