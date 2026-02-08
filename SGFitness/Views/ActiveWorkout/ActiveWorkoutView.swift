import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ActiveWorkoutViewModel
    @State private var showingExercisePicker = false
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Timer Header
                timerHeader

                Divider()

                // MARK: - Exercise Cards
                if viewModel.exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Tap + to add an exercise.")
                    )
                } else {
                    exerciseCardList
                }
            }
            .overlay {
                if viewModel.restTimerIsRunning {
                    RestTimerView(
                        remaining: viewModel.restTimerRemaining,
                        onSkip: { viewModel.skipRestTimer() }
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button("Finish Workout", systemImage: "checkmark.circle") {
                            viewModel.finishWorkout()
                            dismiss()
                        }
                        Button("Discard Workout", systemImage: "trash", role: .destructive) {
                            viewModel.discardWorkout()
                            dismiss()
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

    // MARK: - Timer Header

    private var timerHeader: some View {
        VStack(spacing: 4) {
            Text(formatElapsedTime(viewModel.elapsedTime))
                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            Text(viewModel.session?.name ?? "Workout")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Exercise Card List

    private var exerciseCardList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseCardView(
                        exercise: exercise,
                        exerciseIndex: index,
                        onCompleteSet: { set, reps, weight in
                            viewModel.completeSet(set, reps: reps, weight: weight)
                        },
                        onLogSet: { reps, weight in
                            viewModel.logSet(exerciseIndex: index, reps: reps, weight: weight)
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
