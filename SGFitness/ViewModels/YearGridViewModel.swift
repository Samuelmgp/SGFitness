import Foundation
import SwiftData
import Observation

// MARK: - DayStatus
// Five display states for a calendar day cell.
// "Missed" and "RestDay" are derived at render time from session gaps —
// they are never stored on a model object.

enum DayStatus {
    case exceeded      // 🟣 Purple:  exceeded target by 60+ min
    case targetMet     // 🟢 Green:   met target duration
    case partial       // 🟡 Yellow:  10+ min but below target
    case missed        // 🔴 Red:     2+ days gap since last workout
    case restDay       // ⚪ Grey:    no workout, within normal rest gap
}

@Observable
final class YearGridViewModel {

    private let modelContext: ModelContext

    var year: Int
    private(set) var cellData: [Date: DayStatus] = [:]
    private(set) var prDates: Set<Date> = []

    init(modelContext: ModelContext, year: Int = Calendar.current.component(.year, from: .now)) {
        self.modelContext = modelContext
        self.year = year
    }

    func fetchYearData() {
        let calendar = Calendar.current

        var startComps = DateComponents()
        startComps.year = year; startComps.month = 1; startComps.day = 1
        guard let yearStart = calendar.date(from: startComps) else { return }

        var endComps = DateComponents()
        endComps.year = year + 1; endComps.month = 1; endComps.day = 1
        guard let yearEnd = calendar.date(from: endComps) else { return }

        var data: [Date: DayStatus] = [:]
        var prDatesSet = Set<Date>()

        // MARK: Fetch sessions for the year

        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.completedAt != nil &&
                session.startedAt >= yearStart &&
                session.startedAt < yearEnd
            },
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        // Index by calendar day; collect PR days from stored hasPRs flag.
        var sessionsByDay: [Date: [WorkoutSession]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startedAt)
            sessionsByDay[day, default: []].append(session)
            if session.hasPRs { prDatesSet.insert(day) }
        }

        // Assign DayStatus for days that have sessions.
        for (day, daySessions) in sessionsByDay {
            data[day] = bestStatus(from: daySessions)
        }

        // MARK: Missed / Rest-day logic

        // Find the most recent completed session before this year to anchor gap
        // computation for the first days of January.
        var prevDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.completedAt != nil && session.startedAt < yearStart
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        prevDescriptor.fetchLimit = 1
        let lastBeforeYear = (try? modelContext.fetch(prevDescriptor))?.first

        var lastSessionDay: Date? = lastBeforeYear.map {
            calendar.startOfDay(for: $0.startedAt)
        }

        // Compute missed threshold from user's frequency goal.
        // e.g. 5x/week → ceil(7/5) = 2 days gap before "missed"
        //      3x/week → ceil(7/3) = 3 days gap before "missed"
        //      1x/week → ceil(7/1) = 7 days gap before "missed"
        let userDescriptor = FetchDescriptor<User>()
        let freq = (try? modelContext.fetch(userDescriptor))?.first?.targetWorkoutDaysPerWeek
        let missedThreshold = freq.map { Int(ceil(7.0 / Double($0))) } ?? 2

        // Walk every day in the year up to today. O(365) — fast.
        let today = calendar.startOfDay(for: .now)
        var currentDay = yearStart
        while currentDay < yearEnd && currentDay <= today {
            let day = calendar.startOfDay(for: currentDay)

            if sessionsByDay[day] != nil {
                // Day has a session: status already set; update anchor.
                lastSessionDay = day
            } else if data[day] == nil {
                // No session and no status yet: compute missed vs rest.
                if let last = lastSessionDay {
                    let gap = calendar.dateComponents([.day], from: last, to: day).day ?? 0
                    data[day] = gap >= missedThreshold ? .missed : .restDay
                } else {
                    data[day] = .restDay
                }
            }

            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
        }

        // MARK: ScheduledWorkout overrides (explicitly skipped = missed)

        let scheduledDescriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: #Predicate { workout in
                workout.scheduledDate >= yearStart && workout.scheduledDate < yearEnd
            }
        )
        let scheduledWorkouts = (try? modelContext.fetch(scheduledDescriptor)) ?? []

        for scheduled in scheduledWorkouts {
            let day = calendar.startOfDay(for: scheduled.scheduledDate)
            if scheduled.status == .skipped && data[day] == nil {
                data[day] = .missed
            }
        }

        cellData = data
        prDates = prDatesSet
    }

    func navigateYear(by offset: Int) {
        year += offset
        fetchYearData()
    }

    // MARK: - Private helpers

    /// Map a set of sessions on the same day to the best DayStatus.
    private func bestStatus(from sessions: [WorkoutSession]) -> DayStatus {
        var best: DayStatus = .restDay
        for session in sessions {
            let s = dayStatus(from: session)
            if statusPriority(s) > statusPriority(best) {
                best = s
            }
        }
        return best
    }

    /// Convert a session's stored WorkoutStatus to a calendar DayStatus.
    private func dayStatus(from session: WorkoutSession) -> DayStatus {
        switch session.workoutStatus {
        case .exceeded:  return .exceeded
        case .targetMet: return .targetMet
        case .partial:   return .partial
        case nil:
            // Pre-migration session: completed but status not yet computed.
            // Treat as "partial" since we know it was at least attempted.
            return session.completedAt != nil ? .partial : .restDay
        }
    }

    private func statusPriority(_ status: DayStatus) -> Int {
        switch status {
        case .exceeded:  return 5
        case .targetMet: return 4
        case .partial:   return 3
        case .missed:    return 2
        case .restDay:   return 1
        }
    }
}
