import Foundation
import SwiftData
import Observation

// MARK: - ExercisePickerViewModel
// Searches and presents the ExerciseDefinition catalog.
// Used by both TemplateEditorView and ActiveWorkoutView when
// adding an exercise. Supports creating custom exercises.
//
// Stub — method bodies will be implemented in a future task.

@Observable
final class ExercisePickerViewModel {

    private let modelContext: ModelContext

    /// Full exercise catalog, sorted alphabetically.
    private(set) var definitions: [ExerciseDefinition] = []

    /// UI-only search filter.
    var searchText: String = ""

    /// Definitions matching the current search text.
    var filteredDefinitions: [ExerciseDefinition] {
        if searchText.isEmpty { return definitions }
        return definitions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Most recently used exercises (derived from session history).
    private(set) var recentlyUsed: [ExerciseDefinition] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchDefinitions() {
        // TODO: Query all ExerciseDefinition records, sort alphabetically
    }

    func createCustomExercise(name: String) -> ExerciseDefinition {
        // TODO: Create and insert a new ExerciseDefinition
        let definition = ExerciseDefinition(name: name)
        modelContext.insert(definition)
        return definition
    }
}
