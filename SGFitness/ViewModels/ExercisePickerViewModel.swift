import Foundation
import SwiftData
import Observation

// MARK: - ExercisePickerViewModel
// Searches and presents the ExerciseDefinition catalog.
// Used by both TemplateEditorView and ActiveWorkoutView when
// adding an exercise. Supports creating custom exercises.

@Observable
final class ExercisePickerViewModel: Identifiable {

    let id = UUID()
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
        let descriptor = FetchDescriptor<ExerciseDefinition>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        definitions = (try? modelContext.fetch(descriptor)) ?? []
        fetchRecentlyUsed()
    }

    func createCustomExercise(name: String, muscleGroup: MuscleGroup? = nil, equipment: String? = nil, exerciseType: ExerciseType = .strength) -> ExerciseDefinition {
        let definition = ExerciseDefinition(name: name, muscleGroup: muscleGroup, equipment: equipment, exerciseType: exerciseType)
        modelContext.insert(definition)
        do {
            try modelContext.save()
        } catch {
            print("[ExercisePickerViewModel] Failed to save custom exercise: \(error)")
        }
        definitions.append(definition)
        definitions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return definition
    }

    func updateExercise(_ definition: ExerciseDefinition, name: String, muscleGroup: MuscleGroup?, equipment: String?, exerciseType: ExerciseType = .strength) {
        definition.name = name
        definition.muscleGroup = muscleGroup
        definition.equipment = equipment
        definition.exerciseType = exerciseType
        do {
            try modelContext.save()
        } catch {
            print("[ExercisePickerViewModel] Failed to update exercise: \(error)")
        }
        definitions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func deleteExercise(_ definition: ExerciseDefinition) {
        definitions.removeAll { $0.id == definition.id }
        modelContext.delete(definition)
        do {
            try modelContext.save()
        } catch {
            print("[ExercisePickerViewModel] Failed to delete exercise: \(error)")
        }
    }

    private func fetchRecentlyUsed() {
        var descriptor = FetchDescriptor<ExerciseSession>(
            sortBy: [SortDescriptor(\.workoutSession?.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        var seen = Set<UUID>()
        var recent: [ExerciseDefinition] = []

        for session in sessions {
            guard let def = session.exerciseDefinition else { continue }
            if seen.insert(def.id).inserted {
                recent.append(def)
            }
            if recent.count >= 5 { break }
        }

        recentlyUsed = recent
    }
}
