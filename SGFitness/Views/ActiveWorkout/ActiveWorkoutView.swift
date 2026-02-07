import SwiftUI

// MARK: - ActiveWorkoutView
// Target folder: Views/ActiveWorkout/
//
// The main screen during a live workout. Displays the session header
// (name + elapsed time), a scrollable list of exercises with their sets,
// and a rest timer overlay when active. Toolbar provides finish/discard actions.
//
// Binds to: ActiveWorkoutViewModel

struct ActiveWorkoutView: View {

    // @Bindable enables two-way bindings to @Observable properties
    // (e.g. currentExerciseIndex). The parent view owns the VM via @State.
    @Bindable var viewModel: ActiveWorkoutViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Workout Header
                // Binds to: viewModel.session?.name, viewModel.elapsedTime
                workoutHeader

                Divider()

                // MARK: - Exercise List
                // Binds to: viewModel.exercises (sorted by order)
                if viewModel.exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Add an exercise to get started.")
                    )
                } else {
                    exerciseList
                }
            }
            // MARK: - Rest Timer Overlay
            // Binds to: viewModel.restTimerIsRunning, viewModel.restTimerRemaining
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
                        // TODO: Present ExercisePickerView sheet
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
        }
    }

    // MARK: - Subviews

    private var workoutHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Binds to: viewModel.session?.name
                Text(viewModel.session?.name ?? "Workout")
                    .font(.headline)

                // Binds to: viewModel.exercises.count
                Text("\(viewModel.exercises.count) exercises")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Binds to: viewModel.elapsedTime
            // Formatted as mm:ss
            Text(formatElapsedTime(viewModel.elapsedTime))
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var exerciseList: some View {
        // Binds to: viewModel.exercises
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
