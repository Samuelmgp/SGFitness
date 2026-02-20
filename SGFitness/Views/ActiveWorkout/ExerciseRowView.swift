import SwiftUI

// MARK: - ExerciseCardView
// Shows exercises as grouped cards with per-set completion circles.
// Supports both strength exercises (reps + weight) and cardio (distance + duration).
// Weight values are always stored/passed in kg; display conversion uses weightUnit.

struct ExerciseCardView: View {

    let exercise: ExerciseSession
    let exerciseIndex: Int
    let weightUnit: WeightUnit
    let onCompleteSet: (_ set: PerformedSet, _ reps: Int, _ weight: Double?, _ durationSeconds: Int?) -> Void
    /// weight parameter is already in kg (converted by this view before calling)
    let onLogSet: (_ reps: Int, _ weight: Double?, _ durationSeconds: Int?) -> Void

    @State private var showingAddSet = false
    @State private var newSetReps: String = "10"
    @State private var newSetWeight: String = ""
    @State private var newSetDuration: String = ""

    private var isCardio: Bool {
        exercise.exerciseDefinition?.exerciseType == .cardio
    }

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
                    Text("SET").frame(width: 36, alignment: .leading)
                    if isCardio {
                        Text("DIST (m)").frame(maxWidth: .infinity, alignment: .center)
                        Text("TIME").frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("REPS").frame(maxWidth: .infinity, alignment: .center)
                        Text("WT (\(weightUnit.displayName.uppercased()))").frame(maxWidth: .infinity, alignment: .center)
                    }
                    Spacer().frame(width: 40)
                }
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            }

            // MARK: - Set Rows
            ForEach(sortedSets, id: \.id) { set in
                SetCircleRow(
                    set: set,
                    isCardio: isCardio,
                    weightUnit: weightUnit,
                    onComplete: { reps, weight, durationSeconds in
                        onCompleteSet(set, reps, weight, durationSeconds)
                    }
                )
            }

            // MARK: - Add Set
            Button {
                if isCardio {
                    let last = sortedSets.last
                    newSetReps = last.map { "\($0.reps)" } ?? "800"
                    newSetDuration = last?.durationSeconds.map { formatDuration($0) } ?? ""
                } else {
                    let last = sortedSets.last
                    newSetReps = last.map { "\($0.reps)" } ?? "10"
                    // Pre-fill in user's display unit
                    newSetWeight = last?.weight.map { displayWeight($0) } ?? ""
                }
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
        .alert(isCardio ? "Log Cardio Set" : "Log Set", isPresented: $showingAddSet) {
            if isCardio {
                TextField("Distance (m)", text: $newSetReps)
                    .keyboardType(.numberPad)
                TextField("Duration (mm:ss)", text: $newSetDuration)
                Button("Cancel", role: .cancel) {}
                Button("Log") {
                    let distance = Int(newSetReps) ?? 0
                    guard let duration = parseDuration(newSetDuration), distance > 0 else { return }
                    onLogSet(distance, nil, duration)
                }
            } else {
                TextField("Reps", text: $newSetReps)
                    .keyboardType(.numberPad)
                TextField("Weight (\(weightUnit.displayName), optional)", text: $newSetWeight)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Log") {
                    let reps = Int(newSetReps) ?? 0
                    guard reps > 0 else { return }
                    // Convert entered display-unit value → kg for storage
                    let weightKg = Double(newSetWeight).map { weightUnit.toKilograms($0) }
                    onLogSet(reps, weightKg, nil)
                }
            }
        } message: {
            Text(isCardio ? "Enter distance and time for this set." : "Enter reps and weight for this set.")
        }
    }

    // Display a stored-kg value in the user's preferred unit
    private func displayWeight(_ kg: Double) -> String {
        let v = weightUnit.fromKilograms(kg)
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func parseDuration(_ str: String) -> Int? {
        let parts = str.split(separator: ":").map { String($0) }
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) { return m * 60 + s }
        if parts.count == 1, let t = Int(parts[0]) { return t }
        return nil
    }
}

// MARK: - SetCircleRow

struct SetCircleRow: View {

    let set: PerformedSet
    let isCardio: Bool
    let weightUnit: WeightUnit
    let onComplete: (_ reps: Int, _ weight: Double?, _ durationSeconds: Int?) -> Void

    @State private var showingEdit = false
    @State private var editReps: String = ""
    @State private var editWeight: String = ""
    @State private var editDuration: String = ""

    var body: some View {
        HStack {
            Text("\(set.order + 1)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            if isCardio {
                Text("\(set.reps)m")
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(formatDuration(set.durationSeconds))
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("\(set.reps)")
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(formatWeight(set.weight))
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                if set.isCompleted { return }
                if isCardio {
                    onComplete(set.reps, nil, set.durationSeconds)
                } else {
                    onComplete(set.reps, set.weight, nil)
                }
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
            guard !set.isCompleted else { return }
            if isCardio {
                editReps = "\(set.reps)"
                let dur = formatDuration(set.durationSeconds)
                editDuration = dur == "--:--" ? "" : dur
            } else {
                editReps = "\(set.reps)"
                // Show in user's display unit
                editWeight = set.weight.map { displayWeight($0) } ?? ""
            }
            showingEdit = true
        }
        .alert("Edit & Complete", isPresented: $showingEdit) {
            if isCardio {
                TextField("Distance (m)", text: $editReps).keyboardType(.numberPad)
                TextField("Duration (mm:ss)", text: $editDuration)
                Button("Cancel", role: .cancel) {}
                Button("Complete") {
                    let reps = Int(editReps) ?? set.reps
                    let duration = parseDuration(editDuration) ?? set.durationSeconds
                    onComplete(reps, nil, duration)
                }
            } else {
                TextField("Reps", text: $editReps).keyboardType(.numberPad)
                TextField("Weight (\(weightUnit.displayName), optional)", text: $editWeight).keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Complete") {
                    let reps = Int(editReps) ?? set.reps
                    // Convert display-unit input → kg for storage
                    let weightKg = Double(editWeight).map { weightUnit.toKilograms($0) }
                    onComplete(reps, weightKg, nil)
                }
            }
        } message: {
            Text("Adjust values before completing.")
        }
    }

    /// Converts a stored-kg value to the display unit for rendering.
    private func formatWeight(_ kg: Double?) -> String {
        guard let kg else { return "BW" }
        let v = weightUnit.fromKilograms(kg)
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func displayWeight(_ kg: Double) -> String {
        let v = weightUnit.fromKilograms(kg)
        return v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func formatDuration(_ seconds: Int?) -> String {
        guard let s = seconds else { return "--:--" }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func parseDuration(_ str: String) -> Int? {
        let parts = str.split(separator: ":").map { String($0) }
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) { return m * 60 + s }
        if parts.count == 1, let t = Int(parts[0]) { return t }
        return nil
    }
}
