import Foundation
import SwiftData

// MARK: - ExerciseTemplate
// A single exercise within a WorkoutTemplate (e.g. "Bench Press" in "Push Day").
// Defines what the user plans to do, including ordering within the workout.
//
// The `order` property is explicit because SwiftData does not guarantee
// relationship ordering. Sort by `order` when displaying.

@Model
final class ExerciseTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String

    /// Position of this exercise within the parent workout template. 0-indexed.
    var order: Int

    /// Suggested rest time between sets, in seconds. Nil means no rest timer.
    var restSeconds: Int?

    // MARK: - Relationships

    var workoutTemplate: WorkoutTemplate?

    /// Canonical exercise identity for progress tracking.
    /// Nil for legacy data or exercises not yet linked to the catalog.
    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \SetGoal.exerciseTemplate)
    var setGoals: [SetGoal]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        order: Int,
        restSeconds: Int? = 60,
        workoutTemplate: WorkoutTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.order = order
        self.restSeconds = restSeconds
        self.workoutTemplate = workoutTemplate
        self.setGoals = []
    }
}
