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
    /// Called when user swipes to delete a set. Nil = swipe-to-delete hidden.
    let onRemoveSet: ((PerformedSet) -> Void)?
    /// Called when user taps the checkmark of an already-completed set to un-complete it.
    let onDeselectSet: ((PerformedSet) -> Void)?
    /// Called when user swipes the exercise header and taps the remove button. Nil = swipe hidden.
    let onRemoveExercise: (() -> Void)?

    @State private var showingAddSet = false
    @State private var newSetReps: String = "10"
    @State private var newSetWeight: String = ""
    @State private var newSetDuration: String = ""
    @State private var headerSwiped = false

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
            // MARK: - Exercise Header (swipe left to reveal Remove button)
            ZStack(alignment: .trailing) {
                HStack(spacing: 10) {
                    // Muscle-group body diagram or cardio SF symbol badge
                    if let muscleGroup = exercise.exerciseDefinition?.muscleGroup {
                        MuscleDiagramView(muscleGroup: muscleGroup, size: 32)
                    } else {
                        let iconColor = Color.secondary
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(iconColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: exercise.exerciseDefinition?.exerciseType.sfSymbol ?? "dumbbell")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(iconColor)
                        }
                    }

                    Text(exercise.name)
                        .font(.headline)
                    Spacer()
                    if allSetsComplete && !headerSwiped {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                }
                .offset(x: headerSwiped && onRemoveExercise != nil ? -80 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: headerSwiped)

                if onRemoveExercise != nil {
                    Button(role: .destructive) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            headerSwiped = false
                        }
                        onRemoveExercise?()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.subheadline.bold())
                            Text("Remove")
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 36)
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .opacity(headerSwiped ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: headerSwiped)
                }
            }
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        guard onRemoveExercise != nil else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if value.translation.width < -50 {
                                headerSwiped = true
                            } else if value.translation.width > 20 {
                                headerSwiped = false
                            }
                        }
                    }
            )

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
                    },
                    onDeselect: onDeselectSet.map { handler in { handler(set) } },
                    onRemove: onRemoveSet.map { handler in { handler(set) } }
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
                    let weightKg = Double(newSetWeight).map { weightUnit.toKilograms($0) }
                    onLogSet(reps, weightKg, nil)
                }
            }
        } message: {
            Text(isCardio ? "Enter distance and time for this set." : "Enter reps and weight for this set.")
        }
    }

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
//
// Displays a single set row with:
//   - Tap circle: complete an incomplete set, or de-select a completed set.
//   - Long-press: edit values. Title changes based on whether the set is completed.
//   - Swipe left (when onRemove is provided): reveals a red Delete button.

struct SetCircleRow: View {

    let set: PerformedSet
    let isCardio: Bool
    let weightUnit: WeightUnit
    /// Called when tapping an incomplete set's circle (or long-press → "Complete").
    let onComplete: (_ reps: Int, _ weight: Double?, _ durationSeconds: Int?) -> Void
    /// Called when tapping a completed set's circle. Nil = tapping completed circle is a no-op.
    let onDeselect: (() -> Void)?
    /// Called after confirming swipe-to-delete. Nil = swipe gesture not active.
    let onRemove: (() -> Void)?

    @State private var showingEdit = false
    @State private var editReps: String = ""
    @State private var editWeight: String = ""
    @State private var editDuration: String = ""
    /// Captures whether the set was completed at the moment of long-press,
    /// so the alert title/button text is stable while the alert is shown.
    @State private var editingWasCompleted = false
    @State private var swiped = false

    var body: some View {
        ZStack(alignment: .trailing) {
            rowContent
                .offset(x: swiped && onRemove != nil ? -72 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swiped)

            // Delete button — only visible when swiped and onRemove is provided.
            if onRemove != nil {
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        swiped = false
                    }
                    onRemove?()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                        .font(.subheadline.bold())
                        .frame(width: 68)
                        .frame(maxHeight: .infinity)
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .opacity(swiped ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swiped)
            }
        }
        .clipped()
        // Horizontal swipe to reveal/hide delete button.
        // The gesture is always registered but only acts when onRemove is provided,
        // so it doesn't interfere with vertical scrolling when delete is disabled.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    guard onRemove != nil else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if value.translation.width < -40 {
                            swiped = true
                        } else if value.translation.width > 20 {
                            swiped = false
                        }
                    }
                }
        )
        .alert(
            editingWasCompleted ? "Edit Set" : "Edit & Complete",
            isPresented: $showingEdit
        ) {
            if isCardio {
                TextField("Distance (m)", text: $editReps).keyboardType(.numberPad)
                TextField("Duration (mm:ss)", text: $editDuration)
                Button("Cancel", role: .cancel) {}
                Button(editingWasCompleted ? "Save" : "Complete") {
                    let reps = Int(editReps) ?? set.reps
                    let duration = parseDuration(editDuration) ?? set.durationSeconds
                    onComplete(reps, nil, duration)
                }
            } else {
                TextField("Reps", text: $editReps).keyboardType(.numberPad)
                TextField("Weight (\(weightUnit.displayName), optional)", text: $editWeight).keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button(editingWasCompleted ? "Save" : "Complete") {
                    let reps = Int(editReps) ?? set.reps
                    let weightKg = Double(editWeight).map { weightUnit.toKilograms($0) }
                    onComplete(reps, weightKg, nil)
                }
            }
        } message: {
            Text(editingWasCompleted ? "Adjust the recorded values." : "Adjust values before completing.")
        }
    }

    // MARK: - Row Content

    private var rowContent: some View {
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

            // Complete / de-select circle button.
            Button {
                if set.isCompleted {
                    // Dismiss swipe state first if open.
                    withAnimation { swiped = false }
                    onDeselect?()
                } else {
                    if isCardio {
                        onComplete(set.reps, nil, set.durationSeconds)
                    } else {
                        onComplete(set.reps, set.weight, nil)
                    }
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
            // Capture completed state before alert is shown.
            editingWasCompleted = set.isCompleted
            if isCardio {
                editReps = "\(set.reps)"
                let dur = formatDuration(set.durationSeconds)
                editDuration = dur == "--:--" ? "" : dur
            } else {
                editReps = "\(set.reps)"
                editWeight = set.weight.map { displayWeight($0) } ?? ""
            }
            showingEdit = true
        }
    }

    // MARK: - Helpers

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
