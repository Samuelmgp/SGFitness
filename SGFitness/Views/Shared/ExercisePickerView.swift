import SwiftUI

// MARK: - ExercisePickerView
// Target folder: Views/Shared/
//
// Presented as a sheet from ActiveWorkoutView or TemplateEditorView.
// Shows a searchable list of exercises from the ExerciseDefinition catalog.
// Displays recently used exercises at the top for quick access.
// Supports creating a custom exercise if no match is found.
//
// Binds to: ExercisePickerViewModel

struct ExercisePickerView: View {

    @Bindable var viewModel: ExercisePickerViewModel

    /// Callback when the user selects an exercise.
    let onSelect: (ExerciseDefinition) -> Void

    /// Dismiss action (provided by the sheet presentation).
    @Environment(\.dismiss) private var dismiss

    /// Controls the custom exercise creation alert.
    @State private var showingCreateAlert = false
    @State private var customExerciseName = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Recently Used Section
                // Binds to: viewModel.recentlyUsed
                if !viewModel.recentlyUsed.isEmpty && viewModel.searchText.isEmpty {
                    Section("Recently Used") {
                        ForEach(viewModel.recentlyUsed, id: \.id) { definition in
                            exerciseRow(definition)
                        }
                    }
                }

                // MARK: - All Exercises Section
                // Binds to: viewModel.filteredDefinitions
                Section(viewModel.searchText.isEmpty ? "All Exercises" : "Results") {
                    if viewModel.filteredDefinitions.isEmpty {
                        // No results — offer to create custom exercise
                        Button {
                            customExerciseName = viewModel.searchText
                            showingCreateAlert = true
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
            // Binds to: viewModel.searchText
            .searchable(text: $viewModel.searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Create Exercise", isPresented: $showingCreateAlert) {
                TextField("Exercise Name", text: $customExerciseName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    guard !customExerciseName.isEmpty else { return }
                    let definition = viewModel.createCustomExercise(name: customExerciseName)
                    onSelect(definition)
                    dismiss()
                }
            } message: {
                Text("This exercise will be added to your catalog.")
            }
            .onAppear {
                viewModel.fetchDefinitions()
            }
        }
    }

    // MARK: - Row

    private func exerciseRow(_ definition: ExerciseDefinition) -> some View {
        Button {
            onSelect(definition)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                // Binds to: definition.name
                Text(definition.name)
                    .font(.body)

                HStack(spacing: 8) {
                    // Binds to: definition.muscleGroup
                    if let muscleGroup = definition.muscleGroup {
                        Text(muscleGroup)
                    }
                    // Binds to: definition.equipment
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
