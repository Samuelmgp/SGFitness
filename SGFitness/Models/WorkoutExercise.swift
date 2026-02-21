import Foundation
import SwiftData

// MARK: - WorkoutExercise
// An exercise as performed within a WorkoutSession, using the new typed model system.
//
// Separate from ExerciseSession (legacy) — WorkoutExercise is the clean forward model
// that will be used by new workout logging flows. ExerciseSession remains for
// backward-compatibility with existing session data.
//
// `name` is denormalized so history is readable even if the ExerciseDefinition
// is later deleted. The `exerciseDefinition` link is nullified on deletion.
//
// `order` determines display position within the session. Always sort by this field.

@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID

    /// Denormalized name for display even if the definition is deleted.
    var name: String

    /// Position within the session. 0-indexed.
    var order: Int

    var notes: String

    /// Suggested rest between sets, in seconds.
    var restSeconds: Int?

    // MARK: - Relationships

    var workoutSession: WorkoutSession?

    /// Canonical exercise identity for progress tracking.
    /// Nullified if the definition is deleted — historical data is preserved.
    @Relationship(deleteRule: .nullify)
    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet]

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        notes: String = "",
        restSeconds: Int? = nil,
        workoutSession: WorkoutSession? = nil,
        exerciseDefinition: ExerciseDefinition? = nil
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.notes = notes
        self.restSeconds = restSeconds
        self.workoutSession = workoutSession
        self.exerciseDefinition = exerciseDefinition
        self.sets = []
    }
}
