import Foundation

// MARK: - ExerciseType
// Typed enum replacing the raw String field on ExerciseDefinition.
//
// Raw values are lowercase to match the strings already stored in the
// SwiftData store ("strength", "cardio"). Any change to these raw values
// would require a custom migration.

enum ExerciseType: String, Codable, CaseIterable {
    case strength = "strength"
    case cardio   = "cardio"

    /// Human-readable label for display in pickers and chips.
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio:   return "Cardio"
        }
    }

    /// SF Symbol name for this exercise type.
    var sfSymbol: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio:   return "figure.run"
        }
    }
}
