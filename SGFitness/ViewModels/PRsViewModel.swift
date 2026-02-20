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
// Reads stored PersonalRecord entries (gold medal only) to build ExercisePRs.
// PersonalRecordService populates the stored records after each finished workout.

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

    /// Build ExercisePRs for a definition using the gold-medal stored records.
    func computePRs(for definition: ExerciseDefinition) -> ExercisePRs {
        var prs = ExercisePRs(exercise: definition)

        let goldRecords = definition.personalRecords.filter { record in
            record.medalRaw == PRMedal.gold.rawValue
        }

        for record in goldRecords {
            switch record.recordType {
            case .maxWeight:
                prs.maxWeightKg = record.valueKg
                prs.maxWeightReps = record.reps
                prs.maxWeightDate = record.achievedAt

            case .bestVolume:
                prs.bestVolumeKg = record.valueKg
                prs.bestVolumeDate = record.achievedAt

            case .cardioTime:
                guard let distance = record.distanceMeters,
                      let duration = record.durationSeconds else { continue }
                let sessionName = record.workoutSession?.name ?? "Workout"
                prs.cardioRecords[distance] = CardioRecord(
                    bestTimeSeconds: duration,
                    date: record.achievedAt,
                    sessionName: sessionName
                )
            }
        }

        return prs
    }
}
