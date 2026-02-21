import Foundation
import SwiftData

// MARK: - ExerciseDefinition
// A canonical exercise in the user's exercise catalog (e.g. "Bench Press").
//
// This model provides a stable identity for an exercise across all templates
// and sessions. Without it, progress tracking would require fuzzy string
// matching on exercise names — which drifts over time due to typos and
// naming variations.
//
// Both ExerciseTemplate and ExerciseSession hold an optional reference here.
// The `name` field is still stored on each for denormalized display, but
// ExerciseDefinition is the source of truth for identity and metadata.
//
// Users can create custom exercises. The app may also seed common exercises
// on first launch.

@Model
final class ExerciseDefinition {
    @Attribute(.unique) var id: UUID

    /// Canonical exercise name (e.g. "Barbell Bench Press").
    var name: String

    /// Muscle group for filtering and grouping. Nil for cardio exercises.
    var muscleGroup: MuscleGroup?

    /// Optional equipment tag (e.g. "Barbell", "Dumbbell", "Bodyweight").
    var equipment: String?

    /// Whether this is a strength or cardio exercise.
    var exerciseType: ExerciseType = ExerciseType.strength

    var createdAt: Date

    // MARK: - Relationships

    /// All templates that use this exercise.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseTemplate.exerciseDefinition)
    var exerciseTemplates: [ExerciseTemplate]

    /// All sessions that performed this exercise.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseSession.exerciseDefinition)
    var exerciseSessions: [ExerciseSession]

    /// All WorkoutExercise instances linked to this definition.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exerciseDefinition)
    var workoutExercises: [WorkoutExercise]

    /// Stored personal records for this exercise (gold/silver/bronze podium).
    /// Cascade-deleted when the exercise definition is removed.
    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.exerciseDefinition)
    var personalRecords: [PersonalRecord]

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup? = nil,
        equipment: String? = nil,
        exerciseType: ExerciseType = .strength,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.exerciseType = exerciseType
        self.createdAt = createdAt
        self.exerciseTemplates = []
        self.exerciseSessions = []
        self.workoutExercises = []
        self.personalRecords = []
    }
}
