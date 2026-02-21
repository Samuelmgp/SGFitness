import SwiftUI

// MARK: - OnboardingView
// Full welcome sheet presented on first launch.
// Collects user name and weight unit preference.

struct OnboardingView: View {

    let user: User
    let onComplete: () -> Void

    @State private var userName: String = ""
    @State private var weightUnit: WeightUnit = .lbs

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: - Branding
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Welcome to SGFitness")
                .font(.largeTitle.bold())

            Text("Track your workouts, build your strength.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // MARK: - Input Fields
            VStack(spacing: 16) {
                TextField("Your Name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Picker("Weight Unit", selection: $weightUnit) {
                    Text("kg").tag(WeightUnit.kg)
                    Text("lbs").tag(WeightUnit.lbs)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 40)

            // MARK: - Guidance
            VStack(spacing: 8) {
                Label("Start by creating a workout template", systemImage: "list.clipboard")
                Label("Then use it to track your workouts", systemImage: "figure.run")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()

            // MARK: - Get Started
            Button {
                let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                user.name = name.isEmpty ? "Athlete" : name
                user.preferredWeightUnit = weightUnit
                onComplete()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .onAppear {
            userName = user.name == "Athlete" ? "" : user.name
            weightUnit = user.preferredWeightUnit
        }
        .interactiveDismissDisabled()
    }
}
