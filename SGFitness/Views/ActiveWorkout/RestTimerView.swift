import SwiftUI

// MARK: - RestTimerView
// Target folder: Views/ActiveWorkout/
//
// A full-screen overlay that shows the rest timer countdown.
// Displayed on top of ActiveWorkoutView when restTimerIsRunning == true.
// Shows a large countdown, a circular progress indicator, and a skip button.
//
// Binds to: remaining (from viewModel.restTimerRemaining)
// Action: onSkip (calls viewModel.skipRestTimer())

struct RestTimerView: View {

    /// Seconds remaining on the rest timer.
    let remaining: Int

    /// Callback when the user taps "Skip".
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            // MARK: - Dimmed Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {

                Text("Rest")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))

                // MARK: - Countdown Display
                // Binds to: remaining (seconds)
                Text(formatTime(remaining))
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)

                // MARK: - Skip Button
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        // Animate remaining changes for smooth countdown feel
        .animation(.default, value: remaining)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return "\(s)"
    }
}
