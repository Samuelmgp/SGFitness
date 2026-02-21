import Foundation
import SwiftData

// MARK: - WorkoutSession
// An actual workout that was (or is being) performed.
//
// - `startedAt`: when the user tapped "Start Workout".
// - `completedAt`: when the user tapped "Finish". Nil means in-progress.
// - `template`: optional reference to the WorkoutTemplate that inspired this
//   session. Nil for ad-hoc workouts. The reference is informational only;
//   the session's data is fully independent of the template.
//
// Sessions are editable after completion (the user can fix typos/mistakes).

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var startedAt: Date
    var completedAt: Date?
    var updatedAt: Date
    var targetDurationMinutes: Int?

    // MARK: - Calendar Intelligence

    /// Raw string backing for WorkoutStatus enum.
    /// Empty string until CalendarComputationService runs after session completion.
    var workoutStatusRaw: String = ""

    /// True when PersonalRecordService created at least one PR for this session.
    /// Set by CalendarComputationService after evaluatePRs() completes.
    /// Used as a fast-path flag so the calendar does not need to re-scan PersonalRecords.
    var hasPRs: Bool = false

    /// Typed accessor for the persisted status.
    var workoutStatus: WorkoutStatus? {
        WorkoutStatus(rawValue: workoutStatusRaw)
    }

    // MARK: - Relationships

    var user: User?

    /// The template this session was based on, if any. Nullified on template deletion
    /// so history is preserved even if the user deletes the template.
    @Relationship(deleteRule: .nullify) var template: WorkoutTemplate?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.workoutSession)
    var exercises: [ExerciseSession]

    @Relationship(deleteRule: .cascade, inverse: \StretchEntry.workoutSession)
    var stretches: [StretchEntry]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workoutSession)
    var workoutExercises: [WorkoutExercise]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        startedAt: Date = .now,
        completedAt: Date? = nil,
        updatedAt: Date = .now,
        targetDurationMinutes: Int? = nil,
        user: User? = nil,
        template: WorkoutTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.targetDurationMinutes = targetDurationMinutes
        self.user = user
        self.template = template
        self.workoutStatusRaw = ""
        self.hasPRs = false
        self.exercises = []
        self.stretches = []
        self.workoutExercises = []
    }
}
