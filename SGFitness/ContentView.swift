import SwiftUI
import SwiftData

// MARK: - ContentView
//
// The root view of the app. Provides a TabView with three sections:
//   1. Workout — Start a new workout (ad-hoc or from template)
//   2. Templates — Create and manage workout templates
//   3. History — Browse past completed workouts
//
// Also manages the active workout lifecycle: when a workout is started,
// it is presented as a full-screen cover over everything.

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    // The current user — fetched or created on first appear.
    @State private var user: User?

    // Active workout state.
    @State private var activeWorkoutVM: ActiveWorkoutViewModel?
    @State private var showingActiveWorkout = false

    // Ad-hoc workout name entry.
    @State private var showingAdHocAlert = false
    @State private var adHocWorkoutName = ""

    // Template picker for "Start from Template".
    @State private var showingTemplatePicker = false

    // Onboarding sheet shown on first launch.
    @State private var showingOnboarding = false

    // Template count for workout tab hints.
    @State private var templateCount = 0

    var body: some View {
        Group {
            if let user {
                mainTabView(user: user)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            bootstrapUser()
        }
    }

    // MARK: - Main Tab View

    private func mainTabView(user: User) -> some View {
        TabView {
            // Tab 1: Start Workout
            workoutTab(user: user)
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }

            // Tab 2: Templates
            TemplateListView(
                viewModel: TemplateListViewModel(modelContext: modelContext, user: user)
            )
            .tabItem {
                Label("Templates", systemImage: "list.clipboard")
            }

            // Tab 3: History
            WorkoutHistoryView(
                viewModel: WorkoutHistoryViewModel(modelContext: modelContext)
            )
            .tabItem {
                Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            // Tab 4: Profile
            ProfileView(user: user)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        // Active workout is presented as a full-screen cover.
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            if let activeWorkoutVM {
                ActiveWorkoutView(viewModel: activeWorkoutVM)
            }
        }
        // Onboarding sheet on first launch.
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(user: user) {
                showingOnboarding = false
                try? modelContext.save()
            }
        }
    }

    // MARK: - Workout Tab (Start Screen)

    private func workoutTab(user: User) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Ready to train, \(user.name)?")
                    .font(.title2.bold())

                Text("Start a workout from a template or create one on the fly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    // Start from template
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        VStack(spacing: 4) {
                            Label("Start from Template", systemImage: "list.clipboard")
                            if templateCount == 0 {
                                Text("Create a template first in the Templates tab")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    // Quick start (ad-hoc)
                    Button {
                        adHocWorkoutName = ""
                        showingAdHocAlert = true
                    } label: {
                        Label("Quick Start", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .navigationTitle("SGFitness")
            .onAppear {
                let descriptor = FetchDescriptor<WorkoutTemplate>()
                templateCount = (try? modelContext.fetch(descriptor).count) ?? 0
            }
            // Ad-hoc workout name alert
            .alert("Quick Start", isPresented: $showingAdHocAlert) {
                TextField("Workout Name", text: $adHocWorkoutName)
                Button("Cancel", role: .cancel) { }
                Button("Start") {
                    let name = adHocWorkoutName.isEmpty ? "Workout" : adHocWorkoutName
                    startAdHocWorkout(name: name, user: user)
                }
            } message: {
                Text("Give your workout a name.")
            }
            // Template picker sheet
            .sheet(isPresented: $showingTemplatePicker) {
                templatePickerSheet(user: user)
            }
        }
    }

    // MARK: - Template Picker Sheet

    private func templatePickerSheet(user: User) -> some View {
        NavigationStack {
            TemplatePickerList(
                modelContext: modelContext,
                onSelect: { template in
                    showingTemplatePicker = false
                    startFromTemplate(template, user: user)
                }
            )
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingTemplatePicker = false
                    }
                }
            }
        }
    }

    // MARK: - Workout Lifecycle

    private func startFromTemplate(_ template: WorkoutTemplate, user: User) {
        let vm = ActiveWorkoutViewModel(modelContext: modelContext, user: user)
        vm.startFromTemplate(template)
        activeWorkoutVM = vm
        showingActiveWorkout = true
    }

    private func startAdHocWorkout(name: String, user: User) {
        let vm = ActiveWorkoutViewModel(modelContext: modelContext, user: user)
        vm.startAdHoc(name: name)
        activeWorkoutVM = vm
        showingActiveWorkout = true
    }

    // MARK: - User Bootstrap
    //
    // Ensures a User exists in the store. On first launch, creates one
    // and seeds the exercise catalog and example templates.
    // On subsequent launches, fetches the existing user.

    private func bootstrapUser() {
        let descriptor = FetchDescriptor<User>()
        do {
            let users = try modelContext.fetch(descriptor)
            if let existing = users.first {
                user = existing
            } else {
                let newUser = User(name: "Athlete")
                modelContext.insert(newUser)
                seedExerciseCatalog()
                seedExampleTemplates(owner: newUser)
                try modelContext.save()
                user = newUser
                showingOnboarding = true
            }
        } catch {
            print("[ContentView] Failed to bootstrap user: \(error)")
            let fallback = User(name: "Athlete")
            modelContext.insert(fallback)
            user = fallback
        }
    }

    // MARK: - Data Seeding

    private func seedExerciseCatalog() {
        let exercises: [(String, String, String)] = [
            // Chest
            ("Push-ups", "Chest", "Bodyweight"),
            ("Bench Press", "Chest", "Barbell"),
            ("Dumbbell Flyes", "Chest", "Dumbbell"),
            ("Incline Bench Press", "Chest", "Barbell"),
            ("Cable Crossovers", "Chest", "Cable"),
            // Back
            ("Pull-ups", "Back", "Bodyweight"),
            ("Barbell Rows", "Back", "Barbell"),
            ("Lat Pulldown", "Back", "Cable"),
            ("Seated Cable Row", "Back", "Cable"),
            ("Deadlift", "Back", "Barbell"),
            // Legs
            ("Squats", "Legs", "Barbell"),
            ("Lunges", "Legs", "Bodyweight"),
            ("Leg Press", "Legs", "Machine"),
            ("Romanian Deadlift", "Legs", "Barbell"),
            ("Calf Raises", "Legs", "Machine"),
            // Shoulders
            ("Overhead Press", "Shoulders", "Barbell"),
            ("Lateral Raises", "Shoulders", "Dumbbell"),
            ("Face Pulls", "Shoulders", "Cable"),
            ("Arnold Press", "Shoulders", "Dumbbell"),
            // Arms
            ("Bicep Curls", "Arms", "Dumbbell"),
            ("Tricep Pushdowns", "Arms", "Cable"),
            ("Hammer Curls", "Arms", "Dumbbell"),
            ("Skull Crushers", "Arms", "Barbell"),
            // Core
            ("Plank", "Core", "Bodyweight"),
            ("Crunches", "Core", "Bodyweight"),
            ("Hanging Leg Raises", "Core", "Bodyweight"),
        ]

        for (name, muscleGroup, equipment) in exercises {
            let def = ExerciseDefinition(name: name, muscleGroup: muscleGroup, equipment: equipment)
            modelContext.insert(def)
        }
    }

    private func seedExampleTemplates(owner: User) {
        // Helper to find a seeded exercise definition by name.
        func findDef(_ name: String) -> ExerciseDefinition? {
            let descriptor = FetchDescriptor<ExerciseDefinition>(
                predicate: #Predicate { $0.name == name }
            )
            return try? modelContext.fetch(descriptor).first
        }

        // Helper to create a template exercise with set goals.
        func makeExercise(name: String, order: Int, sets: Int, reps: Int, template: WorkoutTemplate) {
            let def = findDef(name)
            let exercise = ExerciseTemplate(name: name, order: order, workoutTemplate: template)
            exercise.exerciseDefinition = def
            modelContext.insert(exercise)

            for i in 0..<sets {
                let goal = SetGoal(order: i, targetReps: reps, exerciseTemplate: exercise)
                modelContext.insert(goal)
            }
        }

        // Chest Day
        let chestDay = WorkoutTemplate(name: "Chest Day", owner: owner)
        modelContext.insert(chestDay)
        makeExercise(name: "Push-ups", order: 0, sets: 3, reps: 15, template: chestDay)
        makeExercise(name: "Bench Press", order: 1, sets: 4, reps: 10, template: chestDay)
        makeExercise(name: "Dumbbell Flyes", order: 2, sets: 3, reps: 12, template: chestDay)
        makeExercise(name: "Incline Bench Press", order: 3, sets: 3, reps: 10, template: chestDay)

        // Leg Day
        let legDay = WorkoutTemplate(name: "Leg Day", owner: owner)
        modelContext.insert(legDay)
        makeExercise(name: "Squats", order: 0, sets: 4, reps: 8, template: legDay)
        makeExercise(name: "Lunges", order: 1, sets: 3, reps: 12, template: legDay)
        makeExercise(name: "Leg Press", order: 2, sets: 3, reps: 10, template: legDay)
        makeExercise(name: "Romanian Deadlift", order: 3, sets: 3, reps: 10, template: legDay)
        makeExercise(name: "Calf Raises", order: 4, sets: 4, reps: 15, template: legDay)

        // Pull Day
        let pullDay = WorkoutTemplate(name: "Pull Day", owner: owner)
        modelContext.insert(pullDay)
        makeExercise(name: "Pull-ups", order: 0, sets: 3, reps: 8, template: pullDay)
        makeExercise(name: "Barbell Rows", order: 1, sets: 4, reps: 10, template: pullDay)
        makeExercise(name: "Lat Pulldown", order: 2, sets: 3, reps: 12, template: pullDay)
        makeExercise(name: "Bicep Curls", order: 3, sets: 3, reps: 12, template: pullDay)
        makeExercise(name: "Hammer Curls", order: 4, sets: 3, reps: 10, template: pullDay)
    }
}

// MARK: - TemplatePickerList
//
// A simple list of templates for the "Start from Template" sheet.
// Separate from TemplateListView because this is a selection context,
// not a management context — no create/delete, just pick.

private struct TemplatePickerList: View {

    let modelContext: ModelContext
    let onSelect: (WorkoutTemplate) -> Void

    @State private var templates: [WorkoutTemplate] = []

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Templates",
                    systemImage: "list.clipboard",
                    description: Text("Create a template first in the Templates tab.")
                )
            } else {
                List(templates, id: \.id) { template in
                    Button {
                        onSelect(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                            Text("\(template.exercises.count) exercises")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            let descriptor = FetchDescriptor<WorkoutTemplate>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            templates = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            User.self, Badge.self, BadgeAward.self,
            ExerciseDefinition.self,
            WorkoutTemplate.self, ExerciseTemplate.self, SetGoal.self,
            WorkoutSession.self, ExerciseSession.self, PerformedSet.self,
        ], inMemory: true)
}
