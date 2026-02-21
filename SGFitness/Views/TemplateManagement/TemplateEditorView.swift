import SwiftUI
import SwiftData

struct TemplateEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: TemplateEditorViewModel
    let weightUnit: WeightUnit
    @State private var exercisePickerViewModel: ExercisePickerViewModel?

    // Pending exercise definition selected from picker — triggers navigation to config.
    @State private var pendingExerciseDefinition: ExerciseDefinition?
    @State private var showingExerciseConfig = false

    // Add set goal alert state
    @State private var showingAddSetSheet = false
    @State private var addSetTargetExercise: ExerciseTemplate?
    @State private var addSetReps: String = "10"
    @State private var addSetWeight: String = ""

    // Edit set goal alert state
    @State private var showingEditSetSheet = false
    @State private var editingSetGoal: SetGoal?
    @State private var editSetReps: String = ""
    @State private var editSetWeight: String = ""

    // Rest time configuration alert
    @State private var showingRestTimeSheet = false
    @State private var restTimeExercise: ExerciseTemplate?
    @State private var restTimeValue: String = "60"

    // Add stretch goal alert
    @State private var showingAddStretchGoal = false
    @State private var newStretchGoalName: String = ""
    @State private var newStretchGoalDuration: String = ""

    var body: some View {
        Form {
            Section("Template Info") {
                TextField("Name", text: $viewModel.name)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)

                Picker("Target Duration", selection: $viewModel.targetDurationMinutes) {
                    Text("None").tag(nil as Int?)
                    Text("15 min").tag(15 as Int?)
                    Text("30 min").tag(30 as Int?)
                    Text("45 min").tag(45 as Int?)
                    Text("60 min").tag(60 as Int?)
                    Text("75 min").tag(75 as Int?)
                    Text("90 min").tag(90 as Int?)
                    Text("120 min").tag(120 as Int?)
                }
            }

            Section("Exercises") {
                if viewModel.exercises.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "dumbbell")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No exercises yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.exercises, id: \.id) { exercise in
                        NavigationLink(value: exercise) {
                            exerciseRow(exercise)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            viewModel.removeExercise(at: index)
                        }
                    }
                    .onMove { source, destination in
                        if let sourceIndex = source.first {
                            viewModel.reorderExercise(from: sourceIndex, to: destination)
                        }
                    }
                }

                Button {
                    let vm = ExercisePickerViewModel(modelContext: modelContext)
                    vm.fetchDefinitions()
                    exercisePickerViewModel = vm
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }

            Section("Stretches") {
                if viewModel.stretches.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "figure.flexibility")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No stretches yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.stretches, id: \.id) { stretch in
                        stretchGoalRow(stretch)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            viewModel.removeStretchGoal(at: index)
                        }
                    }
                    .onMove { source, destination in
                        if let sourceIndex = source.first {
                            viewModel.reorderStretchGoal(from: sourceIndex, to: destination)
                        }
                    }
                }

                Button {
                    newStretchGoalName = ""
                    newStretchGoalDuration = ""
                    showingAddStretchGoal = true
                } label: {
                    Label("Add Stretch", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ExerciseTemplate.self) { exercise in
            ExerciseDetailView(exercise: exercise, viewModel: viewModel, weightUnit: weightUnit)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    viewModel.save()
                }
                .disabled(!viewModel.hasUnsavedChanges)
            }

            ToolbarItem(placement: .secondaryAction) {
                EditButton()
            }
        }
        .sheet(item: $exercisePickerViewModel, onDismiss: {
            if pendingExerciseDefinition != nil {
                showingExerciseConfig = true
            }
        }) { picker in
            ExercisePickerView(viewModel: picker, onSelect: { exercise in
                pendingExerciseDefinition = exercise
                exercisePickerViewModel = nil
            })
        }
        .navigationDestination(isPresented: $showingExerciseConfig) {
            if let definition = pendingExerciseDefinition {
                ExerciseConfigView(definition: definition, weightUnit: weightUnit) { sets, reps, weight, restSeconds in
                    viewModel.addExercise(from: definition, targetSets: sets, targetReps: reps, targetWeight: weight, restSeconds: restSeconds)
                    pendingExerciseDefinition = nil
                }
            }
        }
        // Add set goal alert
        .alert("Add Set Goal", isPresented: $showingAddSetSheet) {
            TextField("Target Reps", text: $addSetReps)
                .keyboardType(.numberPad)
            TextField("Weight in \(weightUnit.rawValue) (optional)", text: $addSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                guard let exercise = addSetTargetExercise,
                      let reps = Int(addSetReps), reps > 0 else { return }
                let weight = Double(addSetWeight).map { weightUnit.toKilograms($0) }
                viewModel.addSetGoal(to: exercise, reps: reps, weight: weight)
            }
        } message: {
            Text("Enter target reps and weight (\(weightUnit.rawValue)) for this set.")
        }
        // Edit set goal alert
        .alert("Edit Set Goal", isPresented: $showingEditSetSheet) {
            TextField("Target Reps", text: $editSetReps)
                .keyboardType(.numberPad)
            TextField("Weight in \(weightUnit.rawValue) (optional)", text: $editSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                guard let goal = editingSetGoal,
                      let reps = Int(editSetReps), reps > 0 else { return }
                goal.targetReps = reps
                goal.targetWeight = Double(editSetWeight).map { weightUnit.toKilograms($0) }
                try? modelContext.save()
            }
        } message: {
            Text("Modify the target reps and weight (\(weightUnit.rawValue)).")
        }
        // Rest time configuration alert
        .alert("Rest Time", isPresented: $showingRestTimeSheet) {
            TextField("Seconds", text: $restTimeValue)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("No Rest") {
                restTimeExercise?.restSeconds = nil
                try? modelContext.save()
            }
            Button("Save") {
                guard let exercise = restTimeExercise,
                      let seconds = Int(restTimeValue), seconds > 0 else { return }
                exercise.restSeconds = seconds
                try? modelContext.save()
            }
        } message: {
            Text("Set rest time between sets (in seconds).")
        }
        // Add stretch goal alert
        .alert("Add Stretch", isPresented: $showingAddStretchGoal) {
            TextField("Stretch name", text: $newStretchGoalName)
            TextField("Target duration (seconds, optional)", text: $newStretchGoalDuration)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                let trimmed = newStretchGoalName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                viewModel.addStretchGoal(
                    name: trimmed,
                    targetDurationSeconds: Int(newStretchGoalDuration)
                )
            }
        } message: {
            Text("Enter stretch name and optional hold duration.")
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: ExerciseTemplate) -> some View {
        let muscleGroup = exercise.exerciseDefinition?.muscleGroup
        let iconSymbol  = muscleGroup?.sfSymbol ?? exercise.exerciseDefinition?.exerciseType.sfSymbol ?? "dumbbell"
        let iconColor   = muscleGroup?.color ?? Color.secondary

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconSymbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                Text(exercise.name)
                    .font(.headline)

                Spacer()

                if let equipment = exercise.exerciseDefinition?.equipment {
                    Text(equipment)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }
            }

            // Summary line
            let goalCount = exercise.setGoals.count
            let restText = exercise.restSeconds.map { "\($0)s rest" } ?? "No rest"
            Text("\(goalCount) sets \u{2022} \(restText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Stretch Goal Row

    private func stretchGoalRow(_ stretch: StretchGoal) -> some View {
        HStack {
            Image(systemName: "figure.flexibility")
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(stretch.name)
                    .font(.subheadline)
                if let dur = stretch.targetDurationSeconds {
                    Text("Hold \(dur)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

}
