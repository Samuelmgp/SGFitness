import Foundation

// MARK: - WorkoutStatus
// Persisted on WorkoutSession after completion. Computed by CalendarComputationService.
// Drives primary calendar day coloring (Green / Yellow / Purple).
// "Missed" and "RestDay" are calendar-level concepts derived from session gaps —
// they are NOT stored on a session.

enum WorkoutStatus: String, Codable, CaseIterable {
    case exceeded  = "exceeded"   // Purple: completed, exceeded target by 60+ min
    case targetMet = "targetMet"  // Green:  completed, met target duration
    case partial   = "partial"    // Yellow: completed, 10+ min but below target

    /// Compute status from actual duration and optional target.
    /// - Parameters:
    ///   - durationMinutes: Actual completed workout duration in whole minutes.
    ///   - targetMinutes:   Target duration, if the session had one set.
    static func compute(durationMinutes: Int, targetMinutes: Int?) -> WorkoutStatus {
        if let target = targetMinutes {
            if durationMinutes >= target + 60 { return .exceeded }
            if durationMinutes >= target       { return .targetMet }
            return .partial
        } else {
            // No target: treat 60+ min as a "met" session, anything under as partial.
            return durationMinutes >= 60 ? .targetMet : .partial
        }
    }
}
