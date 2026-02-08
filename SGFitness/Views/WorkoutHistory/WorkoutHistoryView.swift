import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: WorkoutHistoryViewModel

    @State private var yearGridVM: YearGridViewModel?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Year contribution grid
                if let yearGridVM {
                    YearGridView(viewModel: yearGridVM)
                }

                Divider()

                // Session list
                Group {
                    if viewModel.filteredSessions.isEmpty && !viewModel.searchText.isEmpty {
                        ContentUnavailableView.search(text: viewModel.searchText)
                    } else if viewModel.filteredSessions.isEmpty {
                        ContentUnavailableView(
                            "No Workouts Yet",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Complete a workout to see it here.")
                        )
                    } else {
                        sessionList
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $viewModel.searchText, prompt: "Search workouts")
            .onAppear {
                if yearGridVM == nil {
                    yearGridVM = YearGridViewModel(modelContext: modelContext)
                }
                viewModel.fetchSessions()
            }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(viewModel.filteredSessions, id: \.id) { session in
                NavigationLink(value: session) {
                    sessionRow(session)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let session = viewModel.filteredSessions[index]
                    viewModel.deleteSession(session)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: WorkoutSession.self) { session in
            let detailVM = WorkoutDetailViewModel(modelContext: modelContext, session: session)
            WorkoutDetailView(viewModel: detailVM)
        }
    }

    // MARK: - Row

    private func sessionRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.headline)

            HStack(spacing: 12) {
                Text(session.startedAt, style: .date)
                Text("\(session.exercises.count) exercises")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
