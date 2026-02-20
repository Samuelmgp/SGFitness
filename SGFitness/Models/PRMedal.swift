import Foundation

enum PRMedal: String, Codable, CaseIterable {
    case gold   = "gold"
    case silver = "silver"
    case bronze = "bronze"

    var rank: Int {
        switch self {
        case .gold:   return 1
        case .silver: return 2
        case .bronze: return 3
        }
    }

    var sfSymbol: String {
        switch self {
        case .gold:   return "1.circle.fill"
        case .silver: return "2.circle.fill"
        case .bronze: return "3.circle.fill"
        }
    }
}
