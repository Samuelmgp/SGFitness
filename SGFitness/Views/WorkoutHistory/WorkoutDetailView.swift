import SwiftUI
import SwiftData

// MARK: - WorkoutDetailView
// Target folder: Views/WorkoutHistory/
//
// Displays a single completed workout session with full drill-down.
// Shows summary stats (duration, total volume, template origin),
// the full exercise list with performed sets, and supports an edit mode
// for correcting past data (tappable sets, add/delete sets, add exercises).
//
// Binds to: WorkoutDetailViewModel

struct WorkoutDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: WorkoutDetailViewModel

    // Template save alert
    @State private var showingSavedAsTemplateAlert = false

    // Exercise picker (add exercise) — item-based sheet so data is always ready on first render
    @State private var exercisePickerVM: ExercisePickerViewModel?

    // Add set sheet — item drives presentation
    @State private var addSetForExercise: ExerciseSession?

    // Edit set sheet — item drives presentation
    @State private var editingSet: PerformedSet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - Summary Header
                summaryHeader

                Divider()

                // MARK: - Exercise List
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    exerciseSection(exercise)
                }

                // MARK: - Stretch List
                if !viewModel.stretches.isEmpty {
                    stretchesSection
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Add Exercise button — only in edit mode
            if viewModel.isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        let vm = ExercisePickerViewModel(modelContext: modelContext)
                        vm.fetchDefinitions()
                        exercisePickerVM = vm
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if viewModel.isEditing {
                    Button("Done") {
                        viewModel.save()
                        viewModel.toggleEditing()
                    }
                    .fontWeight(.semibold)
                } else {
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            viewModel.toggleEditing()
                        }
                        Button("Save as Template", systemImage: "square.and.arrow.down") {
                            viewModel.saveAsTemplate()
                            showingSavedAsTemplateAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Saved as Template", isPresented: $showingSavedAsTemplateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(viewModel.session.name)\" has been added to your Templates.")
        }
        .sheet(item: $addSetForExercise) { exercise in
            let sortedSets = exercise.performedSets.sorted { $0.order < $1.order }
            let initReps   = sortedSets.last.map { "\($0.reps)" } ?? "10"
            let initWeight = sortedSets.last?.weight.map { formatWeightForInput($0) } ?? ""
            DetailAddSetSheet(
                weightUnit: viewModel.preferredWeightUnit,
                initialReps: initReps,
                initialWeight: initWeight
            ) { reps, weightKg in
                viewModel.addSet(to: exercise, reps: reps, weight: weightKg)
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .sheet(item: $editingSet) { set in
            let initReps   = "\(set.reps)"
            let initWeight = set.weight.map { formatWeightForInput($0) } ?? ""
            DetailEditSetSheet(
                weightUnit: viewModel.preferredWeightUnit,
                initialReps: initReps,
                initialWeight: initWeight
            ) { reps, weightKg in
                viewModel.updateSet(set, reps: reps, weight: weightKg)
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .sheet(item: $exercisePickerVM) { pickerVM in
            ExercisePickerView(viewModel: pickerVM) { definition in
                viewModel.addExercise(from: definition)
                exercisePickerVM = nil
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let templateName = viewModel.templateName {
                Label(templateName, systemImage: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                statItem(
                    label: "Duration",
                    value: formatDuration(viewModel.duration)
                )
                statItem(
                    label: "Volume",
                    value: formatVolume(viewModel.totalVolume)
                )
                statItem(
                    label: "Exercises",
                    value: "\(viewModel.exercises.count)"
                )
            }

            if !viewModel.session.notes.isEmpty {
                Text(viewModel.session.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Exercise Section

    private func exerciseSection(_ exercise: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise header
            HStack {
                Text(exercise.name)
                    .font(.headline)

                Spacer()

                if let effort = exercise.effort, !viewModel.isEditing {
                    Text("Effort: \(effort)/10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isEditing {
                    Button(role: .destructive) {
                        viewModel.removeExercise(exercise)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Set rows
            let sortedSets = exercise.performedSets.sorted { $0.order < $1.order }
            ForEach(sortedSets, id: \.id) { set in
                HStack {
                    Text("Set \(set.order + 1)")
                        .frame(width: 50, alignment: .leading)

                    Text("\(set.reps) reps")
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(weightDisplayText(set.weight))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(set.isCompleted ? .green : .red)

                    if viewModel.isEditing {
                        Button(role: .destructive) {
                            viewModel.removeSet(set)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.subheadline)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard viewModel.isEditing else { return }
                    editingSet = set
                }
            }

            // Add Set button — edit mode only
            if viewModel.isEditing {
                Button {
                    addSetForExercise = exercise
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .padding(.top, 2)
            }

            Divider()
        }
    }

    // MARK: - Stretch Section

    private var stretchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Stretches", systemImage: "figure.flexibility")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.stretches.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.stretches, id: \.id) { stretch in
                HStack {
                    Text(stretch.name)
                        .font(.subheadline)
                    Spacer()
                    if let dur = stretch.durationSeconds {
                        Text("\(dur)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
        }
    }

    // MARK: - Helpers

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Converts a stored kg weight to the user's preferred unit for display.
    private func weightDisplayText(_ weightKg: Double?) -> String {
        guard let weightKg else { return "BW" }
        let unit = viewModel.preferredWeightUnit
        let converted = unit.fromKilograms(weightKg)
        let formatted = converted == Double(Int(converted))
            ? "\(Int(converted))"
            : String(format: "%.1f", converted)
        return "\(formatted) \(unit.rawValue)"
    }

    /// Formats a stored kg weight as a clean number string for pre-filling an input field.
    private func formatWeightForInput(_ weightKg: Double) -> String {
        let unit = viewModel.preferredWeightUnit
        let converted = unit.fromKilograms(weightKg)
        return converted == Double(Int(converted))
            ? "\(Int(converted))"
            : String(format: "%.1f", converted)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - DetailAddSetSheet

private struct DetailAddSetSheet: View {

    let weightUnit: WeightUnit
    let onAdd: (Int, Double?) -> Void

    @State private var reps:   String
    @State private var weight: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field { case reps, weight }

    init(weightUnit: WeightUnit,
         initialReps: String,
         initialWeight: String,
         onAdd: @escaping (Int, Double?) -> Void) {
        self.weightUnit = weightUnit
        self.onAdd      = onAdd
        _reps   = State(initialValue: initialReps)
        _weight = State(initialValue: initialWeight)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                field("Reps", text: $reps, keyboard: .numberPad, focus: .reps)
                field("Weight (\(weightUnit.displayName), optional)", text: $weight, keyboard: .decimalPad, focus: .weight)
                Spacer()
                Button {
                    guard let r = Int(reps), r > 0 else { return }
                    let kg = Double(weight).map { weightUnit.toKilograms($0) }
                    onAdd(r, kg)
                    dismiss()
                } label: {
                    Text("Add Set").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled((Int(reps) ?? 0) <= 0)
            }
            .padding(20)
            .navigationTitle("Add Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = .reps }
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($focused, equals: focus)
        }
    }
}

// MARK: - DetailEditSetSheet

private struct DetailEditSetSheet: View {

    let weightUnit: WeightUnit
    let onSave: (Int, Double?) -> Void

    @State private var reps:   String
    @State private var weight: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field { case reps, weight }

    init(weightUnit: WeightUnit,
         initialReps: String,
         initialWeight: String,
         onSave: @escaping (Int, Double?) -> Void) {
        self.weightUnit = weightUnit
        self.onSave     = onSave
        _reps   = State(initialValue: initialReps)
        _weight = State(initialValue: initialWeight)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                field("Reps", text: $reps, keyboard: .numberPad, focus: .reps)
                field("Weight (\(weightUnit.displayName), optional)", text: $weight, keyboard: .decimalPad, focus: .weight)
                Spacer()
                Button {
                    guard let r = Int(reps), r > 0 else { return }
                    let kg = Double(weight).map { weightUnit.toKilograms($0) }
                    onSave(r, kg)
                    dismiss()
                } label: {
                    Text("Save").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled((Int(reps) ?? 0) <= 0)
            }
            .padding(20)
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = .reps }
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(.title3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.fill.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($focused, equals: focus)
        }
    }
}
