import SwiftUI

// MARK: - TemplateListView
// Target folder: Views/TemplateManagement/
//
// Lists all workout templates with search, swipe-to-delete, and a button
// to create new templates. Tapping a row navigates to TemplateEditorView.
//
// Binds to: TemplateListViewModel

struct TemplateListView: View {

    @Bindable var viewModel: TemplateListViewModel

    /// Controls the new-template alert.
    @State private var showingNewTemplateAlert = false
    @State private var newTemplateName = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredTemplates.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else if viewModel.templates.isEmpty {
                    // MARK: - Empty State
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "list.clipboard",
                        description: Text("Create a workout template to get started.")
                    )
                } else {
                    templateList
                }
            }
            .navigationTitle("Templates")
            // Binds to: viewModel.searchText
            .searchable(text: $viewModel.searchText, prompt: "Search templates")
            .toolbar {
                // MARK: - Add Template
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newTemplateName = ""
                        showingNewTemplateAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Template", isPresented: $showingNewTemplateAlert) {
                TextField("Template Name", text: $newTemplateName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    guard !newTemplateName.isEmpty else { return }
                    _ = viewModel.createTemplate(name: newTemplateName)
                    viewModel.fetchTemplates()
                }
            } message: {
                Text("Enter a name for the new workout template.")
            }
            .onAppear {
                viewModel.fetchTemplates()
            }
        }
    }

    // MARK: - Template List

    private var templateList: some View {
        // Binds to: viewModel.filteredTemplates
        List {
            ForEach(viewModel.filteredTemplates, id: \.id) { template in
                NavigationLink(value: template) {
                    templateRow(template)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let template = viewModel.filteredTemplates[index]
                    viewModel.deleteTemplate(template)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: WorkoutTemplate.self) { template in
            // TODO: Initialize TemplateEditorViewModel and pass to TemplateEditorView
            Text("Edit: \(template.name)")
        }
    }

    // MARK: - Row

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Binds to: template.name
            Text(template.name)
                .font(.headline)

            HStack(spacing: 12) {
                // Binds to: template.exercises.count
                Text("\(template.exercises.count) exercises")

                // Binds to: template.updatedAt
                Text("Updated \(template.updatedAt, style: .relative) ago")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
