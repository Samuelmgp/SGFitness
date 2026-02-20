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
    var targetDurationMinutes: Int?

    /// Tracks whether exercises have been modified since last save.
    @ObservationIgnored private var exercisesModified: Bool = false

    /// Exercises sorted by order. Stored directly so @Observable triggers view updates.
    private(set) var exercises: [ExerciseTemplate] = []

    /// Whether buffered values differ from the persisted model.
    var hasUnsavedChanges: Bool {
        name != template.name || notes != template.notes || targetDurationMinutes != template.targetDurationMinutes || exercisesModified
    }

    init(modelContext: ModelContext, template: WorkoutTemplate) {
        self.modelContext = modelContext
        self.template = template
        self.name = template.name
        self.notes = template.notes
        self.targetDurationMinutes = template.targetDurationMinutes
        self.exercises = template.exercises.sorted { $0.order < $1.order }
    }

    func addExercise(from definition: ExerciseDefinition, targetSets: Int, targetReps: Int, targetWeight: Double?, restSeconds: Int? = 60) {
        let nextOrder = exercises.last.map { $0.order + 1 } ?? 0

        let exercise = ExerciseTemplate(
            name: definition.name,
            order: nextOrder,
            restSeconds: restSeconds,
            workoutTemplate: template
        )
        exercise.exerciseDefinition = definition
        modelContext.insert(exercise)

        for i in 0..<targetSets {
            let goal = SetGoal(order: i, targetReps: targetReps, targetWeight: targetWeight, exerciseTemplate: exercise)
            modelContext.insert(goal)
        }

        exercises.append(exercise)
        exercisesModified = true
        persistChanges()
    }

    func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }

        let target = exercises.remove(at: index)
        modelContext.delete(target)

        for (newOrder, exercise) in exercises.enumerated() {
            exercise.order = newOrder
        }

        exercisesModified = true
        persistChanges()
    }

    func reorderExercise(from source: Int, to destination: Int) {
        guard source != destination else { return }
        guard exercises.indices.contains(source) else { return }

        let clamped = min(destination, exercises.count - 1)
        let moving = exercises.remove(at: source)
        exercises.insert(moving, at: clamped)

        for (newOrder, exercise) in exercises.enumerated() {
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

    func refreshExercises() {
        exercises = template.exercises.sorted { $0.order < $1.order }
    }

    func save() {
        template.name = name
        template.notes = notes
        template.targetDurationMinutes = targetDurationMinutes
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
