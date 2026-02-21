import Foundation
import SwiftData

// MARK: - StretchEntry
// A stretch as actually performed within a WorkoutSession.
//
// Free-text name — no catalog required for Feature Group 1.
// A StretchDefinition catalog can be introduced later if autocomplete
// or cross-session stretch tracking becomes needed.
//
// `order` determines display position within the session.

@Model
final class StretchEntry {
    @Attribute(.unique) var id: UUID

    /// Stretch name as entered by the user (e.g. "Hip Flexor Stretch").
    var name: String

    /// How long the stretch was held, in seconds. Nil means untracked.
    var durationSeconds: Int?

    /// Position of this stretch within the session. 0-indexed.
    var order: Int

    var notes: String

    // MARK: - Relationships

    var workoutSession: WorkoutSession?

    init(
        id: UUID = UUID(),
        name: String,
        durationSeconds: Int? = nil,
        order: Int,
        notes: String = "",
        workoutSession: WorkoutSession? = nil
    ) {
        self.id = id
        self.name = name
        self.durationSeconds = durationSeconds
        self.order = order
        self.notes = notes
        self.workoutSession = workoutSession
    }
}
