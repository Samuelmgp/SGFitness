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
