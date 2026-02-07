import SwiftUI
import SwiftData

struct WorkoutHistoryViewModel {
    let modelContext: ModelContext
}

struct WorkoutHistoryView: View {
    let viewModel: WorkoutHistoryViewModel
    @Query private var sessions: [WorkoutSession]

    init(viewModel: WorkoutHistoryViewModel) {
        self.viewModel = viewModel
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _sessions = Query(descriptor)
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Your completed workouts will appear here.")
                )
            } else {
                List(sessions, id: \.id) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.name)
                            .font(.headline)
                        Text(session.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
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
    return NavigationStack {
        WorkoutHistoryView(viewModel: WorkoutHistoryViewModel(modelContext: context))
    }
    .modelContainer(container)
}
