import SwiftUI
import SwiftData

struct ExerciseDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: ExerciseTemplate
    let viewModel: TemplateEditorViewModel

    @State private var restSeconds: String = ""

    // Add set goal
    @State private var showingAddSet = false
    @State private var addSetReps: String = "10"
    @State private var addSetWeight: String = ""

    // Edit set goal
    @State private var showingEditSet = false
    @State private var editingGoal: SetGoal?
    @State private var editReps: String = ""
    @State private var editWeight: String = ""

    var body: some View {
        Form {
            // MARK: - Exercise Info
            Section("Exercise") {
                LabeledContent("Name", value: exercise.name)
                if let group = exercise.exerciseDefinition?.muscleGroup {
                    LabeledContent("Muscle Group", value: group)
                }
                if let equipment = exercise.exerciseDefinition?.equipment {
                    LabeledContent("Equipment", value: equipment)
                }
            }

            // MARK: - Rest Time
            Section("Rest Time") {
                HStack {
                    Text("Seconds between sets")
                    Spacer()
                    TextField("60", text: $restSeconds)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // MARK: - Set Goals
            Section("Set Goals") {
                let sortedGoals = exercise.setGoals.sorted { $0.order < $1.order }

                if sortedGoals.isEmpty {
                    Text("No sets configured")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("Set")
                            .frame(width: 36, alignment: .leading)
                        Text("Reps")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("Weight")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(sortedGoals, id: \.id) { goal in
                        HStack {
                            Text("\(goal.order + 1)")
                                .frame(width: 36, alignment: .leading)
                            Text("\(goal.targetReps) reps")
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text(goal.targetWeight.map { "\(Int($0)) kg" } ?? "BW")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .font(.subheadline)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingGoal = goal
                            editReps = "\(goal.targetReps)"
                            editWeight = goal.targetWeight.map { "\(Int($0))" } ?? ""
                            showingEditSet = true
                        }
                    }
                    .onDelete { offsets in
                        let sorted = exercise.setGoals.sorted { $0.order < $1.order }
                        for index in offsets {
                            viewModel.removeSetGoal(sorted[index])
                        }
                    }
                }

                Button {
                    let lastGoal = exercise.setGoals.sorted { $0.order < $1.order }.last
                    addSetReps = lastGoal.map { "\($0.targetReps)" } ?? "10"
                    addSetWeight = lastGoal?.targetWeight.map { "\(Int($0))" } ?? ""
                    showingAddSet = true
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                }
            }

            // MARK: - Delete
            Section {
                Button("Remove Exercise", role: .destructive) {
                    if let index = viewModel.exercises.firstIndex(where: { $0.id == exercise.id }) {
                        viewModel.removeExercise(at: index)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            restSeconds = exercise.restSeconds.map { "\($0)" } ?? ""
        }
        .onDisappear {
            // Save rest time changes
            if let seconds = Int(restSeconds), seconds > 0 {
                exercise.restSeconds = seconds
            } else if restSeconds.isEmpty {
                exercise.restSeconds = nil
            }
            try? modelContext.save()
        }
        .alert("Add Set Goal", isPresented: $showingAddSet) {
            TextField("Target Reps", text: $addSetReps)
                .keyboardType(.numberPad)
            TextField("Weight (optional)", text: $addSetWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                guard let reps = Int(addSetReps), reps > 0 else { return }
                let weight = Double(addSetWeight)
                viewModel.addSetGoal(to: exercise, reps: reps, weight: weight)
            }
        } message: {
            Text("Enter target reps and weight for this set.")
        }
        .alert("Edit Set Goal", isPresented: $showingEditSet) {
            TextField("Target Reps", text: $editReps)
                .keyboardType(.numberPad)
            TextField("Weight (optional)", text: $editWeight)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                guard let goal = editingGoal,
                      let reps = Int(editReps), reps > 0 else { return }
                goal.targetReps = reps
                goal.targetWeight = Double(editWeight)
                try? modelContext.save()
            }
        } message: {
            Text("Modify the target reps and weight.")
        }
    }
}
