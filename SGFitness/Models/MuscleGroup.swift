import Foundation

// MARK: - MuscleGroup
// Typed enum replacing the raw String? field on ExerciseDefinition.
//
// Raw values use Title Case to match the capitalized strings already stored
// in the SwiftData store from seedExerciseCatalog(). Any change to these
// raw values would require a custom migration.

enum MuscleGroup: String, Codable, CaseIterable {
    case chest     = "Chest"
    case back      = "Back"
    case legs      = "Legs"
    case shoulders = "Shoulders"
    case arms      = "Arms"
    case core      = "Core"

    /// SF Symbol name for this muscle group — used in exercise lists and cards.
    var sfSymbol: String {
        switch self {
        case .chest:     return "figure.arms.open"
        case .back:      return "figure.rowing"
        case .legs:      return "figure.walk"
        case .shoulders: return "figure.boxing"
        case .arms:      return "figure.mixed.cardio"
        case .core:      return "figure.core.training"
        }
    }
}
