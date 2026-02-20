import Foundation
import SwiftData
import Observation

enum DayStatus {
    case completed, partial, skipped, none
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
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let yearStart = calendar.date(from: components) else { return }

        var endComponents = DateComponents()
        endComponents.year = year + 1
        endComponents.month = 1
        endComponents.day = 1
        guard let yearEnd = calendar.date(from: endComponents) else { return }

        var data: [Date: DayStatus] = [:]

        // Fetch completed workout sessions for the year
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.completedAt != nil && session.startedAt >= yearStart && session.startedAt < yearEnd
            }
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        // Group sessions by day
        for session in sessions {
            let day = calendar.startOfDay(for: session.startedAt)
            let allSets = session.exercises.flatMap(\.performedSets)
            let completedSets = allSets.filter(\.isCompleted)

            let status: DayStatus
            if allSets.isEmpty {
                status = .completed
            } else if completedSets.count == allSets.count {
                status = .completed
            } else if completedSets.count > 0 {
                status = .partial
            } else {
                status = .partial
            }

            // If there's already a status for this day, keep the better one
            if let existing = data[day] {
                if statusPriority(status) > statusPriority(existing) {
                    data[day] = status
                }
            } else {
                data[day] = status
            }
        }

        // Fetch scheduled workouts that were skipped
        let scheduledDescriptor = FetchDescriptor<ScheduledWorkout>(
            predicate: #Predicate { workout in
                workout.scheduledDate >= yearStart && workout.scheduledDate < yearEnd
            }
        )
        let scheduledWorkouts = (try? modelContext.fetch(scheduledDescriptor)) ?? []

        for scheduled in scheduledWorkouts {
            let day = calendar.startOfDay(for: scheduled.scheduledDate)
            if scheduled.status == .skipped && data[day] == nil {
                data[day] = .skipped
            }
        }

        cellData = data

        // MARK: - PR Dates
        // For each exercise, scan sessions chronologically and detect when a
        // new running max weight is set. Mark those days in the current year.
        var prDatesSet = Set<Date>()

        let defDescriptor = FetchDescriptor<ExerciseDefinition>()
        let definitions = (try? modelContext.fetch(defDescriptor)) ?? []

        for definition in definitions {
            guard definition.exerciseType != "cardio" else { continue }

            let completedExerciseSessions = definition.exerciseSessions.filter {
                $0.workoutSession?.completedAt != nil
            }.sorted {
                ($0.workoutSession?.completedAt ?? .distantPast) < ($1.workoutSession?.completedAt ?? .distantPast)
            }

            var runningMaxWeight: Double = 0
            for exerciseSession in completedExerciseSessions {
                guard let completedAt = exerciseSession.workoutSession?.completedAt else { continue }
                let maxWeight = exerciseSession.performedSets
                    .filter(\.isCompleted)
                    .compactMap(\.weight)
                    .max() ?? 0

                if maxWeight > runningMaxWeight {
                    runningMaxWeight = maxWeight
                    let day = calendar.startOfDay(for: completedAt)
                    if calendar.component(.year, from: day) == year {
                        prDatesSet.insert(day)
                    }
                }
            }
        }

        prDates = prDatesSet
    }

    func navigateYear(by offset: Int) {
        year += offset
        fetchYearData()
    }

    private func statusPriority(_ status: DayStatus) -> Int {
        switch status {
        case .completed: return 3
        case .partial: return 2
        case .skipped: return 1
        case .none: return 0
        }
    }
}
