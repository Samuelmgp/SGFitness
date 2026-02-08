import SwiftUI

// MARK: - ExerciseCardView
// Redesigned exercise display for the active workout.
// Shows exercises as grouped cards with per-set completion circles.

struct ExerciseCardView: View {

    let exercise: ExerciseSession
    let exerciseIndex: Int
    let onCompleteSet: (_ set: PerformedSet, _ reps: Int, _ weight: Double?) -> Void
    let onLogSet: (_ reps: Int, _ weight: Double?) -> Void

    @State private var showingAddSet = false
    @State private var newSetReps: String = "10"
    @State private var newSetWeight: String = ""

    private var sortedSets: [PerformedSet] {
        exercise.performedSets.sorted { $0.order < $1.order }
    }

    private var allSetsComplete: Bool {
        !sortedSets.isEmpty && sortedSets.allSatisfy(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Exercise Header
            HStack {
                Text(exercise.name)
                    .font(.headline)

                Spacer()

                if allSetsComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }

            // MARK: - Set Grid Header
            if !sortedSets.isEmpty {
                HStack {
                    Text("SET")
                        .frame(width: 36, alignment: .leading)
                    Text("REPS")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("WEIGHT")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer().frame(width: 40)
                }
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            }

            // MARK: - Set Rows
            ForEach(sortedSets, id: \.id) { set in
                SetCircleRow(
                    set: set,
                    onComplete: { reps, weight in
                        onCompleteSet(set, reps, weight)
                    }
                )
            }

            // MARK: - Add Set
            Button {
                let lastSet = sortedSets.last
                newSetReps = lastSet.map { "\($0.reps)" } ?? "10"
                newSetWeight = lastSet?.weight.map { "\(Int($0))" } ?? ""
                showingAddSet = true
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Log Set", isPresented: $showingAddSet) {
            TextField("Reps", text: $newSetReps)
                .keyboardType(.numberPad)
            TextField("Weight (optional)", text: $newSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Log") {
                let reps = Int(newSetReps) ?? 0
                let weight = Double(newSetWeight)
                guard reps > 0 else { return }
                onLogSet(reps, weight)
            }
        } message: {
            Text("Enter reps and weight for this set.")
        }
    }
}

// MARK: - SetCircleRow
// A single set row with a tappable completion circle.

struct SetCircleRow: View {

    let set: PerformedSet
    let onComplete: (_ reps: Int, _ weight: Double?) -> Void

    @State private var showingEdit = false
    @State private var editReps: String = ""
    @State private var editWeight: String = ""

    var body: some View {
        HStack {
            Text("\(set.order + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            Text("\(set.reps)")
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)

            Text(formatWeight(set.weight))
                .font(.body.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .center)

            // Completion circle
            Button {
                if set.isCompleted { return }
                // Single tap: auto-complete with pre-filled values
                onComplete(set.reps, set.weight)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.isCompleted ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .frame(width: 40)
        }
        .padding(.vertical, 2)
        .opacity(set.isCompleted ? 0.7 : 1.0)
        .contentShape(Rectangle())
        .onLongPressGesture {
            if !set.isCompleted {
                editReps = "\(set.reps)"
                editWeight = set.weight.map { "\(Int($0))" } ?? ""
                showingEdit = true
            }
        }
        .alert("Edit & Complete", isPresented: $showingEdit) {
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
            Text("Adjust values before completing.")
        }
    }

    private func formatWeight(_ weight: Double?) -> String {
        guard let weight else { return "BW" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}
