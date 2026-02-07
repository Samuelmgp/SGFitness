import Foundation
import SwiftData
import Observation

// MARK: - TemplateEditorViewModel
// Full editing of a single template — name, notes, exercises, set goals, ordering.
// Used for both new and existing templates.
//
// Stub — method bodies will be implemented in a future task.

@Observable
final class TemplateEditorViewModel {

    private let modelContext: ModelContext

    /// The template being edited.
    let template: WorkoutTemplate

    /// Buffered edit fields — written to the model on save().
    var name: String
    var notes: String

    /// Exercises sorted by order.
    var exercises: [ExerciseTemplate] {
        template.exercises.sorted { $0.order < $1.order }
    }

    /// Whether buffered values differ from the persisted model.
    var hasUnsavedChanges: Bool {
        name != template.name || notes != template.notes
    }

    init(modelContext: ModelContext, template: WorkoutTemplate) {
        self.modelContext = modelContext
        self.template = template
        self.name = template.name
        self.notes = template.notes
    }

    func addExercise(from definition: ExerciseDefinition, targetSets: Int, targetReps: Int, targetWeight: Double?) {
        // TODO: Create ExerciseTemplate + SetGoal children
    }

    func removeExercise(at index: Int) {
        // TODO: Delete exercise and recompute order
    }

    func reorderExercise(from source: Int, to destination: Int) {
        // TODO: Update order on affected rows
    }

    func addSetGoal(to exercise: ExerciseTemplate, reps: Int, weight: Double?) {
        // TODO: Append a SetGoal to the exercise
    }

    func removeSetGoal(_ goal: SetGoal) {
        // TODO: Delete goal and recompute order
    }

    func save() {
        // TODO: Write buffered name/notes to model, set template.updatedAt
    }
}
