import Foundation
import SwiftData
import Observation

// MARK: - TemplateEditorViewModel
// Full editing of a single template — name, notes, exercises, set goals, ordering.
// Used for both new and existing templates.

@Observable
final class TemplateEditorViewModel {

    private let modelContext: ModelContext

    /// The template being edited.
    let template: WorkoutTemplate

    /// Buffered edit fields — written to the model on save().
    var name: String
    var notes: String

    /// Tracks whether exercises have been modified since last save.
    @ObservationIgnored private var exercisesModified: Bool = false

    /// Exercises sorted by order.
    var exercises: [ExerciseTemplate] {
        template.exercises.sorted { $0.order < $1.order }
    }

    /// Whether buffered values differ from the persisted model.
    var hasUnsavedChanges: Bool {
        name != template.name || notes != template.notes || exercisesModified
    }

    init(modelContext: ModelContext, template: WorkoutTemplate) {
        self.modelContext = modelContext
        self.template = template
        self.name = template.name
        self.notes = template.notes
    }

    func addExercise(from definition: ExerciseDefinition, targetSets: Int, targetReps: Int, targetWeight: Double?) {
        let nextOrder = exercises.last.map { $0.order + 1 } ?? 0

        let exercise = ExerciseTemplate(
            name: definition.name,
            order: nextOrder,
            workoutTemplate: template
        )
        exercise.exerciseDefinition = definition
        modelContext.insert(exercise)

        for i in 0..<targetSets {
            let goal = SetGoal(order: i, targetReps: targetReps, targetWeight: targetWeight, exerciseTemplate: exercise)
            modelContext.insert(goal)
        }

        exercisesModified = true
        persistChanges()
    }

    func removeExercise(at index: Int) {
        let sorted = exercises
        guard sorted.indices.contains(index) else { return }

        let target = sorted[index]
        let remaining = sorted.filter { $0.id != target.id }

        modelContext.delete(target)

        for (newOrder, exercise) in remaining.enumerated() {
            exercise.order = newOrder
        }

        exercisesModified = true
        persistChanges()
    }

    func reorderExercise(from source: Int, to destination: Int) {
        guard source != destination else { return }

        var sorted = exercises
        guard sorted.indices.contains(source) else { return }

        let clamped = min(destination, sorted.count - 1)
        let moving = sorted.remove(at: source)
        sorted.insert(moving, at: clamped)

        for (newOrder, exercise) in sorted.enumerated() {
            exercise.order = newOrder
        }

        exercisesModified = true
    }

    func addSetGoal(to exercise: ExerciseTemplate, reps: Int, weight: Double?) {
        let nextOrder = exercise.setGoals
            .map(\.order)
            .max()
            .map { $0 + 1 } ?? 0

        let goal = SetGoal(order: nextOrder, targetReps: reps, targetWeight: weight, exerciseTemplate: exercise)
        modelContext.insert(goal)

        exercisesModified = true
        persistChanges()
    }

    func removeSetGoal(_ goal: SetGoal) {
        guard let exercise = goal.exerciseTemplate else {
            modelContext.delete(goal)
            return
        }

        let remaining = exercise.setGoals
            .filter { $0.id != goal.id }
            .sorted { $0.order < $1.order }

        modelContext.delete(goal)

        for (newOrder, survivingGoal) in remaining.enumerated() {
            survivingGoal.order = newOrder
        }

        exercisesModified = true
        persistChanges()
    }

    func save() {
        template.name = name
        template.notes = notes
        template.updatedAt = .now
        exercisesModified = false
        persistChanges()
    }

    private func persistChanges() {
        do {
            try modelContext.save()
        } catch {
            print("[TemplateEditorViewModel] Failed to save: \(error)")
        }
    }
}
