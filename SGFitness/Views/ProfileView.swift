import SwiftUI
import SwiftData

// MARK: - ProfileView
// User profile and settings screen (4th tab).
// Displays user info, preferences, and workout stats.

struct ProfileView: View {

    @Environment(\.modelContext) private var modelContext
    let user: User
    var onDeleteAccount: (() -> Void)?

    @State private var showingDeleteConfirmation = false
    @State private var showingMeasurementsEdit = false
    @State private var showingGoalsEdit = false

    // Measurements edit state
    @State private var editHeightCm: Int = 170
    @State private var editHeightFeet: Int = 5
    @State private var editHeightInches: Int = 9
    @State private var editBodyWeightText: String = ""

    // Goals edit state
    @State private var editGoalFrequencyDays: Int = 3
    @State private var editGoalDurationMinutes: Int? = nil

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - User Info
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(.title2.bold())
                            Text("Member since \(user.createdAt, format: .dateTime.month(.wide).year())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Settings
                Section("Settings") {
                    HStack {
                        Label("Name", systemImage: "pencil")
                        Spacer()
                        TextField("Name", text: Binding(
                            get: { user.name },
                            set: { newValue in
                                user.name = newValue
                                try? modelContext.save()
                            }
                        ))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                    }

                    Picker(selection: Binding(
                        get: { user.preferredWeightUnit },
                        set: { newValue in
                            user.preferredWeightUnit = newValue
                            try? modelContext.save()
                        }
                    )) {
                        Text("kg").tag(WeightUnit.kg)
                        Text("lbs").tag(WeightUnit.lbs)
                    } label: {
                        Label("Weight Unit", systemImage: "scalemass")
                    }
                }

                // MARK: - Goals
                Section("Goals") {
                    HStack {
                        Label("Weekly Target", systemImage: "calendar")
                        Spacer()
                        Text(user.targetWorkoutDaysPerWeek.map { "\($0) days/week" } ?? "Not set")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editGoalFrequencyDays = user.targetWorkoutDaysPerWeek ?? 3
                        editGoalDurationMinutes = user.targetWorkoutMinutes
                        showingGoalsEdit = true
                    }

                    HStack {
                        Label("Session Duration", systemImage: "timer")
                        Spacer()
                        Text(user.targetWorkoutMinutes.map { "\($0) min" } ?? "Not set")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editGoalFrequencyDays = user.targetWorkoutDaysPerWeek ?? 3
                        editGoalDurationMinutes = user.targetWorkoutMinutes
                        showingGoalsEdit = true
                    }
                }

                // MARK: - Stats
                Section("Stats") {
                    HStack {
                        Label("Workouts Completed", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(user.workoutSessions.filter { $0.completedAt != nil }.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Templates Created", systemImage: "list.clipboard")
                        Spacer()
                        Text("\(user.workoutTemplates.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Body Measurements
                Section("Body Measurements") {
                    HStack {
                        Label("Height", systemImage: "ruler")
                        Spacer()
                        Text(heightDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Body Weight", systemImage: "scalemass")
                        Spacer()
                        Text(bodyWeightDisplayText)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        loadMeasurementsForEdit()
                        showingMeasurementsEdit = true
                    } label: {
                        Label("Edit Measurements", systemImage: "pencil")
                    }
                }

                // MARK: - Library & Records
                Section("Library") {
                    NavigationLink {
                        PersonalRecordsView(weightUnit: user.preferredWeightUnit)
                    } label: {
                        Label("Personal Records", systemImage: "trophy")
                    }

                    NavigationLink {
                        ExerciseLibraryView(weightUnit: user.preferredWeightUnit)
                    } label: {
                        Label("Exercise Library", systemImage: "books.vertical")
                    }
                }

                // MARK: - Danger Zone
                if onDeleteAccount != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingMeasurementsEdit) {
                measurementsEditSheet
            }
            .sheet(isPresented: $showingGoalsEdit) {
                goalsEditSheet
            }
            .confirmationDialog(
                "Delete Account",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    onDeleteAccount?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your data including workout history, templates, and exercises. The app will reset to its initial state.")
            }
        }
    }

    // MARK: - Body Measurements Display

    private var heightDisplayText: String {
        guard let h = user.heightMeters else { return "Not set" }
        if user.preferredWeightUnit == .kg {
            return "\(Int(h * 100)) cm"
        } else {
            let totalInches = Int(h / 0.0254)
            let feet = totalInches / 12
            let inches = totalInches % 12
            return "\(feet)'\(inches)\""
        }
    }

    private var bodyWeightDisplayText: String {
        guard let w = user.bodyWeightKg else { return "Not set" }
        let display = user.preferredWeightUnit.fromKilograms(w)
        let formatted = display.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(display))" : String(format: "%.1f", display)
        return "\(formatted) \(user.preferredWeightUnit.rawValue)"
    }

    // MARK: - Measurements Edit Sheet

    @ViewBuilder
    private var measurementsEditSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 8)

                    // Height
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundStyle(.tint)
                            Text("Height")
                                .font(.headline)
                        }

                        if user.preferredWeightUnit == .kg {
                            HStack(spacing: 0) {
                                Picker("Height (cm)", selection: $editHeightCm) {
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
                            HStack(spacing: 0) {
                                VStack(spacing: 2) {
                                    Picker("Feet", selection: $editHeightFeet) {
                                        ForEach(4...7, id: \.self) { Text("\($0)").tag($0) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)
                                    Text("ft")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(spacing: 2) {
                                    Picker("Inches", selection: $editHeightInches) {
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

                    // Body Weight
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "scalemass")
                                .foregroundStyle(.tint)
                            Text("Body Weight")
                                .font(.headline)
                        }

                        HStack(spacing: 8) {
                            TextField(user.preferredWeightUnit == .kg ? "e.g. 70" : "e.g. 155",
                                      text: $editBodyWeightText)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)

                            Text(user.preferredWeightUnit.rawValue)
                                .foregroundStyle(.secondary)
                                .frame(width: 36)
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer(minLength: 8)
                }
            }
            .navigationTitle("Body Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingMeasurementsEdit = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeasurements()
                        showingMeasurementsEdit = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func loadMeasurementsForEdit() {
        if let h = user.heightMeters {
            if user.preferredWeightUnit == .kg {
                editHeightCm = Int(h * 100)
            } else {
                let totalInches = Int(h / 0.0254)
                editHeightFeet = max(4, min(7, totalInches / 12))
                editHeightInches = totalInches % 12
            }
        }
        if let w = user.bodyWeightKg {
            let display = user.preferredWeightUnit.fromKilograms(w)
            editBodyWeightText = display.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(display))" : String(format: "%.1f", display)
        } else {
            editBodyWeightText = ""
        }
    }

    private func saveMeasurements() {
        if user.preferredWeightUnit == .kg {
            user.heightMeters = Double(editHeightCm) / 100.0
        } else {
            let totalInches = editHeightFeet * 12 + editHeightInches
            user.heightMeters = Double(totalInches) * 0.0254
        }
        if let value = Double(editBodyWeightText), value > 0 {
            user.bodyWeightKg = user.preferredWeightUnit.toKilograms(value)
        }
        try? modelContext.save()
    }

    // MARK: - Goals Edit Sheet

    @ViewBuilder
    private var goalsEditSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 8)

                    // Weekly frequency
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.tint)
                            Text("Weekly Target")
                                .font(.headline)
                        }

                        HStack(spacing: 0) {
                            Picker("Days per week", selection: $editGoalFrequencyDays) {
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
                        .frame(height: 120)
                    }
                    .padding(.horizontal, 40)

                    // Session duration
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundStyle(.tint)
                            Text("Session Duration")
                                .font(.headline)
                        }

                        Picker("Session Duration", selection: $editGoalDurationMinutes) {
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
                    .padding(.horizontal, 40)

                    Spacer(minLength: 8)
                }
            }
            .navigationTitle("Workout Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingGoalsEdit = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        user.targetWorkoutDaysPerWeek = editGoalFrequencyDays
                        user.targetWorkoutMinutes = editGoalDurationMinutes
                        try? modelContext.save()
                        showingGoalsEdit = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
