import SwiftUI

// MARK: - ExerciseRowView
// Displays a single exercise within the active workout list.
// Shows the exercise name, effort rating, a list of SetRowViews,
// and an "Add Set" button at the bottom.

struct ExerciseRowView: View {

    let exercise: ExerciseSession
    let exerciseIndex: Int
    let isCurrent: Bool
    let onLogSet: (_ reps: Int, _ weight: Double?) -> Void
    let onCompleteSet: (_ set: PerformedSet, _ reps: Int, _ weight: Double?) -> Void
    let onSetEffort: (_ effort: Int) -> Void

    @State private var showingAddSetAlert = false
    @State private var newSetReps: String = "10"
    @State private var newSetWeight: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // MARK: - Exercise Header
            HStack {
                Text(exercise.name)
                    .font(.headline)

                Spacer()

                if let effort = exercise.effort {
                    Text("Effort: \(effort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Set List
            let sortedSets = exercise.performedSets.sorted { $0.order < $1.order }

            if !sortedSets.isEmpty {
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
                // Pre-fill from last set if available
                let lastSet = sortedSets.last
                newSetReps = lastSet.map { "\($0.reps)" } ?? "10"
                newSetWeight = lastSet?.weight.map { "\(Int($0))" } ?? ""
                showingAddSetAlert = true
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
        .listRowBackground(isCurrent ? Color.accentColor.opacity(0.08) : nil)
        .alert("Log Set", isPresented: $showingAddSetAlert) {
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
