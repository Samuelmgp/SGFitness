import Foundation
import SwiftData
import Observation

// MARK: - WorkoutDetailViewModel
// Displays a single completed session with full drill-down.
// Supports edit mode for correcting past data.
//
// Stub — method bodies will be implemented in a future task.

@Observable
final class WorkoutDetailViewModel {

    private let modelContext: ModelContext

    /// The session being viewed/edited.
    let session: WorkoutSession

    /// Read vs edit mode toggle. UI-only.
    var isEditing: Bool = false

    /// Exercises sorted by order.
    var exercises: [ExerciseSession] {
        session.exercises.sorted { $0.order < $1.order }
    }

    /// Workout duration derived from timestamps.
    var duration: TimeInterval {
        guard let completedAt = session.completedAt else { return 0 }
        return completedAt.timeIntervalSince(session.startedAt)
    }

    /// Sum of (reps * weight) across all completed sets.
    var totalVolume: Double {
        exercises.flatMap(\.performedSets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + Double($1.reps) * ($1.weight ?? 0) }
    }

    /// Template name if this session was based on one.
    var templateName: String? {
        session.template?.name
    }

    init(modelContext: ModelContext, session: WorkoutSession) {
        self.modelContext = modelContext
        self.session = session
    }

    func toggleEditing() {
        isEditing.toggle()
    }

    func updateSet(_ set: PerformedSet, reps: Int, weight: Double?) {
        // TODO: Update set values, set session.updatedAt
    }

    func updateEffort(_ exercise: ExerciseSession, effort: Int) {
        // TODO: Set effort, set session.updatedAt
    }

    func updateNotes(_ notes: String) {
        // TODO: Update session notes, set session.updatedAt
    }

    func save() {
        // TODO: Persist edits, set session.updatedAt
    }
}
