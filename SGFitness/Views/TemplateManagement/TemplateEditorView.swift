import SwiftUI
import SwiftData

// MARK: - TemplateEditorView
// Full editor for a single workout template. Provides fields for name
// and notes, a reorderable exercise list with set goals, and buttons
// to add/remove exercises and set goals.

struct TemplateEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: TemplateEditorViewModel
    @State private var showingExercisePicker = false

    // Add set goal sheet state
    @State private var showingAddSetSheet = false
    @State private var addSetTargetExercise: ExerciseTemplate?
    @State private var addSetReps: String = "10"
    @State private var addSetWeight: String = ""

    // Edit set goal sheet state
    @State private var showingEditSetSheet = false
    @State private var editingSetGoal: SetGoal?
    @State private var editSetReps: String = ""
    @State private var editSetWeight: String = ""

    // Rest time configuration
    @State private var showingRestTimeSheet = false
    @State private var restTimeExercise: ExerciseTemplate?
    @State private var restTimeValue: String = "60"

    var body: some View {
        Form {
            // MARK: - Template Info Section
            Section("Template Info") {
                TextField("Name", text: $viewModel.name)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            // MARK: - Exercises Section
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
                        exerciseRow(exercise)
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
        .sheet(isPresented: $showingExercisePicker) {
            let picker = ExercisePickerViewModel(modelContext: modelContext)
            ExercisePickerView(viewModel: picker, onSelect: { exercise in
                viewModel.addExercise(from: exercise, targetSets: 3, targetReps: 10, targetWeight: nil)
                showingExercisePicker = false
            })
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
            // Exercise header with muscle group icon
            HStack {
                Image(systemName: iconForMuscleGroup(exercise.exerciseDefinition?.muscleGroup))
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                Text(exercise.name)
                    .font(.headline)

                Spacer()

                // Equipment badge
                if let equipment = exercise.exerciseDefinition?.equipment {
                    Text(equipment)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(Capsule())
                }
            }

            // Rest time
            Button {
                restTimeExercise = exercise
                restTimeValue = exercise.restSeconds.map { "\($0)" } ?? "60"
                showingRestTimeSheet = true
            } label: {
                if let rest = exercise.restSeconds {
                    Label("Rest: \(rest)s", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Set rest time", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.borderless)

            // Set Goals
            let sortedGoals = exercise.setGoals.sorted { $0.order < $1.order }

            if !sortedGoals.isEmpty {
                HStack {
                    Text("Set")
                        .frame(width: 36, alignment: .leading)
                    Text("Reps")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Weight")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer().frame(width: 30)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(sortedGoals, id: \.id) { goal in
                HStack {
                    Text("\(goal.order + 1)")
                        .frame(width: 36, alignment: .leading)

                    Text("\(goal.targetReps) reps")
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(goal.targetWeight.map { "\(Int($0)) kg" } ?? "BW")
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Delete set goal button
                    Button {
                        viewModel.removeSetGoal(goal)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 30)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingSetGoal = goal
                    editSetReps = "\(goal.targetReps)"
                    editSetWeight = goal.targetWeight.map { "\(Int($0))" } ?? ""
                    showingEditSetSheet = true
                }
            }

            // Add Set Goal button
            Button {
                addSetTargetExercise = exercise
                addSetReps = sortedGoals.last.map { "\($0.targetReps)" } ?? "10"
                addSetWeight = sortedGoals.last?.targetWeight.map { "\(Int($0))" } ?? ""
                showingAddSetSheet = true
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
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
