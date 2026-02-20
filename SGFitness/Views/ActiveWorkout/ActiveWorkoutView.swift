import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ActiveWorkoutViewModel
    @State private var showingExercisePicker = false
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false
    @State private var exercisePickerViewModel: ExercisePickerViewModel?
    @State private var showingPRBanner = false
    @State private var prBannerMessage = ""
    @State private var showingManualDuration = false
    @State private var manualDurationInput: String = "45"

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
            .overlay(alignment: .top) {
                if showingPRBanner {
                    prBannerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .onChange(of: viewModel.latestPRAlert) { _, newAlert in
                guard let alert = newAlert else { return }
                prBannerMessage = "\(alert.exerciseName): \(alert.metric)"
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showingPRBanner = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation {
                        showingPRBanner = false
                    }
                    viewModel.clearPRAlert()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        exercisePickerViewModel = ExercisePickerViewModel(modelContext: modelContext)
                        showingExercisePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button("Finish Workout", systemImage: "checkmark.circle") {
                            if viewModel.isManualEntry {
                                showingManualDuration = true
                            } else {
                                viewModel.finishWorkout()
                                dismiss()
                            }
                        }
                        Button("Save as Template", systemImage: "square.and.arrow.down") {
                            viewModel.saveAsTemplate()
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
                if let picker = exercisePickerViewModel {
                    ExercisePickerView(viewModel: picker, onSelect: { definition in
                        viewModel.addExercise(from: definition)
                        showingExercisePicker = false
                    })
                }
            }
            .alert("Workout Duration", isPresented: $showingManualDuration) {
                TextField("Minutes", text: $manualDurationInput)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {}
                Button("Finish") {
                    let minutes = Int(manualDurationInput) ?? 45
                    viewModel.finishWorkout(manualDurationMinutes: minutes)
                    dismiss()
                }
            } message: {
                Text("How long was your workout? (minutes)")
            }
        }
    }

    // MARK: - PR Banner

    private var prBannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
            Text("New PR! \(prBannerMessage)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }

    // MARK: - Timer Header

    private var timerHeader: some View {
        VStack(spacing: 8) {
            if viewModel.isManualEntry {
                // Manual entry mode — no live timer
                Text("--:--")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if let target = viewModel.targetDurationSeconds {
                // Circular timer ring with color-coded progress
                let progress = min(viewModel.elapsedTime / target, 1.0)
                let rawProgress = viewModel.elapsedTime / target

                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(timerColor(for: rawProgress), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    // Time text in center
                    VStack(spacing: 4) {
                        Text(formatElapsedTime(viewModel.elapsedTime))
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)

                        Text("/ \(formatElapsedTime(target))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 180, height: 180)
            } else {
                // No target duration — plain text timer (blue accent)
                Text(formatElapsedTime(viewModel.elapsedTime))
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.blue)
            }

            Text(viewModel.session?.name ?? "Workout")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    /// Color for the timer ring based on how far through the target duration.
    private func timerColor(for progress: Double) -> Color {
        switch progress {
        case ..<0.5: return .green
        case 0.5..<0.75: return .yellow
        case 0.75..<1.0: return .orange
        default: return .red
        }
    }

    // MARK: - Exercise Card List

    private var exerciseCardList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseCardView(
                        exercise: exercise,
                        exerciseIndex: index,
                        weightUnit: viewModel.preferredWeightUnit,
                        onCompleteSet: { set, reps, weight, durationSeconds in
                            viewModel.completeSet(set, reps: reps, weight: weight, durationSeconds: durationSeconds)
                        },
                        onLogSet: { reps, weight, durationSeconds in
                            if let duration = durationSeconds {
                                viewModel.logSet(exerciseIndex: index, distanceMeters: reps, durationSeconds: duration)
                            } else {
                                viewModel.logSet(exerciseIndex: index, reps: reps, weight: weight)
                            }
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
