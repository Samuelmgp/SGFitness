import SwiftUI
import SwiftData

struct NewTemplateView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let user: User
    let onCreated: (WorkoutTemplate) -> Void

    @State private var name = ""
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Template Info") {
                TextField("Template Name", text: $name)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
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
                    let template = WorkoutTemplate(name: trimmed, notes: notes, owner: user)
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
