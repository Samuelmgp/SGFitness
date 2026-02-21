import SwiftUI

// MARK: - OnboardingView
// Full welcome sheet presented on first launch.
// Collects name, weight unit preference, height, and body weight.
// Height is stored in metres; body weight in kg. Both are converted
// for display based on the user's chosen weight unit.

struct OnboardingView: View {

    let user: User
    let onComplete: () -> Void

    @State private var userName: String = ""
    @State private var weightUnit: WeightUnit = .lbs

    // Height — metric path (cm)
    @State private var heightCm: Int = 170
    // Height — imperial path (ft + in)
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 9

    // Body weight as a typed string in the selected unit
    @State private var bodyWeightText: String = ""

    // Workout goals
    @State private var goalFrequencyDays: Int = 3
    @State private var goalDurationMinutes: Int? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

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

                // MARK: - Name & Unit
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

                // MARK: - Height
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundStyle(.tint)
                        Text("Height")
                            .font(.headline)
                        Text("(optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if weightUnit == .kg {
                        // Metric: single cm wheel
                        HStack(spacing: 0) {
                            Picker("Height (cm)", selection: $heightCm) {
                                ForEach(100...250, id: \.self) { cm in
                                    Text("\(cm)").tag(cm)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Text("cm")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 40)
                        }
                        .frame(height: 120)
                    } else {
                        // Imperial: ft + in wheels side by side
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Picker("Feet", selection: $heightFeet) {
                                    ForEach(4...7, id: \.self) { Text("\($0)").tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                Text("ft")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 2) {
                                Picker("Inches", selection: $heightInches) {
                                    ForEach(0...11, id: \.self) { Text("\($0)\"").tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                Text("in")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 130)
                    }
                }
                .padding(.horizontal, 40)

                // MARK: - Body Weight
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundStyle(.tint)
                        Text("Body Weight")
                            .font(.headline)
                        Text("(optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        TextField(weightUnit == .kg ? "e.g. 70" : "e.g. 155",
                                  text: $bodyWeightText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)

                        Text(weightUnit.rawValue)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }
                .padding(.horizontal, 40)

                // MARK: - Workout Goals
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.tint)
                        Text("Workout Goals")
                            .font(.headline)
                        Text("(optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Frequency: days per week
                    VStack(spacing: 4) {
                        Text("Frequency")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            Picker("Days per week", selection: $goalFrequencyDays) {
                                ForEach(1...7, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Text("days/week")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 80)
                        }
                        .frame(height: 100)
                    }

                    // Duration goal
                    VStack(spacing: 4) {
                        Text("Session Duration")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Session Duration", selection: $goalDurationMinutes) {
                            Text("Not set").tag(nil as Int?)
                            Text("20 min").tag(20 as Int?)
                            Text("30 min").tag(30 as Int?)
                            Text("45 min").tag(45 as Int?)
                            Text("60 min").tag(60 as Int?)
                            Text("75 min").tag(75 as Int?)
                            Text("90 min").tag(90 as Int?)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 40)

                // MARK: - Guidance
                VStack(spacing: 8) {
                    Label("Start by creating a workout template", systemImage: "list.clipboard")
                    Label("Then use it to track your workouts", systemImage: "figure.run")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                // MARK: - Get Started
                Button {
                    saveAndComplete()
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
        }
        .onAppear {
            userName = user.name == "Athlete" ? "" : user.name
            weightUnit = user.preferredWeightUnit
            loadExistingMeasurements()
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Helpers

    private func saveAndComplete() {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.name = name.isEmpty ? "Athlete" : name
        user.preferredWeightUnit = weightUnit

        // Height → metres
        if weightUnit == .kg {
            user.heightMeters = Double(heightCm) / 100.0
        } else {
            let totalInches = heightFeet * 12 + heightInches
            user.heightMeters = Double(totalInches) * 0.0254
        }

        // Body weight → kg
        if let value = Double(bodyWeightText), value > 0 {
            user.bodyWeightKg = weightUnit.toKilograms(value)
        }

        // Workout goals
        user.targetWorkoutDaysPerWeek = goalFrequencyDays
        user.targetWorkoutMinutes = goalDurationMinutes

        onComplete()
    }

    private func loadExistingMeasurements() {
        if let h = user.heightMeters {
            if user.preferredWeightUnit == .kg {
                heightCm = Int(h * 100)
            } else {
                let totalInches = Int(h / 0.0254)
                heightFeet = max(4, min(7, totalInches / 12))
                heightInches = totalInches % 12
            }
        }
        if let w = user.bodyWeightKg {
            let display = user.preferredWeightUnit.fromKilograms(w)
            bodyWeightText = display.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(display))"
                : String(format: "%.1f", display)
        }
    }
}
