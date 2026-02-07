import SwiftUI
import SwiftData

// MARK: - TemplateListViewModel (Placeholder)
final class TemplateListViewModel: ObservableObject {
    private let modelContext: ModelContext
    private let user: User

    @Published var templates: [WorkoutTemplate] = []

    init(modelContext: ModelContext, user: User) {
        self.modelContext = modelContext
        self.user = user
        loadTemplates()
    }

    private func loadTemplates() {
        let descriptor = FetchDescriptor<WorkoutTemplate>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        self.templates = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - TemplateListView (Placeholder)
struct TemplateListView: View {
    @ObservedObject var viewModel: TemplateListViewModel

    var body: some View {
        Group {
            if viewModel.templates.isEmpty {
                ContentUnavailableView(
                    "No Templates",
                    systemImage: "list.clipboard",
                    description: Text("Create a template to get started.")
                )
            } else {
                List(viewModel.templates, id: \.id) { template in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name).font(.headline)
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
    }
}

#Preview {
    let context = try! ModelContainer(for: [
        User.self, Badge.self, BadgeAward.self,
        ExerciseDefinition.self,
        WorkoutTemplate.self, ExerciseTemplate.self, SetGoal.self,
        WorkoutSession.self, ExerciseSession.self, PerformedSet.self,
    ], configurations: .init(isStoredInMemoryOnly: true)).mainContext

    let user = User(name: "Preview User")
    context.insert(user)

    let vm = TemplateListViewModel(modelContext: context, user: user)
    return NavigationStack { TemplateListView(viewModel: vm) }
}
