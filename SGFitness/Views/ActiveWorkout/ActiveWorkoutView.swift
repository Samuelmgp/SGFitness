import SwiftUI
import SwiftData

// MARK: - ActiveWorkoutView
// The main screen during a live workout. Displays the session header
// (name + elapsed time), a scrollable list of exercises with their sets,
// and a rest timer overlay when active.

struct ActiveWorkoutView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ActiveWorkoutViewModel
    @State private var showingExercisePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Workout Header
                workoutHeader

                Divider()

                // MARK: - Exercise List
                if viewModel.exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Tap + to add an exercise.")
                    )
                } else {
                    exerciseList
                }
            }
            // MARK: - Rest Timer Overlay
            .overlay {
                if viewModel.restTimerIsRunning {
                    RestTimerView(
                        remaining: viewModel.restTimerRemaining,
                        onSkip: { viewModel.skipRestTimer() }
                    )
                }
            }
            .navigationTitle(viewModel.session?.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // MARK: - Toolbar: Add Exercise
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                // MARK: - Toolbar: Finish / Discard
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button("Finish Workout", systemImage: "checkmark.circle") {
                            viewModel.finishWorkout()
                        }
                        Button("Discard Workout", systemImage: "trash", role: .destructive) {
                            viewModel.discardWorkout()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                let picker = ExercisePickerViewModel(modelContext: modelContext)
                ExercisePickerView(viewModel: picker, onSelect: { definition in
                    viewModel.addExercise(from: definition)
                    showingExercisePicker = false
                })
            }
        }
    }

    // MARK: - Subviews

    private var workoutHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.session?.name ?? "Workout")
                    .font(.headline)

                Text("\(viewModel.exercises.count) exercises")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatElapsedTime(viewModel.elapsedTime))
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var exerciseList: some View {
        List {
            ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseRowView(
                    exercise: exercise,
                    exerciseIndex: index,
                    isCurrent: index == viewModel.currentExerciseIndex,
                    onLogSet: { reps, weight in
                        viewModel.logSet(exerciseIndex: index, reps: reps, weight: weight)
                    },
                    onCompleteSet: { set, reps, weight in
                        viewModel.completeSet(set, reps: reps, weight: weight)
                    },
                    onSetEffort: { effort in
                        viewModel.setEffort(exerciseIndex: index, effort: effort)
                    }
                )
                .onTapGesture {
                    viewModel.currentExerciseIndex = index
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    viewModel.removeExercise(at: index)
                }
            }
            .onMove { source, destination in
                if let sourceIndex = source.first {
                    viewModel.reorderExercise(from: sourceIndex, to: destination)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: User.self, configurations: configuration)
        let context = container.mainContext

        let mockUser = User(
            id: UUID(),
            name: "tester",
            createdAt: Date(),
            preferredWeightUnit: .kg
        )

        context.insert(mockUser)

        let viewModel = ActiveWorkoutViewModel(modelContext: context, user: mockUser)

        return ActiveWorkoutView(viewModel: viewModel)
            .previewDisplayName("Active Workout (Preview)")
    }
}
