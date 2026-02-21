import Foundation
import SwiftUI

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
        case .chest:     return "figure.strengthtraining.traditional"
        case .back:      return "figure.rowing"
        case .legs:      return "figure.run"
        case .shoulders: return "figure.handball"
        case .arms:      return "figure.boxing"
        case .core:      return "figure.core.training"
        }
    }

    /// Accent colour for this muscle group — used on icon badges in exercise lists.
    var color: Color {
        switch self {
        case .chest:     return Color(red: 0.20, green: 0.48, blue: 0.96)  // blue
        case .back:      return Color(red: 0.20, green: 0.72, blue: 0.40)  // green
        case .legs:      return Color(red: 0.96, green: 0.56, blue: 0.13)  // orange
        case .shoulders: return Color(red: 0.62, green: 0.32, blue: 0.90)  // purple
        case .arms:      return Color(red: 0.95, green: 0.28, blue: 0.28)  // red
        case .core:      return Color(red: 0.92, green: 0.72, blue: 0.10)  // amber
        }
    }
}
