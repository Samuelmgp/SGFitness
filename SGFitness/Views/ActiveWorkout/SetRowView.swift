import SwiftUI

// MARK: - SetRowView
// Displays a single set within an exercise row.
// Shows the set number, reps, weight, and completion status.
// Pre-populated sets (from template) start as incomplete and can be
// tapped to mark as done. Supports inline editing of reps/weight.

struct SetRowView: View {

    let set: PerformedSet
    let onComplete: (_ reps: Int, _ weight: Double?) -> Void

    @State private var showingEditAlert = false
    @State private var editReps: String = ""
    @State private var editWeight: String = ""

    var body: some View {
        HStack {
            // MARK: - Set Number
            Text("\(set.order + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            // MARK: - Reps (tappable to edit)
            Text("\(set.reps)")
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)

            // MARK: - Weight (tappable to edit)
            Text(formatWeight(set.weight))
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)

            // MARK: - Completion Toggle
            Button {
                if !set.isCompleted {
                    editReps = "\(set.reps)"
                    editWeight = set.weight.map { "\(Int($0))" } ?? ""
                    showingEditAlert = true
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
        .opacity(set.isCompleted ? 0.6 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if !set.isCompleted {
                editReps = "\(set.reps)"
                editWeight = set.weight.map { "\(Int($0))" } ?? ""
                showingEditAlert = true
            }
        }
        .alert("Complete Set", isPresented: $showingEditAlert) {
            TextField("Reps", text: $editReps)
                .keyboardType(.numberPad)
            TextField("Weight (optional)", text: $editWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Complete") {
                let reps = Int(editReps) ?? set.reps
                let weight = Double(editWeight)
                onComplete(reps, weight)
            }
        } message: {
            Text("Adjust reps and weight before completing.")
        }
    }

    // MARK: - Helpers

    private func formatWeight(_ weight: Double?) -> String {
        guard let weight else { return "BW" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
