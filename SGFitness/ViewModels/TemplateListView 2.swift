import SwiftUI
import SwiftData

struct TemplateListViewModel {
    let modelContext: ModelContext
    let user: User
}

struct TemplateListView: View {
    let viewModel: TemplateListViewModel
    @Query private var templates: [WorkoutTemplate]

    init(viewModel: TemplateListViewModel) {
        self.viewModel = viewModel
        // Configure @Query to fetch WorkoutTemplate sorted by updatedAt desc
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        _templates = Query(descriptor)
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Templates",
                    systemImage: "list.clipboard",
                    description: Text("Tap + to add a template.")
                )
            } else {
                List(templates, id: \.id) { template in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                        Text("\(template.exercises.count) exercises")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addTemplate) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addTemplate() {
        let template = WorkoutTemplate(name: "New Template", user: viewModel.user)
        viewModel.modelContext.insert(template)
        try? viewModel.modelContext.save()
    }
}

#Preview {
    let container = try! ModelContainer(for: [
        User.self, Badge.self, BadgeAward.self,
        ExerciseDefinition.self,
        WorkoutTemplate.self, ExerciseTemplate.self, SetGoal.self,
        WorkoutSession.self, ExerciseSession.self, PerformedSet.self,
    ], inMemory: true)

    let context = container.mainContext
    let user = User(name: "Athlete")
    context.insert(user)
    return NavigationStack {
        TemplateListView(viewModel: TemplateListViewModel(modelContext: context, user: user))
    }
    .modelContainer(container)
}
