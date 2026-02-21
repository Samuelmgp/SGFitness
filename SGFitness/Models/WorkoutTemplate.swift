import Foundation
import SwiftData

// MARK: - WorkoutTemplate
// A reusable workout plan (e.g. "Push Day", "Full Body A").
// Templates define the structure a user intends to follow.
// When a user starts a workout, a WorkoutSession is created — optionally
// referencing this template — and the user can deviate freely.
//
// Templates are mutable: editing a template does NOT change past sessions.

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var targetDurationMinutes: Int?

    // MARK: - Relationships

    var owner: User?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.workoutTemplate)
    var exercises: [ExerciseTemplate]

    @Relationship(deleteRule: .cascade, inverse: \StretchGoal.workoutTemplate)
    var stretches: [StretchGoal]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        targetDurationMinutes: Int? = nil,
        owner: User? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetDurationMinutes = targetDurationMinutes
        self.owner = owner
        self.exercises = []
        self.stretches = []
    }
}
