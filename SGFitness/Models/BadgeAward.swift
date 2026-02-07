import Foundation
import SwiftData

// MARK: - BadgeAward
// Records the moment a user earns a specific badge.
// This is the join between User and Badge with a timestamp.
// One award per badge per user — duplicates should be prevented at the logic layer.

@Model
final class BadgeAward {
    @Attribute(.unique) var id: UUID
    var awardedAt: Date

    // MARK: - Relationships

    var user: User?
    var badge: Badge?

    init(
        id: UUID = UUID(),
        awardedAt: Date = .now,
        user: User? = nil,
        badge: Badge? = nil
    ) {
        self.id = id
        self.awardedAt = awardedAt
        self.user = user
        self.badge = badge
    }
}
