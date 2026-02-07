import Foundation

// MARK: - WeightUnit
// Defines the unit of weight the user prefers for display.
// All persisted weight values are stored in kilograms (canonical unit).
// Conversion to/from the user's preferred unit happens at the view layer only.

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lbs

    var displayName: String {
        switch self {
        case .kg: return "kg"
        case .lbs: return "lbs"
        }
    }

    /// Converts a value FROM this unit TO kilograms (the canonical storage unit).
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lbs: return value * 0.45359237
        }
    }

    /// Converts a value FROM kilograms TO this unit for display.
    func fromKilograms(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lbs: return value / 0.45359237
        }
    }
}
