import Foundation
import SwiftData

// MARK: - ExerciseSet
// A single set within a WorkoutExercise. Supports both strength and cardio types
// via optional field groups — only the fields relevant to the exercise type are
// populated. The parent WorkoutExercise → ExerciseDefinition → exerciseType
// determines which fields apply.
//
// Strength set:  reps + weightKg (nil = bodyweight)
// Cardio set:    distanceMeters + durationSeconds
//
// `order` determines display position within the exercise. Always sort by this field.

@Model
final class ExerciseSet {
    @Attribute(.unique) var id: UUID

    /// Position within the exercise. 0-indexed.
    var order: Int

    var isCompleted: Bool
    var completedAt: Date?

    // MARK: - Strength Fields

    /// Reps completed. Nil for cardio sets.
    var reps: Int?

    /// Weight in kilograms. Nil means bodyweight or cardio.
    /// All weights stored in kg — convert at the view layer.
    var weightKg: Double?

    // MARK: - Cardio Fields

    /// Distance covered, in meters. Nil for strength sets.
    var distanceMeters: Int?

    /// Elapsed time in seconds. Nil for strength sets.
    var durationSeconds: Int?

    // MARK: - Relationships

    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        order: Int,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        reps: Int? = nil,
        weightKg: Double? = nil,
        distanceMeters: Int? = nil,
        durationSeconds: Int? = nil,
        workoutExercise: WorkoutExercise? = nil
    ) {
        self.id = id
        self.order = order
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.reps = reps
        self.weightKg = weightKg
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.workoutExercise = workoutExercise
    }
}
