import SwiftUI

struct ExerciseConfigView: View {

    let definition: ExerciseDefinition
    let weightUnit: WeightUnit
    let onAdd: (_ sets: Int, _ reps: Int, _ weight: Double?, _ restSeconds: Int?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var weightText: String = ""
    @State private var restSeconds: Int = 60

    var body: some View {
        Form {
            Section("Exercise") {
                LabeledContent("Name", value: definition.name)
                if let group = definition.muscleGroup {
                    LabeledContent("Muscle Group", value: group.rawValue)
                }
                if let equipment = definition.equipment {
                    LabeledContent("Equipment", value: equipment)
                }
            }

            Section("Configuration") {
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                Stepper("Reps per Set: \(reps)", value: $reps, in: 1...100)
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Optional", text: $weightText)
                        .keyboardType(.decimalPad)
                        .keyboardShortcut(.defaultAction)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text(weightUnit.rawValue)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }
                Stepper("Rest: \(restSeconds)s", value: $restSeconds, in: 0...300, step: 15)
            }
        }
        .navigationTitle("Configure Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add to Template") {
                    let weight = Double(weightText).map { weightUnit.toKilograms($0) }
                    let rest = restSeconds > 0 ? restSeconds : nil
                    onAdd(sets, reps, weight, rest)
                    dismiss()
                }
            }
        }
    }
}
