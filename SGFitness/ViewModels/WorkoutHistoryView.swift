import SwiftUI
import SwiftData

// MARK: - WorkoutHistoryViewModel (Placeholder)
final class WorkoutHistoryViewModel: ObservableObject {
    private let modelContext: ModelContext

    @Published var sessions: [WorkoutSession] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadHistory()
    }

    private func loadHistory() {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        self.sessions = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - WorkoutHistoryView (Placeholder)
struct WorkoutHistoryView: View {
    @ObservedObject var viewModel: WorkoutHistoryViewModel

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    description: Text("Your completed workouts will appear here.")
                )
            } else {
                List(viewModel.sessions, id: \.id) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.name).font(.headline)
                        if let start = session.startDate {
                            Text(start, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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
    let context = try! ModelContainer(for: [
        User.self, Badge.self, BadgeAward.self,
        ExerciseDefinition.self,
        WorkoutTemplate.self, ExerciseTemplate.self, SetGoal.self,
        WorkoutSession.self, ExerciseSession.self, PerformedSet.self,
    ], configurations: .init(isStoredInMemoryOnly: true)).mainContext

    let vm = WorkoutHistoryViewModel(modelContext: context)
    return NavigationStack { WorkoutHistoryView(viewModel: vm) }
}
