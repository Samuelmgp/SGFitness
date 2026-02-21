import Foundation
import SwiftData

// MARK: - PerformedSet
// A single set as actually performed during an ExerciseSession.
// This is the most granular unit of workout data.
//
// Records what the user actually did — reps completed, weight used,
// and whether the set was completed or skipped.
//
// `order` determines display position within the exercise session.

@Model
final class PerformedSet {
    @Attribute(.unique) var id: UUID

    /// Position of this set within the exercise session. 0-indexed.
    var order: Int

    /// Number of reps actually completed.
    var reps: Int

    /// Weight actually used. Nil means bodyweight or unspecified.
    var weight: Double?

    /// Whether the user completed this set (false = skipped/failed).
    var isCompleted: Bool

    /// Timestamp when this set was logged. Useful for rest-time calculations.
    var completedAt: Date?

    /// Duration in seconds. For cardio sets: elapsed time. Nil for strength sets.
    /// When used for cardio: reps = distance in meters, durationSeconds = time.
    var durationSeconds: Int? = nil

    // MARK: - Relationships

    var exerciseSession: ExerciseSession?

    init(
        id: UUID = UUID(),
        order: Int,
        reps: Int,
        weight: Double? = nil,
        isCompleted: Bool = true,
        completedAt: Date? = nil,
        exerciseSession: ExerciseSession? = nil
    ) {
        self.id = id
        self.order = order
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.exerciseSession = exerciseSession
    }
}
