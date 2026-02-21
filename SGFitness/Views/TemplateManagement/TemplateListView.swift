import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var viewModel: TemplateListViewModel

    @State private var showingNewTemplate = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredTemplates.isEmpty && !viewModel.searchText.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else if viewModel.templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
            .navigationTitle("Templates")
            .searchable(text: $viewModel.searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                NavigationStack {
                    NewTemplateView(user: viewModel.user) { template in
                        viewModel.fetchTemplates()
                    }
                }
            }
            .onAppear {
                viewModel.fetchTemplates()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: "list.clipboard")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Start with a Template")
                    .font(.title2.bold())

                Text("Templates define your workout structure. Create one, then use it to track your sets and reps during a workout.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    showingNewTemplate = true
                } label: {
                    Label("Create Your Own", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    // MARK: - Template List

    private var templateList: some View {
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
            let editorVM = TemplateEditorViewModel(modelContext: modelContext, template: template)
            TemplateEditorView(viewModel: editorVM, weightUnit: viewModel.user.preferredWeightUnit)
        }
    }

    // MARK: - Row

    private func templateRow(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(template.exercises.count) exercises", systemImage: "dumbbell")
                Text(template.updatedAt, format: .dateTime.month(.abbreviated).day())
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
