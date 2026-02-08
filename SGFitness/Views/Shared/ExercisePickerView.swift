import SwiftUI

// MARK: - ExercisePickerView
// Presented as a sheet from ActiveWorkoutView or TemplateEditorView.
// Shows a searchable list of exercises from the ExerciseDefinition catalog.
// Supports creating custom exercises with full details.

struct ExercisePickerView: View {

    @Bindable var viewModel: ExercisePickerViewModel

    /// Callback when the user selects an exercise.
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    // Create exercise state
    @State private var showingCreateSheet = false
    @State private var newExerciseName = ""
    @State private var newExerciseMuscleGroup = "Chest"
    @State private var newExerciseEquipment = "Barbell"

    private let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
    private let equipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight"]

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Recently Used Section
                if !viewModel.recentlyUsed.isEmpty && viewModel.searchText.isEmpty {
                    Section("Recently Used") {
                        ForEach(viewModel.recentlyUsed, id: \.id) { definition in
                            exerciseRow(definition)
                        }
                    }
                }

                // MARK: - All Exercises Section
                Section(viewModel.searchText.isEmpty ? "All Exercises" : "Results") {
                    if viewModel.filteredDefinitions.isEmpty {
                        Button {
                            newExerciseName = viewModel.searchText
                            showingCreateSheet = true
                        } label: {
                            Label("Create \"\(viewModel.searchText)\"", systemImage: "plus.circle")
                        }
                    } else {
                        ForEach(viewModel.filteredDefinitions, id: \.id) { definition in
                            exerciseRow(definition)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newExerciseName = ""
                        newExerciseMuscleGroup = "Chest"
                        newExerciseEquipment = "Barbell"
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                createExerciseSheet
            }
            .onAppear {
                viewModel.fetchDefinitions()
            }
        }
    }

    // MARK: - Create Exercise Sheet

    private var createExerciseSheet: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $newExerciseName)

                    Picker("Muscle Group", selection: $newExerciseMuscleGroup) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }

                    Picker("Equipment", selection: $newExerciseEquipment) {
                        ForEach(equipmentTypes, id: \.self) { equipment in
                            Text(equipment).tag(equipment)
                        }
                    }
                }
            }
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let definition = viewModel.createCustomExercise(
                            name: trimmed,
                            muscleGroup: newExerciseMuscleGroup,
                            equipment: newExerciseEquipment
                        )
                        showingCreateSheet = false
                        onSelect(definition)
                        dismiss()
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Row

    private func exerciseRow(_ definition: ExerciseDefinition) -> some View {
        Button {
            onSelect(definition)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.body)

                HStack(spacing: 8) {
                    if let muscleGroup = definition.muscleGroup {
                        Text(muscleGroup)
                    }
                    if let equipment = definition.equipment {
                        Text(equipment)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }
}
