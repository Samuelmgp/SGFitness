import SwiftUI
import SwiftData

// MARK: - ExerciseLibraryView
// Standalone view to browse, create, edit, and delete exercises
// from the ExerciseDefinition catalog. Accessible from ProfileView.

struct ExerciseLibraryView: View {

    var weightUnit: WeightUnit = .kg

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ExercisePickerViewModel?

    @State private var showingCreateSheet = false
    @State private var exerciseToDelete: ExerciseDefinition?
    @State private var showingDeleteConfirmation = false


    var body: some View {
        Group {
            if let viewModel {
                exerciseList(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            if let viewModel {
                NavigationStack {
                    ExerciseEditorView(viewModel: viewModel, mode: .create) {
                        viewModel.fetchDefinitions()
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingCreateSheet = false
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Exercise",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete, let viewModel {
                    viewModel.deleteExercise(exercise)
                }
                exerciseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
        } message: {
            if let exercise = exerciseToDelete {
                let templateCount = exercise.exerciseTemplates.count
                let sessionCount = exercise.exerciseSessions.count
                if templateCount > 0 || sessionCount > 0 {
                    Text("This exercise is used in \(templateCount) template(s) and \(sessionCount) session(s). Deleting it will remove those references.")
                } else {
                    Text("Are you sure you want to delete \"\(exercise.name)\"?")
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = ExercisePickerViewModel(modelContext: modelContext)
                vm.fetchDefinitions()
                viewModel = vm
            }
        }
    }

    // MARK: - Exercise List

    private func exerciseList(viewModel: ExercisePickerViewModel) -> some View {
        let displayedExercises = viewModel.filteredDefinitions

        return List {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                let exercises = displayedExercises.filter { $0.muscleGroup == group }
                if !exercises.isEmpty {
                    Section(group.rawValue) {
                        ForEach(exercises, id: \.id) { definition in
                            NavigationLink {
                                ExerciseDefinitionDetailView(definition: definition, viewModel: viewModel, weightUnit: weightUnit)
                            } label: {
                                exerciseRow(definition)
                            }
                        }
                        .onDelete { offsets in
                            if let first = offsets.first {
                                exerciseToDelete = exercises[first]
                                showingDeleteConfirmation = true
                            }
                        }
                    }
                }
            }

            // Uncategorized exercises (nil muscleGroup)
            let uncategorized = displayedExercises.filter { $0.muscleGroup == nil }
            if !uncategorized.isEmpty {
                Section("Other") {
                    ForEach(uncategorized, id: \.id) { definition in
                        NavigationLink {
                            ExerciseDefinitionDetailView(definition: definition, viewModel: viewModel, weightUnit: weightUnit)
                        } label: {
                            exerciseRow(definition)
                        }
                    }
                    .onDelete { offsets in
                        if let first = offsets.first {
                            exerciseToDelete = uncategorized[first]
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.definitions.isEmpty {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "dumbbell",
                    description: Text("Tap + to add your first exercise.")
                )
            }
        }
        .searchable(text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        ), prompt: "Search exercises")
    }

    // MARK: - Row

    private func exerciseRow(_ definition: ExerciseDefinition) -> some View {
        HStack(spacing: 12) {
            exerciseIcon(definition)

            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.body)

                HStack(spacing: 6) {
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
    }

    @ViewBuilder
    private func exerciseIcon(_ definition: ExerciseDefinition) -> some View {
        if let muscleGroup = definition.muscleGroup {
            MuscleDiagramView(muscleGroup: muscleGroup, side: muscleGroup == .back ? .back : .front, size: 38)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: definition.exerciseType.sfSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
