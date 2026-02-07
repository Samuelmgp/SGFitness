import SwiftUI

// MARK: - SetRowView
// Target folder: Views/ActiveWorkout/
//
// Displays a single set within an exercise row.
// Shows the set number, reps, weight, and completion status.
// Pre-populated sets (from template) start as incomplete and can be
// tapped to mark as done. Completed sets show a checkmark.
//
// Binds to: PerformedSet model properties.

struct SetRowView: View {

    /// The set data to display.
    let set: PerformedSet

    /// Callback when the user taps to complete this set.
    /// Passes the actual reps and weight (may differ from pre-populated values).
    let onComplete: (_ reps: Int, _ weight: Double?) -> Void

    var body: some View {
        HStack {
            // MARK: - Set Number
            // Binds to: set.order (0-indexed, display as 1-indexed)
            Text("\(set.order + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            // MARK: - Reps
            // Binds to: set.reps
            Text("\(set.reps)")
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)

            // MARK: - Weight
            // Binds to: set.weight (stored in kg, display conversion happens in parent)
            Text(formatWeight(set.weight))
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)

            // MARK: - Completion Toggle
            // Binds to: set.isCompleted
            Button {
                if !set.isCompleted {
                    // Mark as completed with current values.
                    // TODO: Show inline editor to adjust reps/weight before confirming.
                    onComplete(set.reps, set.weight)
                }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .frame(width: 44, alignment: .center)
        }
        .padding(.vertical, 2)
        // Dim completed sets to visually separate "done" from "to do"
        .opacity(set.isCompleted ? 0.6 : 1.0)
    }

    // MARK: - Helpers

    private func formatWeight(_ weight: Double?) -> String {
        guard let weight else { return "BW" }
        // Display with no decimal places if weight is a whole number
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
