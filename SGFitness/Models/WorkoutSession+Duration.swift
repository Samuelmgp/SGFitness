import Foundation

// MARK: - WorkoutSession + Duration
// Computed duration helpers — derived from startedAt/completedAt.
// No stored field is needed; these are always consistent with the session dates.

extension WorkoutSession {
    /// Elapsed duration of the workout in seconds.
    /// Returns nil if the session is still in progress (completedAt is nil).
    var durationSeconds: TimeInterval? {
        guard let end = completedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    /// Elapsed duration rounded down to whole minutes.
    /// Returns nil if the session is still in progress.
    var durationMinutes: Int? {
        durationSeconds.map { Int($0 / 60) }
    }
}
