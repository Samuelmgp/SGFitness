import SwiftUI

// MARK: - TemplateEditorView
// Target folder: Views/TemplateManagement/
//
// Full editor for a single workout template. Provides fields for name
// and notes, a reorderable exercise list with set goals, and buttons
// to add/remove exercises and set goals. Save button writes buffered
// edits to the model.
//
// Binds to: TemplateEditorViewModel

struct TemplateEditorView: View {

    @Bindable var viewModel: TemplateEditorViewModel

    var body: some View {
        Form {
            // MARK: - Template Info Section
            Section("Template Info") {
                // Binds to: viewModel.name (buffered)
                TextField("Name", text: $viewModel.name)

                // Binds to: viewModel.notes (buffered)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            // MARK: - Exercises Section
            // Binds to: viewModel.exercises (sorted by order)
            Section("Exercises") {
                if viewModel.exercises.isEmpty {
                    Text("No exercises yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
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

                // MARK: - Add Exercise Button
                Button {
                    // TODO: Present ExercisePickerView sheet
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // MARK: - Save Button
            // Binds to: viewModel.hasUnsavedChanges
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
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: ExerciseTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Binds to: exercise.name
            Text(exercise.name)
                .font(.headline)

            // Binds to: exercise.restSeconds
            if let rest = exercise.restSeconds {
                Text("Rest: \(rest)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Set Goals
            // Binds to: exercise.setGoals (sorted by order)
            let sortedGoals = exercise.setGoals.sorted { $0.order < $1.order }
            ForEach(sortedGoals, id: \.id) { goal in
                HStack {
                    Text("Set \(goal.order + 1)")
                        .frame(width: 50, alignment: .leading)

                    // Binds to: goal.targetReps
                    Text("\(goal.targetReps) reps")
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Binds to: goal.targetWeight
                    Text(goal.targetWeight.map { "\(Int($0)) kg" } ?? "BW")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            // Add Set Goal button
            Button {
                // TODO: Present input for target reps/weight
                viewModel.addSetGoal(to: exercise, reps: 10, weight: nil)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
