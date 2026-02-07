import SwiftUI

// MARK: - BadgeView
// Target folder: Views/Shared/
//
// A presentational component that displays a single badge.
// Can show in "earned" or "locked" state based on whether a BadgeAward exists.
// No ViewModel — this is a pure display component.
//
// Binds to: Badge model properties, optional BadgeAward for earned state.

struct BadgeView: View {

    /// The badge definition to display.
    let badge: Badge

    /// Whether the user has earned this badge. Controls visual state.
    let isEarned: Bool

    /// When the badge was earned (if applicable).
    let awardedAt: Date?

    init(badge: Badge, award: BadgeAward? = nil) {
        self.badge = badge
        self.isEarned = award != nil
        self.awardedAt = award?.awardedAt
    }

    var body: some View {
        VStack(spacing: 8) {

            // MARK: - Badge Icon
            // Binds to: badge.iconName
            Image(systemName: badge.iconName)
                .font(.largeTitle)
                .foregroundStyle(isEarned ? .yellow : .gray)
                .symbolVariant(isEarned ? .fill : .none)

            // MARK: - Badge Name
            // Binds to: badge.name
            Text(badge.name)
                .font(.caption.bold())
                .multilineTextAlignment(.center)

            // MARK: - Badge Description
            // Binds to: badge.badgeDescription
            Text(badge.badgeDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // MARK: - Earned Date
            if let awardedAt {
                Text(awardedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        // Dim locked badges
        .opacity(isEarned ? 1.0 : 0.5)
    }
}
