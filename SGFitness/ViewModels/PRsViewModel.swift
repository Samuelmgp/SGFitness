import Foundation
import SwiftData
import Observation

// MARK: - PR Data Structures

struct CardioRecord {
    var bestTimeSeconds: Int
    var date: Date
    var sessionName: String
}

struct ExercisePRs {
    let exercise: ExerciseDefinition

    // Strength
    var maxWeightKg: Double?
    var maxWeightReps: Int?
    var maxWeightDate: Date?
    var bestVolumeKg: Double?
    var bestVolumeDate: Date?

    // Cardio: key = distance in meters
    var cardioRecords: [Int: CardioRecord] = [:]

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
    }
}

// MARK: - PRsViewModel
// Computes personal records on-demand from existing session data.
// No separate PersonalRecord model is stored — all PRs are derived.

@Observable
final class PRsViewModel {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - All PRs

    func computeAllPRs() -> [(ExerciseDefinition, ExercisePRs)] {
        let descriptor = FetchDescriptor<ExerciseDefinition>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let definitions = (try? modelContext.fetch(descriptor)) ?? []
        return definitions.map { ($0, computePRs(for: $0)) }
    }

    // MARK: - Per-Exercise PRs

    func computePRs(for definition: ExerciseDefinition) -> ExercisePRs {
        var prs = ExercisePRs(exercise: definition)

        let completedSessions = definition.exerciseSessions.filter {
            $0.workoutSession?.completedAt != nil
        }

        if definition.exerciseType == "cardio" {
            prs.cardioRecords = computeCardioPRs(from: completedSessions)
        } else {
            computeStrengthPRs(from: completedSessions, into: &prs)
        }

        return prs
    }

    // MARK: - All PR Dates (for calendar indicator)

    /// Returns the dates on which any current all-time PR was set.
    func allPRDates() -> Set<Date> {
        let calendar = Calendar.current
        var prDates = Set<Date>()

        let descriptor = FetchDescriptor<ExerciseDefinition>()
        let definitions = (try? modelContext.fetch(descriptor)) ?? []

        for definition in definitions {
            let prs = computePRs(for: definition)
            if let date = prs.maxWeightDate {
                prDates.insert(calendar.startOfDay(for: date))
            }
            if let date = prs.bestVolumeDate {
                prDates.insert(calendar.startOfDay(for: date))
            }
            for (_, record) in prs.cardioRecords {
                prDates.insert(calendar.startOfDay(for: record.date))
            }
        }

        return prDates
    }

    // MARK: - Baseline helpers (for live workout PR detection)

    func maxWeight(for definitionId: UUID) -> Double? {
        guard let definition = fetchDefinition(id: definitionId) else { return nil }
        return computePRs(for: definition).maxWeightKg
    }

    func bestVolume(for definitionId: UUID) -> Double? {
        guard let definition = fetchDefinition(id: definitionId) else { return nil }
        return computePRs(for: definition).bestVolumeKg
    }

    // MARK: - Private helpers

    private func fetchDefinition(id: UUID) -> ExerciseDefinition? {
        let descriptor = FetchDescriptor<ExerciseDefinition>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func computeStrengthPRs(from sessions: [ExerciseSession], into prs: inout ExercisePRs) {
        for session in sessions {
            guard let completedAt = session.workoutSession?.completedAt else { continue }
            let completedSets = session.performedSets.filter(\.isCompleted)

            // Max weight PR
            for set in completedSets {
                guard let weight = set.weight, weight > 0 else { continue }
                if prs.maxWeightKg == nil || weight > prs.maxWeightKg! {
                    prs.maxWeightKg = weight
                    prs.maxWeightReps = set.reps
                    prs.maxWeightDate = completedAt
                }
            }

            // Best volume PR (sum of reps × weight for this session)
            let sessionVolume = completedSets.reduce(0.0) { total, set in
                guard let weight = set.weight else { return total }
                return total + Double(set.reps) * weight
            }
            if sessionVolume > 0, (prs.bestVolumeKg == nil || sessionVolume > prs.bestVolumeKg!) {
                prs.bestVolumeKg = sessionVolume
                prs.bestVolumeDate = completedAt
            }
        }
    }

    private func computeCardioPRs(from sessions: [ExerciseSession]) -> [Int: CardioRecord] {
        var records: [Int: CardioRecord] = [:]

        for session in sessions {
            guard let completedAt = session.workoutSession?.completedAt,
                  let sessionName = session.workoutSession?.name else { continue }

            let completedSets = session.performedSets.filter(\.isCompleted)
            for set in completedSets {
                guard let duration = set.durationSeconds, duration > 0 else { continue }
                let distance = set.reps // reps stores distance in meters for cardio

                if let existing = records[distance] {
                    if duration < existing.bestTimeSeconds {
                        records[distance] = CardioRecord(
                            bestTimeSeconds: duration,
                            date: completedAt,
                            sessionName: sessionName
                        )
                    }
                } else {
                    records[distance] = CardioRecord(
                        bestTimeSeconds: duration,
                        date: completedAt,
                        sessionName: sessionName
                    )
                }
            }
        }

        return records
    }
}
