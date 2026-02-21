import Foundation
import SwiftData

// MARK: - PersonalRecordService
//
// Owns all PersonalRecord evaluation logic. Evaluates which sessions
// earn gold/silver/bronze podium spots for each exercise metric.
//
// Two entry points:
//   - evaluatePRs(for:) — called after finishWorkout() to evaluate a single session.
//   - rebuildAllPRs() — one-time migration that replays all completed sessions.
//
// Design notes:
//   - Uses in-memory filtering on definition.personalRecords (NOT #Predicate with
//     optional chains) to avoid SwiftData predicate limitations with optionals.
//   - Idempotent: guards against inserting a duplicate record for the same
//     (workoutSession.id + recordType + distanceMeters) combination.
//   - At most 3 records per (definition, recordType, distanceMeters) bucket.

final class PersonalRecordService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Evaluate PRs for all exercises in a completed session.
    /// Call this after persistChanges() in finishWorkout().
    func evaluatePRs(for session: WorkoutSession) {
        for exerciseSession in session.exercises {
            guard let definition = exerciseSession.exerciseDefinition else { continue }

            if definition.exerciseType == .cardio {
                evaluateCardio(exerciseSession: exerciseSession, definition: definition, workoutSession: session)
            } else {
                evaluateStrength(exerciseSession: exerciseSession, definition: definition, workoutSession: session)
            }
        }
        save()
    }

    /// One-time migration. Deletes all PersonalRecord entries then replays
    /// all completed sessions in chronological order.
    func rebuildAllPRs() {
        // Delete all existing records
        let allDescriptor = FetchDescriptor<PersonalRecord>()
        let existing = (try? modelContext.fetch(allDescriptor)) ?? []
        for record in existing {
            modelContext.delete(record)
        }

        // Commit deletions before evaluating new PRs.
        // Without this save, SwiftData's in-memory relationship cache still
        // returns the deleted records when rerankPRs() reads
        // definition.personalRecords. The idempotency guard then sees a
        // "matching" entry for every session and returns early, preventing
        // any new PRs from being inserted — leaving the store empty after
        // the rebuild completes.
        save()

        // Fetch all completed sessions sorted chronologically
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .forward)]
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        for session in sessions {
            for exerciseSession in session.exercises {
                guard let definition = exerciseSession.exerciseDefinition else { continue }

                if definition.exerciseType == .cardio {
                    evaluateCardio(exerciseSession: exerciseSession, definition: definition, workoutSession: session)
                } else {
                    evaluateStrength(exerciseSession: exerciseSession, definition: definition, workoutSession: session)
                }
            }
        }

        save()
    }

    // MARK: - Private: Strength Evaluation

    private func evaluateStrength(
        exerciseSession: ExerciseSession,
        definition: ExerciseDefinition,
        workoutSession: WorkoutSession
    ) {
        let completedSets = exerciseSession.performedSets.filter(\.isCompleted)
        guard !completedSets.isEmpty else { return }

        let achievedAt = workoutSession.completedAt ?? workoutSession.startedAt

        // Max weight: highest weight set + reps at that weight
        if let maxWeightSet = completedSets.filter({ ($0.weight ?? 0) > 0 }).max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
           let weight = maxWeightSet.weight {
            rerankPRs(
                definition: definition,
                recordType: .maxWeight,
                distanceMeters: nil,
                candidateValueKg: weight,
                candidateReps: maxWeightSet.reps,
                candidateDuration: nil,
                achievedAt: achievedAt,
                workoutSession: workoutSession,
                higherIsBetter: true
            )
        }

        // Best volume: sum(reps × weight) across all completed sets
        let sessionVolume = completedSets.reduce(0.0) { total, set in
            guard let w = set.weight else { return total }
            return total + Double(set.reps) * w
        }
        if sessionVolume > 0 {
            rerankPRs(
                definition: definition,
                recordType: .bestVolume,
                distanceMeters: nil,
                candidateValueKg: sessionVolume,
                candidateReps: nil,
                candidateDuration: nil,
                achievedAt: achievedAt,
                workoutSession: workoutSession,
                higherIsBetter: true
            )
        }
    }

    // MARK: - Private: Cardio Evaluation

    private func evaluateCardio(
        exerciseSession: ExerciseSession,
        definition: ExerciseDefinition,
        workoutSession: WorkoutSession
    ) {
        let completedSets = exerciseSession.performedSets.filter(\.isCompleted)
        guard !completedSets.isEmpty else { return }

        let achievedAt = workoutSession.completedAt ?? workoutSession.startedAt

        // Group by distance (reps field stores meters), find min duration per distance
        var bestByDistance: [Int: Int] = [:] // distance -> min durationSeconds
        for set in completedSets {
            guard let duration = set.durationSeconds, duration > 0 else { continue }
            let distance = set.reps
            if let existing = bestByDistance[distance] {
                if duration < existing {
                    bestByDistance[distance] = duration
                }
            } else {
                bestByDistance[distance] = duration
            }
        }

        for (distance, duration) in bestByDistance {
            rerankPRs(
                definition: definition,
                recordType: .cardioTime,
                distanceMeters: distance,
                candidateValueKg: nil,
                candidateReps: nil,
                candidateDuration: duration,
                achievedAt: achievedAt,
                workoutSession: workoutSession,
                higherIsBetter: false // lower time is better for cardio
            )
        }
    }

    // MARK: - Private: Re-ranking

    /// Core re-ranking algorithm. Filters existing records in-memory, adds
    /// the candidate, sorts, keeps the top 3, assigns medals, and deletes
    /// entries that fell outside the top 3.
    private func rerankPRs(
        definition: ExerciseDefinition,
        recordType: PRRecordType,
        distanceMeters: Int?,
        candidateValueKg: Double?,
        candidateReps: Int?,
        candidateDuration: Int?,
        achievedAt: Date,
        workoutSession: WorkoutSession,
        higherIsBetter: Bool
    ) {
        // 1. Filter existing records for this bucket in-memory
        let existingForBucket = definition.personalRecords.filter { record in
            record.recordTypeRaw == recordType.rawValue &&
            record.distanceMeters == distanceMeters
        }

        // 2. Idempotency guard: skip if a record for this session+type+distance already exists
        let sessionId = workoutSession.id
        let alreadyExists = existingForBucket.contains { record in
            record.workoutSession?.id == sessionId
        }
        guard !alreadyExists else { return }

        // 3. Create candidate (not yet inserted into context)
        let candidate = PersonalRecord(
            recordType: recordType,
            medal: PRMedal.gold, // placeholder; will be reassigned below
            valueKg: candidateValueKg,
            reps: candidateReps,
            distanceMeters: distanceMeters,
            durationSeconds: candidateDuration,
            achievedAt: achievedAt,
            exerciseDefinition: definition,
            workoutSession: workoutSession
        )

        // 4. Build combined list and sort
        var combined = existingForBucket + [candidate]
        if higherIsBetter {
            combined.sort { ($0.valueKg ?? 0) > ($1.valueKg ?? 0) }
        } else {
            combined.sort { ($0.durationSeconds ?? Int.max) < ($1.durationSeconds ?? Int.max) }
        }

        // 5. Keep top 3, delete the rest
        let top3 = Array(combined.prefix(3))
        let dropped = combined.dropFirst(3)
        for record in dropped {
            // Only delete records that are already in the context (not the new candidate)
            if record !== candidate {
                modelContext.delete(record)
            }
        }

        // 6. Check if candidate made it into the top 3
        let candidateInTop3 = top3.contains { $0 === candidate }
        if candidateInTop3 {
            modelContext.insert(candidate)
        }

        // 7. Assign medals by rank index
        let medals: [PRMedal] = [.gold, .silver, .bronze]
        for (index, record) in top3.enumerated() {
            record.medal = medals[index]
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("[PersonalRecordService] Failed to save: \(error)")
        }
    }
}
