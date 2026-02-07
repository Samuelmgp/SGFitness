import Foundation
import SwiftData

// MARK: - ExerciseSession
// An exercise as actually performed within a WorkoutSession.
//
// Mirrors ExerciseTemplate in structure but records what really happened.
// The optional `exerciseTemplate` link lets the UI show "planned vs actual"
// comparisons, but the session stands alone if the template is deleted.
//
// `order` determines display position within the session.

@Model
final class ExerciseSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String

    /// Position of this exercise within the session. 0-indexed.
    var order: Int

    /// Perceived effort on a 1–10 scale. Nil if the user skipped rating.
    var effort: Int?

    /// Rest time actually used between sets, in seconds.
    var restSeconds: Int?

    // MARK: - Relationships

    var workoutSession: WorkoutSession?

    /// Optional link back to the template exercise this was based on.
    /// Nullified if the template exercise is deleted.
    @Relationship(deleteRule: .nullify) var exerciseTemplate: ExerciseTemplate?

    /// Canonical exercise identity for progress tracking.
    /// Nil for legacy data or exercises not yet linked to the catalog.
    var exerciseDefinition: ExerciseDefinition?

    @Relationship(deleteRule: .cascade, inverse: \PerformedSet.exerciseSession)
    var performedSets: [PerformedSet]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        order: Int,
        effort: Int? = nil,
        restSeconds: Int? = nil,
        workoutSession: WorkoutSession? = nil,
        exerciseTemplate: ExerciseTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.order = order
        self.effort = effort
        self.restSeconds = restSeconds
        self.workoutSession = workoutSession
        self.exerciseTemplate = exerciseTemplate
        self.performedSets = []
    }
}
