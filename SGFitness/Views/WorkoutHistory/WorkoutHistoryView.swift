import SwiftUI
import SwiftData

// MARK: - WorkoutHistoryView
// Target folder: Views/WorkoutHistory/
//
// Displays a chronological list of past completed workouts.
// Supports search filtering and swipe-to-delete.
// Tapping a row navigates to WorkoutDetailView.
//
// Binds to: WorkoutHistoryViewModel

struct WorkoutHistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: WorkoutHistoryViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredSessions.isEmpty {
                    // MARK: - Empty State
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            // Binds to: viewModel.searchText
            .searchable(text: $viewModel.searchText, prompt: "Search workouts")
            .onAppear {
                viewModel.fetchSessions()
            }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        // Binds to: viewModel.filteredSessions
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
            // Binds to: session.name
            Text(session.name)
                .font(.headline)

            HStack(spacing: 12) {
                // Binds to: session.startedAt
                Text(session.startedAt, style: .date)

                // Binds to: session.exercises.count
                Text("\(session.exercises.count) exercises")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
