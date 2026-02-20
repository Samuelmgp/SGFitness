import Foundation
import SwiftData

// MARK: - SetGoal
// A single target set within an ExerciseTemplate.
// For example: "Set 1: 10 reps @ 135 lbs".
//
// Each SetGoal is a separate row so that exercises can have varied
// rep/weight targets across sets (e.g. pyramid sets, drop sets).
//
// `order` determines display position within the exercise.

@Model
final class SetGoal {
    @Attribute(.unique) var id: UUID

    /// Position of this set within the parent exercise. 0-indexed.
    var order: Int

    /// Target number of reps.
    var targetReps: Int

    /// Target weight. Nil means bodyweight or unspecified.
    var targetWeight: Double?

    /// Target duration in seconds for cardio sets. Nil for strength sets.
    var targetDurationSeconds: Int? = nil

    // MARK: - Relationships

    var exerciseTemplate: ExerciseTemplate?

    init(
        id: UUID = UUID(),
        order: Int,
        targetReps: Int,
        targetWeight: Double? = nil,
        exerciseTemplate: ExerciseTemplate? = nil
    ) {
        self.id = id
        self.order = order
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.exerciseTemplate = exerciseTemplate
    }
}
