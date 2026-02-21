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
    @State private var showingAddStretch = false
    @State private var newStretchName: String = ""
    @State private var newStretchDuration: String = ""
    /// Index of the exercise currently swiped left to reveal its delete button.
    @State private var swipedExerciseIndex: Int? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Timer Header
                timerHeader

                Divider()

                // MARK: - Stretch section (always visible) + Exercise cards
                exerciseCardList
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
                        if exercisePickerViewModel == nil {
                            exercisePickerViewModel = ExercisePickerViewModel(modelContext: modelContext)
                        }
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
            .alert("Add Stretch", isPresented: $showingAddStretch) {
                TextField("Stretch name", text: $newStretchName)
                TextField("Duration (seconds, optional)", text: $newStretchDuration)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let trimmed = newStretchName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    viewModel.addStretch(name: trimmed, durationSeconds: Int(newStretchDuration))
                }
            } message: {
                Text("Enter stretch name and optional hold duration.")
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

                // Stretch section — always at the top, visible from the moment
                // a workout starts (even before any exercises are added).
                stretchSection

                // Exercise cards, or an inline empty state when none exist yet.
                if viewModel.exercises.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dumbbell")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No exercises yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Tap + to add an exercise.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseCardWithSwipeDelete(exercise: exercise, index: index)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Exercise Card + Swipe-to-Delete

    /// Wraps an ExerciseCardView in a ZStack that reveals a red Delete button
    /// when the user swipes left. Swiping right (or tapping another card's swipe)
    /// dismisses the delete button. Only one card can be in the swiped state at a time.
    private func exerciseCardWithSwipeDelete(exercise: ExerciseSession, index: Int) -> some View {
        let isSwiped = swipedExerciseIndex == index

        return ZStack(alignment: .trailing) {
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
            .offset(x: isSwiped ? -80 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipedExerciseIndex)

            // Delete button — hidden until swiped left.
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.removeExercise(at: index)
                    swipedExerciseIndex = nil
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.title3)
                    Text("Remove")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white)
                .frame(width: 76)
                .frame(maxHeight: .infinity)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .opacity(isSwiped ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: swipedExerciseIndex)
        }
        // Clip so the card edge doesn't overflow when sliding left.
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if value.translation.width < -50 {
                            // Swipe left — reveal delete. Automatically closes any other open card.
                            swipedExerciseIndex = index
                        } else if value.translation.width > 20, isSwiped {
                            // Swipe right on the same card — hide delete button.
                            swipedExerciseIndex = nil
                        }
                    }
                }
        )
    }

    // MARK: - Stretch Section

    private var stretchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Stretches", systemImage: "figure.flexibility")
                    .font(.headline)
                Spacer()
                Button {
                    newStretchName = ""
                    newStretchDuration = ""
                    showingAddStretch = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            if viewModel.stretches.isEmpty {
                Text("No stretches added")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(viewModel.stretches.enumerated()), id: \.element.id) { index, stretch in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stretch.name)
                                    .font(.subheadline.bold())
                                if let dur = stretch.durationSeconds {
                                    Text("\(dur)s hold")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeStretch(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)

                        if index < viewModel.stretches.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
