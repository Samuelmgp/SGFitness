import Foundation
import SwiftData

// MARK: - StretchGoal
// A stretch target within a WorkoutTemplate.
//
// Mirrors StretchEntry in structure but records what the user plans to do.
// When saveAsTemplate() runs, StretchEntry records are copied to StretchGoal
// entries on the new template so stretch routines are preserved.
//
// `order` determines display position within the template.

@Model
final class StretchGoal {
    @Attribute(.unique) var id: UUID

    /// Stretch name (e.g. "Hip Flexor Stretch").
    var name: String

    /// Suggested hold duration in seconds. Nil means unspecified.
    var targetDurationSeconds: Int?

    /// Position of this stretch within the parent template. 0-indexed.
    var order: Int

    // MARK: - Relationships

    var workoutTemplate: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        name: String,
        targetDurationSeconds: Int? = nil,
        order: Int,
        workoutTemplate: WorkoutTemplate? = nil
    ) {
        self.id = id
        self.name = name
        self.targetDurationSeconds = targetDurationSeconds
        self.order = order
        self.workoutTemplate = workoutTemplate
    }
}
