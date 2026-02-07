import SwiftUI

// MARK: - ExerciseRowView
// Target folder: Views/ActiveWorkout/
//
// Displays a single exercise within the active workout list.
// Shows the exercise name, effort rating, a list of SetRowViews,
// and an "Add Set" button at the bottom.
//
// Binds to: ExerciseSession model properties.
// Actions are closures passed from ActiveWorkoutView to route through the VM.

struct ExerciseRowView: View {

    /// The exercise data to display.
    let exercise: ExerciseSession

    /// Position of this exercise in the workout (for effort callback).
    let exerciseIndex: Int

    /// Whether this exercise is the user's current focus.
    let isCurrent: Bool

    /// Callback to log a brand-new set (ad-hoc or extra sets).
    let onLogSet: (_ reps: Int, _ weight: Double?) -> Void

    /// Callback to mark a pre-populated set as completed.
    let onCompleteSet: (_ set: PerformedSet, _ reps: Int, _ weight: Double?) -> Void

    /// Callback to set effort rating.
    let onSetEffort: (_ effort: Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // MARK: - Exercise Header
            HStack {
                // Binds to: exercise.name
                Text(exercise.name)
                    .font(.headline)

                Spacer()

                // Binds to: exercise.effort
                // Placeholder for effort rating control (1–10 scale)
                if let effort = exercise.effort {
                    Text("Effort: \(effort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Set List
            // Binds to: exercise.performedSets (sorted by order)
            let sortedSets = exercise.performedSets.sorted { $0.order < $1.order }

            if !sortedSets.isEmpty {
                // Column headers
                HStack {
                    Text("Set")
                        .frame(width: 36, alignment: .leading)
                    Text("Reps")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Done")
                        .frame(width: 44, alignment: .center)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(sortedSets, id: \.id) { set in
                    SetRowView(
                        set: set,
                        onComplete: { reps, weight in
                            onCompleteSet(set, reps, weight)
                        }
                    )
                }
            }

            // MARK: - Add Set Button
            Button {
                // TODO: Present input for reps/weight, then call onLogSet
                onLogSet(0, nil)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
        // Highlight the currently focused exercise
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.08) : nil)
    }
}
