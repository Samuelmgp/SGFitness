import SwiftUI
import SwiftData

struct NewTemplateView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let user: User
    let onCreated: (WorkoutTemplate) -> Void

    @State private var name = ""
    @State private var notes = ""
    @State private var targetDurationMinutes: Int? = nil

    var body: some View {
        Form {
            Section("Template Info") {
                TextField("Template Name", text: $name)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)

                Picker("Target Duration", selection: $targetDurationMinutes) {
                    Text("None").tag(nil as Int?)
                    Text("15 min").tag(15 as Int?)
                    Text("30 min").tag(30 as Int?)
                    Text("45 min").tag(45 as Int?)
                    Text("60 min").tag(60 as Int?)
                    Text("75 min").tag(75 as Int?)
                    Text("90 min").tag(90 as Int?)
                    Text("120 min").tag(120 as Int?)
                }
            }
        }
        .navigationTitle("New Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let template = WorkoutTemplate(name: trimmed, notes: notes, targetDurationMinutes: targetDurationMinutes, owner: user)
                    modelContext.insert(template)
                    try? modelContext.save()
                    onCreated(template)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
