import SwiftUI

// MARK: - ExerciseEditorView
// Form for creating or editing an ExerciseDefinition.
// Used from ExerciseDetailView (edit) and ExerciseLibraryView (create).

struct ExerciseEditorView: View {

    enum Mode {
        case create
        case edit(ExerciseDefinition)
    }

    let viewModel: ExercisePickerViewModel
    let mode: Mode
    var initialName: String = ""
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedMuscleGroup: MuscleGroup = .chest
    @State private var selectedEquipment: String = "Barbell"
    @State private var selectedExerciseType: ExerciseType = .strength

    private let equipmentTypes = ["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight"]

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        Form {
            Section("Exercise Details") {
                TextField("Exercise Name", text: $name)
                
                if (selectedMuscleGroup == .back){
                    MuscleDiagramView(muscleGroup: selectedMuscleGroup, side: .back, size: 225)
                        .frame(width: .infinity, alignment: .center)
                }else{
                    MuscleDiagramView(muscleGroup: selectedMuscleGroup, side: .front, size: 225)
                        .frame(width: .infinity, alignment: .center)
                }

                Picker("Type", selection: $selectedExerciseType) {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                if selectedExerciseType == .strength {
                    Picker("Muscle Group", selection: $selectedMuscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                }

                if selectedExerciseType == .strength {
                    Picker("Equipment", selection: $selectedEquipment) {
                        ForEach(equipmentTypes, id: \.self) { equipment in
                            Text(equipment).tag(equipment)
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            switch mode {
            case .create:
                if !initialName.isEmpty {
                    name = initialName
                }
            case .edit(let definition):
                name = definition.name
                selectedMuscleGroup = definition.muscleGroup ?? .chest
                selectedEquipment = definition.equipment ?? "Barbell"
                selectedExerciseType = definition.exerciseType
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let isStrength = selectedExerciseType == .strength
        let muscleGroup: MuscleGroup? = isStrength ? selectedMuscleGroup : nil
        let equipment: String? = isStrength ? selectedEquipment : nil

        switch mode {
        case .create:
            _ = viewModel.createCustomExercise(
                name: trimmed,
                muscleGroup: muscleGroup,
                equipment: equipment,
                exerciseType: selectedExerciseType
            )
        case .edit(let definition):
            viewModel.updateExercise(
                definition,
                name: trimmed,
                muscleGroup: muscleGroup,
                equipment: equipment,
                exerciseType: selectedExerciseType
            )
        }

        onSave?()
        dismiss()
    }
}
