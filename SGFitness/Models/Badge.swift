import Foundation
import SwiftData

// MARK: - Badge
// Defines a badge that can be earned (e.g. "First Workout", "100 Sessions").
// Badge definitions are reference data — they describe *what* can be earned.
// The actual earning event is recorded in BadgeAward.
//
// Badges are seeded by the app on first launch and are not user-created.

@Model
final class Badge {
    @Attribute(.unique) var id: UUID

    /// Machine-readable key used to identify the badge in code (e.g. "first_workout").
    @Attribute(.unique) var key: String

    /// Human-readable display name (e.g. "First Workout").
    var name: String

    /// Short description shown to the user (e.g. "Complete your first workout").
    var badgeDescription: String

    /// SF Symbol name for display.
    var iconName: String

    // MARK: - Relationships

    @Relationship(deleteRule: .deny, inverse: \BadgeAward.badge)
    var awards: [BadgeAward]

    init(
        id: UUID = UUID(),
        key: String,
        name: String,
        badgeDescription: String,
        iconName: String
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.badgeDescription = badgeDescription
        self.iconName = iconName
        self.awards = []
    }
}
