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
        // Step 1: Explicitly delete all PersonalRecord objects linked to this session
        // BEFORE deleting the session. PersonalRecord.workoutSession has no declared
        // inverse on WorkoutSession so SwiftData cannot nullify these automatically.
        // If the session is deleted first, SwiftData's auto-save may commit that
        // deletion before rebuildAllPRs() runs — leaving those PR references dangling
        // and causing a "model instance was invalidated" crash.
        for exercise in session.exercises {
            guard let definition = exercise.exerciseDefinition else { continue }
            let stale = definition.personalRecords.filter { $0.workoutSession === session }
            stale.forEach { modelContext.delete($0) }
        }

        // Step 2: Delete the session (cascade-deletes its ExerciseSessions and PerformedSets).
        modelContext.delete(session)
        sessions.removeAll { $0.id == session.id }

        // Step 3: Commit all deletions atomically. After this save, no stale PR references
        // pointing to the deleted session remain anywhere in the store.
        do { try modelContext.save() } catch {
            print("[WorkoutHistoryViewModel] Failed to save after delete: \(error)")
            return
        }

        // Step 4: Re-rank remaining sessions (safe now — store has no stale references).
        PersonalRecordService(modelContext: modelContext).rebuildAllPRs()

        // Step 5: Refresh hasPRs on surviving sessions so the Calendar is accurate.
        CalendarComputationService(modelContext: modelContext).rebuildAll()
    }
}
