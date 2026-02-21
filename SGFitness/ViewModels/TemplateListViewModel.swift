import Foundation
import SwiftData
import Observation

// MARK: - TemplateListViewModel
// Lists all workout templates. Handles creation and deletion at the list level.
// Template editing is delegated to TemplateEditorViewModel.

@Observable
final class TemplateListViewModel {

    private let modelContext: ModelContext
    let user: User

    /// All templates, sorted by updatedAt descending.
    private(set) var templates: [WorkoutTemplate] = []

    /// UI-only search filter.
    var searchText: String = ""

    /// Templates matching the current search text.
    var filteredTemplates: [WorkoutTemplate] {
        if searchText.isEmpty { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    init(modelContext: ModelContext, user: User) {
        self.modelContext = modelContext
        self.user = user
    }

    func fetchTemplates() {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        do {
            templates = try modelContext.fetch(descriptor)
        } catch {
            print("[TemplateListViewModel] Failed to fetch templates: \(error)")
            templates = []
        }
    }

    func createTemplate(name: String) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name, owner: user)
        modelContext.insert(template)
        do { try modelContext.save() } catch {
            print("[TemplateListViewModel] Failed to save: \(error)")
        }
        return template
    }

    func deleteTemplate(_ template: WorkoutTemplate) {
        // Manually nullify WorkoutSession.template for every session that references
        // this template. WorkoutTemplate has no declared inverse relationship to
        // WorkoutSession, so SwiftData cannot nullify these automatically on deletion.
        // Without this, the behavior is undefined and may cascade-delete or invalidate
        // sessions that should be preserved as history.
        for session in user.workoutSessions where session.template === template {
            session.template = nil
        }

        modelContext.delete(template)
        // Remove from local array immediately for responsive UI.
        templates.removeAll { $0.id == template.id }
        do { try modelContext.save() } catch {
            print("[TemplateListViewModel] Failed to save after delete: \(error)")
        }
    }
}
