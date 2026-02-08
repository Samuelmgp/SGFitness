import Foundation
import SwiftData

enum ScheduledWorkoutStatus: String, Codable {
    case planned, completed, skipped
}

@Model
final class ScheduledWorkout {
    @Attribute(.unique) var id: UUID

    /// Normalized to Calendar.current.startOfDay() for date-keyed lookups.
    var scheduledDate: Date
    var status: ScheduledWorkoutStatus
    var createdAt: Date

    // MARK: - Relationships

    var user: User?

    @Relationship(deleteRule: .nullify) var template: WorkoutTemplate?
    @Relationship(deleteRule: .nullify) var workoutSession: WorkoutSession?

    init(
        id: UUID = UUID(),
        scheduledDate: Date,
        status: ScheduledWorkoutStatus = .planned,
        createdAt: Date = .now,
        user: User? = nil,
        template: WorkoutTemplate? = nil,
        workoutSession: WorkoutSession? = nil
    ) {
        self.id = id
        self.scheduledDate = Calendar.current.startOfDay(for: scheduledDate)
        self.status = status
        self.createdAt = createdAt
        self.user = user
        self.template = template
        self.workoutSession = workoutSession
    }
}
