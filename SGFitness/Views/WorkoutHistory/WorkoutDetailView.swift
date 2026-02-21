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

    // Exercise picker (add exercise)
    @State private var showingExercisePicker = false
    @State private var exercisePickerVM: ExercisePickerViewModel?

    // Add set alert
    @State private var showingAddSet = false
    @State private var addSetExercise: ExerciseSession?
    @State private var addSetReps: String = "10"
    @State private var addSetWeight: String = ""

    // Edit set alert
    @State private var showingEditSet = false
    @State private var editingSet: PerformedSet?
    @State private var editSetReps: String = ""
    @State private var editSetWeight: String = ""

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
                        if exercisePickerVM == nil {
                            exercisePickerVM = ExercisePickerViewModel(modelContext: modelContext)
                        }
                        showingExercisePicker = true
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
        .alert("Add Set", isPresented: $showingAddSet) {
            TextField("Reps", text: $addSetReps)
                .keyboardType(.numberPad)
            TextField("Weight (\(viewModel.preferredWeightUnit.rawValue), optional)", text: $addSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                guard let exercise = addSetExercise,
                      let reps = Int(addSetReps), reps > 0 else { return }
                let weightKg = Double(addSetWeight).map { viewModel.preferredWeightUnit.toKilograms($0) }
                viewModel.addSet(to: exercise, reps: reps, weight: weightKg)
            }
        } message: {
            Text("Enter reps and weight for this set.")
        }
        .alert("Edit Set", isPresented: $showingEditSet) {
            TextField("Reps", text: $editSetReps)
                .keyboardType(.numberPad)
            TextField("Weight (\(viewModel.preferredWeightUnit.rawValue), optional)", text: $editSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard let set = editingSet,
                      let reps = Int(editSetReps), reps > 0 else { return }
                let weightKg = Double(editSetWeight).map { viewModel.preferredWeightUnit.toKilograms($0) }
                viewModel.updateSet(set, reps: reps, weight: weightKg)
            }
        } message: {
            Text("Edit reps and weight for this set.")
        }
        .sheet(isPresented: $showingExercisePicker) {
            if let pickerVM = exercisePickerVM {
                ExercisePickerView(viewModel: pickerVM) { definition in
                    viewModel.addExercise(from: definition)
                }
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

                    if viewModel.isEditing {
                        Button(role: .destructive) {
                            viewModel.removeSet(set)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(set.isCompleted ? .green : .red)
                    }
                }
                .font(.subheadline)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard viewModel.isEditing else { return }
                    editingSet = set
                    editSetReps = "\(set.reps)"
                    editSetWeight = set.weight.map { formatWeightForInput($0) } ?? ""
                    showingEditSet = true
                }
            }

            // Add Set button — edit mode only
            if viewModel.isEditing {
                Button {
                    addSetExercise = exercise
                    let lastSet = sortedSets.last
                    addSetReps = lastSet.map { "\($0.reps)" } ?? "10"
                    addSetWeight = lastSet?.weight.map { formatWeightForInput($0) } ?? ""
                    showingAddSet = true
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
