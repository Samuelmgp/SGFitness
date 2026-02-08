import SwiftUI
import SwiftData

struct TemplateEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: TemplateEditorViewModel
    @State private var showingExercisePicker = false

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

    var body: some View {
        Form {
            Section("Template Info") {
                TextField("Name", text: $viewModel.name)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
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
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ExerciseTemplate.self) { exercise in
            ExerciseDetailView(exercise: exercise, viewModel: viewModel)
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
        .sheet(isPresented: $showingExercisePicker, onDismiss: {
            if pendingExerciseDefinition != nil {
                showingExerciseConfig = true
            }
        }) {
            let picker = ExercisePickerViewModel(modelContext: modelContext)
            ExercisePickerView(viewModel: picker, onSelect: { exercise in
                pendingExerciseDefinition = exercise
                showingExercisePicker = false
            })
        }
        .navigationDestination(isPresented: $showingExerciseConfig) {
            if let definition = pendingExerciseDefinition {
                ExerciseConfigView(definition: definition) { sets, reps, weight, restSeconds in
                    viewModel.addExercise(from: definition, targetSets: sets, targetReps: reps, targetWeight: weight, restSeconds: restSeconds)
                    pendingExerciseDefinition = nil
                }
            }
        }
        // Add set goal alert
        .alert("Add Set Goal", isPresented: $showingAddSetSheet) {
            TextField("Target Reps", text: $addSetReps)
                .keyboardType(.numberPad)
            TextField("Weight (optional)", text: $addSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                guard let exercise = addSetTargetExercise,
                      let reps = Int(addSetReps), reps > 0 else { return }
                let weight = Double(addSetWeight)
                viewModel.addSetGoal(to: exercise, reps: reps, weight: weight)
            }
        } message: {
            Text("Enter target reps and weight for this set.")
        }
        // Edit set goal alert
        .alert("Edit Set Goal", isPresented: $showingEditSetSheet) {
            TextField("Target Reps", text: $editSetReps)
                .keyboardType(.numberPad)
            TextField("Weight (optional)", text: $editSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                guard let goal = editingSetGoal,
                      let reps = Int(editSetReps), reps > 0 else { return }
                goal.targetReps = reps
                goal.targetWeight = Double(editSetWeight)
                try? modelContext.save()
            }
        } message: {
            Text("Modify the target reps and weight.")
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
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: ExerciseTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForMuscleGroup(exercise.exerciseDefinition?.muscleGroup))
                    .foregroundStyle(.tint)
                    .frame(width: 24)

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

    // MARK: - Helpers

    private func iconForMuscleGroup(_ group: String?) -> String {
        switch group?.lowercased() {
        case "chest": return "figure.arms.open"
        case "back": return "figure.rowing"
        case "legs": return "figure.walk"
        case "shoulders": return "figure.boxing"
        case "arms": return "figure.mixed.cardio"
        case "core": return "figure.core.training"
        default: return "dumbbell"
        }
    }
}
