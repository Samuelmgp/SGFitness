import SwiftUI
import SwiftData

// MARK: - ActiveWorkoutViewModel (Shim)
final class ActiveWorkoutViewModel: ObservableObject {
    private let modelContext: ModelContext
    private let user: User

    @Published var title: String = "Workout"

    init(modelContext: ModelContext, user: User) {
        self.modelContext = modelContext
        self.user = user
    }

    func startFromTemplate(_ template: WorkoutTemplate) {
        title = template.name
        // Real impl would create a session from template
    }

    func startAdHoc(name: String) {
        title = name
        // Real impl would create a new ad-hoc session
    }
}

// MARK: - ActiveWorkoutView (Placeholder)
struct ActiveWorkoutView: View {
    @ObservedObject var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text(viewModel.title)
                    .font(.largeTitle.bold())
                Text("This is a placeholder active workout screen.")
                    .foregroundStyle(.secondary)

                Button("End Workout") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 24)
            }
            .padding()
            .navigationTitle("Active Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
    let vm = ActiveWorkoutViewModel(modelContext: context, user: user)
    vm.startAdHoc(name: "Leg Day")

    return ActiveWorkoutView(viewModel: vm)
        .modelContainer(for: [
            User.self, Badge.self, BadgeAward.self,
            ExerciseDefinition.self,
            WorkoutTemplate.self, ExerciseTemplate.self, SetGoal.self,
            WorkoutSession.self, ExerciseSession.self, PerformedSet.self,
        ], inMemory: true)
}
