import SwiftUI

// MARK: - ExercisePickerView
// Presented as a sheet from ActiveWorkoutView or TemplateEditorView.
// Shows a searchable list of exercises from the ExerciseDefinition catalog.
// Supports creating custom exercises via ExerciseEditorView.

struct ExercisePickerView: View {

    @Bindable var viewModel: ExercisePickerViewModel

    /// Callback when the user selects an exercise.
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateSheet = false
    @State private var pendingNewExerciseName = ""

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
                            pendingNewExerciseName = viewModel.searchText
                            showingCreateSheet = true
                        } label: {
                            Label(
                                viewModel.searchText.isEmpty
                                    ? "Create New Exercise"
                                    : "Create \"\(viewModel.searchText)\"",
                                systemImage: "plus.circle"
                            )
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pendingNewExerciseName = ""
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

    // MARK: - Create Sheet
    // Uses ExerciseEditorView so type picker (Strength/Cardio) is available.
    // After saving, the newly created exercise is auto-selected.

    private var createExerciseSheet: some View {
        NavigationStack {
            ExerciseEditorView(
                viewModel: viewModel,
                mode: .create,
                initialName: pendingNewExerciseName
            ) {
                // onSave: pick the most recently created definition
                viewModel.fetchDefinitions()
                if let newest = viewModel.definitions.max(by: { $0.createdAt < $1.createdAt }) {
                    showingCreateSheet = false
                    onSelect(newest)
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCreateSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                        Text(muscleGroup.rawValue)
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
