import SwiftUI
import SwiftData

final class ActiveWorkoutViewModel: ObservableObject {
    let modelContext: ModelContext
    let user: User

    @Published var name: String = "Workout"

    init(modelContext: ModelContext, user: User) {
        self.modelContext = modelContext
        self.user = user
    }

    func startFromTemplate(_ template: WorkoutTemplate) {
        name = template.name
        // future: initialize working state from template
    }

    func startAdHoc(name: String) {
        self.name = name
        // future: initialize new empty workout
    }
}

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ActiveWorkoutViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text(viewModel.name)
                    .font(.title.bold())
                Text("Active workout in progress…")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
    return ActiveWorkoutView(viewModel: ActiveWorkoutViewModel(modelContext: context, user: user))
        .modelContainer(container)
}
