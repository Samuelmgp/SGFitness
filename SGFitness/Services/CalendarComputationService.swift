import Foundation
import SwiftData

// MARK: - CalendarComputationService
//
// Owns all calendar-status evaluation logic. Computes and persists two fields
// on WorkoutSession after each workout completes:
//
//   workoutStatusRaw — WorkoutStatus (exceeded / targetMet / partial)
//   hasPRs           — true if PersonalRecordService created any records
//
// Two entry points:
//   evaluateSession(_:) — called after finishWorkout() + evaluatePRs() for a
//                         single session. Fast: walks in-memory relationships.
//   rebuildAll()        — one-time migration. Scans all completed sessions.
//
// "Missed" days (Red) are computed on-the-fly by YearGridViewModel from
// the gap between sessions — there is no session object to stamp for a
// day that had no workout.

final class CalendarComputationService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Evaluate a single just-completed session.
    /// Call after `persistChanges()` and `PersonalRecordService.evaluatePRs()`.
    func evaluateSession(_ session: WorkoutSession) {
        guard let completedAt = session.completedAt else { return }

        // Workout status from actual vs target duration.
        let durationMinutes = Int(completedAt.timeIntervalSince(session.startedAt) / 60)
        session.workoutStatusRaw = WorkoutStatus.compute(
            durationMinutes: durationMinutes,
            targetMinutes: session.targetDurationMinutes
        ).rawValue

        // Check for PRs by walking in-memory relationships.
        // session → exercises → exerciseDefinition → personalRecords
        // This avoids a full-table PersonalRecord fetch.
        session.hasPRs = sessionHasPRs(session)

        save()
    }

    /// Rebuild status and hasPRs for every completed session.
    /// Safe to call multiple times (idempotent).
    func rebuildAll() {
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        // Fetch all PersonalRecords once and build a set of session IDs
        // that have at least one PR — avoids O(n²) per-session fetches.
        let allPRDescriptor = FetchDescriptor<PersonalRecord>()
        let allPRs = (try? modelContext.fetch(allPRDescriptor)) ?? []
        var sessionIdsWithPRs = Set<UUID>()
        for pr in allPRs {
            if let sid = pr.workoutSession?.id {
                sessionIdsWithPRs.insert(sid)
            }
        }

        for session in sessions {
            guard let completedAt = session.completedAt else { continue }
            let durationMinutes = Int(completedAt.timeIntervalSince(session.startedAt) / 60)
            session.workoutStatusRaw = WorkoutStatus.compute(
                durationMinutes: durationMinutes,
                targetMinutes: session.targetDurationMinutes
            ).rawValue
            session.hasPRs = sessionIdsWithPRs.contains(session.id)
        }

        save()
    }

    // MARK: - Private

    /// Walk exercise definitions in memory to detect any PR linked to this session.
    private func sessionHasPRs(_ session: WorkoutSession) -> Bool {
        for exercise in session.exercises {
            guard let definition = exercise.exerciseDefinition else { continue }
            if definition.personalRecords.contains(where: { $0.workoutSession?.id == session.id }) {
                return true
            }
        }
        return false
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("[CalendarComputationService] Failed to save: \(error)")
        }
    }
}
