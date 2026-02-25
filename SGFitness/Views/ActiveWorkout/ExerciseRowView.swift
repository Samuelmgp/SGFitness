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
                        muscleGroup != .back ? MuscleDiagramView(muscleGroup: muscleGroup, side: .front, size: 32) : MuscleDiagramView(muscleGroup: muscleGroup, side: .back, size: 32)
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
                    VStack(alignment: .leading, spacing: 2){
                        Text(exercise.name)
                            .font(.headline)
                        Text(exercise.exerciseDefinition?.equipment ?? "Unknown Equiptment")
                            .font(.footnote)
                            .fontWeight(.light)
                    }
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
        .sheet(isPresented: $showingAddSet) {
            let last = sortedSets.last
            let initReps    = isCardio ? (last.map { "\($0.reps)" } ?? "800") : (last.map { "\($0.reps)" } ?? "10")
            let initWeight  = last?.weight.map { displayWeight($0) } ?? ""
            let initDuration = last?.durationSeconds.map { formatDuration($0) } ?? ""

            AddSetSheet(
                isCardio: isCardio,
                weightUnit: weightUnit,
                initialReps: initReps,
                initialWeight: initWeight,
                initialDuration: initDuration
            ) { reps, weightKg, durationSeconds in
                onLogSet(reps, weightKg, durationSeconds)
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
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

// MARK: - AddSetSheet
//
// Half-sheet presented when the user taps "Add Set" on an ExerciseCardView.
// Replaces the old .alert to give labelled fields, a numeric keyboard that
// stays visible, and a prominent action button.

private struct AddSetSheet: View {

    let isCardio:   Bool
    let weightUnit: WeightUnit
    let onLog:      (Int, Double?, Int?) -> Void

    @State private var reps:     String
    @State private var weight:   String
    @State private var duration: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: InputField?

    private enum InputField { case primary, secondary }

    init(isCardio: Bool,
         weightUnit: WeightUnit,
         initialReps: String,
         initialWeight: String,
         initialDuration: String,
         onLog: @escaping (Int, Double?, Int?) -> Void) {
        self.isCardio   = isCardio
        self.weightUnit = weightUnit
        self.onLog      = onLog
        _reps           = State(initialValue: initialReps)
        _weight         = State(initialValue: initialWeight)
        _duration       = State(initialValue: initialDuration)
    }

    private var canLog: Bool {
        if isCardio {
            return (Int(reps) ?? 0) > 0 && parseDuration(duration) != nil
        }
        return (Int(reps) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // Primary field — Reps (strength) or Distance in metres (cardio)
                inputField(
                    label:    isCardio ? "Distance (m)" : "Reps",
                    text:     $reps,
                    keyboard: .numberPad,
                    field:    .primary
                )

                // Secondary field — Weight (strength, optional) or Duration mm:ss (cardio)
                inputField(
                    label:    isCardio ? "Duration (mm:ss)" : "Weight (\(weightUnit.displayName), optional)",
                    text:     isCardio ? $duration : $weight,
                    keyboard: isCardio ? .default : .decimalPad,
                    field:    .secondary
                )

                Spacer()

                Button {
                    commitLog()
                } label: {
                    Text("Log Set")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canLog)
            }
            .padding(20)
            .navigationTitle(isCardio ? "Log Cardio Set" : "Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            // Brief delay lets the sheet animate in before the keyboard rises.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focused = .primary
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func inputField(label: String,
                            text: Binding<String>,
                            keyboard: UIKeyboardType,
                            field: InputField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($focused, equals: field)
        }
    }

    private func commitLog() {
        if isCardio {
            let dist = Int(reps) ?? 0
            guard let dur = parseDuration(duration), dist > 0 else { return }
            onLog(dist, nil, dur)
        } else {
            let r = Int(reps) ?? 0
            guard r > 0 else { return }
            let weightKg = Double(weight).map { weightUnit.toKilograms($0) }
            onLog(r, weightKg, nil)
        }
        dismiss()
    }

    private func parseDuration(_ str: String) -> Int? {
        let parts = str.split(separator: ":").map { String($0) }
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) { return m * 60 + s }
        if parts.count == 1, let t = Int(parts[0]) { return t }
        return nil
    }
}

// MARK: - EditSetSheet
//
// Half-sheet for editing an existing set's values (long-press on a SetCircleRow).
// When wasCompleted is false the button reads "Complete" and tapping it both
// saves the new values and marks the set complete — matching the old alert behaviour.

private struct EditSetSheet: View {

    let isCardio:     Bool
    let weightUnit:   WeightUnit
    let wasCompleted: Bool
    let onSave:       (Int, Double?, Int?) -> Void

    @State private var reps:     String
    @State private var weight:   String
    @State private var duration: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: InputField?

    private enum InputField { case primary, secondary }

    init(isCardio: Bool,
         weightUnit: WeightUnit,
         wasCompleted: Bool,
         initialReps: String,
         initialWeight: String,
         initialDuration: String,
         onSave: @escaping (Int, Double?, Int?) -> Void) {
        self.isCardio     = isCardio
        self.weightUnit   = weightUnit
        self.wasCompleted = wasCompleted
        self.onSave       = onSave
        _reps     = State(initialValue: initialReps)
        _weight   = State(initialValue: initialWeight)
        _duration = State(initialValue: initialDuration)
    }

    private var canSave: Bool {
        if isCardio { return (Int(reps) ?? 0) > 0 && parseDuration(duration) != nil }
        return (Int(reps) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                inputField(
                    label:    isCardio ? "Distance (m)" : "Reps",
                    text:     $reps,
                    keyboard: .numberPad,
                    field:    .primary
                )

                inputField(
                    label:    isCardio ? "Duration (mm:ss)" : "Weight (\(weightUnit.displayName), optional)",
                    text:     isCardio ? $duration : $weight,
                    keyboard: isCardio ? .default : .decimalPad,
                    field:    .secondary
                )

                Spacer()

                Button {
                    commitSave()
                } label: {
                    Text(wasCompleted ? "Save" : "Complete")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSave)
            }
            .padding(20)
            .navigationTitle(wasCompleted ? "Edit Set" : "Edit & Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focused = .primary
            }
        }
    }

    @ViewBuilder
    private func inputField(label: String,
                            text: Binding<String>,
                            keyboard: UIKeyboardType,
                            field: InputField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($focused, equals: field)
        }
    }

    private func commitSave() {
        if isCardio {
            let dist = Int(reps) ?? 0
            guard let dur = parseDuration(duration), dist > 0 else { return }
            onSave(dist, nil, dur)
        } else {
            let r = Int(reps) ?? 0
            guard r > 0 else { return }
            let weightKg = Double(weight).map { weightUnit.toKilograms($0) }
            onSave(r, weightKg, nil)
        }
        dismiss()
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
        .sheet(isPresented: $showingEdit) {
            EditSetSheet(
                isCardio: isCardio,
                weightUnit: weightUnit,
                wasCompleted: editingWasCompleted,
                initialReps: editReps,
                initialWeight: editWeight,
                initialDuration: editDuration
            ) { reps, weightKg, durationSeconds in
                onComplete(reps, weightKg, durationSeconds)
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
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
