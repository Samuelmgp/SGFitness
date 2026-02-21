import Foundation
import SwiftData
import Observation

// MARK: - CalendarDayData
// Per-day data bundle for the secondary detailed calendar.
// Built once per month fetch; never mutated by views.

struct CalendarDayData {
    var sessions: [WorkoutSession]
    /// Unique muscle groups trained (sorted by rawValue for stable order).
    var muscleGroups: [MuscleGroup]
    /// Any cardio exercise was performed.
    var hasCardio: Bool
    /// At least one new PR was set (mirrors WorkoutSession.hasPRs).
    var hasPRs: Bool
    /// Best medal earned across all sessions on this day (lowest rank value).
    var bestMedal: PRMedal?
    /// Best WorkoutStatus across all sessions on this day.
    var dominantStatus: WorkoutStatus?
}

// MARK: - CalendarViewModel

@Observable
final class CalendarViewModel {

    private let modelContext: ModelContext

    /// First day of the currently displayed month.
    var currentMonth: Date

    /// Keyed by `Calendar.current.startOfDay(for:)`.
    private(set) var dayData: [Date: CalendarDayData] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: .now)
        comps.day = 1
        self.currentMonth = cal.date(from: comps) ?? .now
    }

    // MARK: - Data Loading

    func fetchMonthData() {
        let calendar = Calendar.current
        var startComps = calendar.dateComponents([.year, .month], from: currentMonth)
        startComps.day = 1
        guard let monthStart = calendar.date(from: startComps),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.completedAt != nil &&
                session.startedAt >= monthStart &&
                session.startedAt < monthEnd
            }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []

        var result: [Date: CalendarDayData] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startedAt)

            var muscleGroupSet = Set<MuscleGroup>()
            var hasCardio = false
            var bestMedal: PRMedal? = nil

            for exercise in session.exercises {
                guard let definition = exercise.exerciseDefinition else { continue }
                if definition.exerciseType == .cardio {
                    hasCardio = true
                } else if let mg = definition.muscleGroup {
                    muscleGroupSet.insert(mg)
                }
            }

            // Walk in-memory PR relationships to find best medal for this session
            if session.hasPRs {
                for exercise in session.exercises {
                    guard let definition = exercise.exerciseDefinition else { continue }
                    for pr in definition.personalRecords
                    where pr.workoutSession?.id == session.id {
                        if bestMedal == nil || pr.medal.rank < bestMedal!.rank {
                            bestMedal = pr.medal
                        }
                    }
                }
            }

            let sortedGroups = muscleGroupSet.sorted { $0.rawValue < $1.rawValue }

            if var existing = result[day] {
                existing.sessions.append(session)
                let combined = Set(existing.muscleGroups).union(muscleGroupSet)
                existing.muscleGroups = combined.sorted { $0.rawValue < $1.rawValue }
                existing.hasCardio = existing.hasCardio || hasCardio
                existing.hasPRs = existing.hasPRs || session.hasPRs
                if let m = bestMedal,
                   existing.bestMedal == nil || m.rank < existing.bestMedal!.rank {
                    existing.bestMedal = m
                }
                existing.dominantStatus = betterStatus(existing.dominantStatus, session.workoutStatus)
                result[day] = existing
            } else {
                result[day] = CalendarDayData(
                    sessions: [session],
                    muscleGroups: sortedGroups,
                    hasCardio: hasCardio,
                    hasPRs: session.hasPRs,
                    bestMedal: bestMedal,
                    dominantStatus: session.workoutStatus
                )
            }
        }

        dayData = result
    }

    func navigateMonth(by offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
            fetchMonthData()
        }
    }

    // MARK: - Grid Layout

    var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    /// 2D array of optional Dates — nil = leading/trailing blank cell.
    var calendarGrid: [[Date?]] {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month], from: currentMonth)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: currentMonth)
        else { return [] }

        let leadingBlanks = (calendar.component(.weekday, from: firstDay) - 1 + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<($0 + 7)])
        }
    }

    // MARK: - Private helpers

    private func betterStatus(_ a: WorkoutStatus?, _ b: WorkoutStatus?) -> WorkoutStatus? {
        switch (a, b) {
        case (.none, let x): return x
        case (let x, .none): return x
        case (.exceeded, _), (_, .exceeded): return .exceeded
        case (.targetMet, _), (_, .targetMet): return .targetMet
        default: return .partial
        }
    }
}
