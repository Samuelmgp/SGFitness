import Foundation
import SwiftData

// MARK: - User
// Represents the single local user of the app.
// Exists as a model (rather than UserDefaults) so that all user-owned data
// can be queried through relationships and to support future multi-profile
// or cloud-sync scenarios without a migration.

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    /// Display unit for weights. All persisted weights are stored in kg.
    var preferredWeightUnit: WeightUnit

    /// User's height stored in metres regardless of display preference.
    var heightMeters: Double?

    /// User's body weight stored in kg regardless of display preference.
    var bodyWeightKg: Double?

    /// Target workout frequency in days per week. Nil = no goal (calendar uses default gap of 2).
    var targetWorkoutDaysPerWeek: Int?

    /// Target workout duration in minutes. Nil = no goal (no default set on new sessions).
    var targetWorkoutMinutes: Int?

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.owner)
    var workoutTemplates: [WorkoutTemplate]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.user)
    var workoutSessions: [WorkoutSession]

    @Relationship(deleteRule: .cascade, inverse: \BadgeAward.user)
    var badgeAwards: [BadgeAward]

    @Relationship(deleteRule: .cascade, inverse: \ScheduledWorkout.user)
    var scheduledWorkouts: [ScheduledWorkout]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        preferredWeightUnit: WeightUnit = .lbs,
        heightMeters: Double? = nil,
        bodyWeightKg: Double? = nil,
        targetWorkoutDaysPerWeek: Int? = nil,
        targetWorkoutMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.preferredWeightUnit = preferredWeightUnit
        self.heightMeters = heightMeters
        self.bodyWeightKg = bodyWeightKg
        self.targetWorkoutDaysPerWeek = targetWorkoutDaysPerWeek
        self.targetWorkoutMinutes = targetWorkoutMinutes
        self.workoutTemplates = []
        self.workoutSessions = []
        self.badgeAwards = []
        self.scheduledWorkouts = []
    }
}
