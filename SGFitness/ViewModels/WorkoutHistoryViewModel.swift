import Foundation
import SwiftData
import Observation

// MARK: - WorkoutHistoryViewModel
// Fetches and presents the list of past completed workout sessions.
// Handles filtering by search text and deletion.

@Observable
final class WorkoutHistoryViewModel {

    private let modelContext: ModelContext

    /// All completed sessions, sorted by startedAt descending.
    private(set) var sessions: [WorkoutSession] = []

    /// UI-only search filter.
    var searchText: String = ""

    /// Sessions matching the current search text.
    var filteredSessions: [WorkoutSession] {
        if searchText.isEmpty { return sessions }
        return sessions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSessions() {
        // Fetch only completed sessions (completedAt != nil).
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        do {
            sessions = try modelContext.fetch(descriptor)
        } catch {
            print("[WorkoutHistoryViewModel] Failed to fetch sessions: \(error)")
            sessions = []
        }
    }

    func deleteSession(_ session: WorkoutSession) {
        modelContext.delete(session)
        sessions.removeAll { $0.id == session.id }
        do { try modelContext.save() } catch {
            print("[WorkoutHistoryViewModel] Failed to save after delete: \(error)")
        }
    }
}
