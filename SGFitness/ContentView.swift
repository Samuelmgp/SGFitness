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

    // Onboarding sheet shown on first launch.
    @State private var showingOnboarding = false

    // Selected tab for programmatic navigation.
    @State private var selectedTab = 0

    // Stable ViewModel references — created once in bootstrapUser().
    @State private var templateListVM: TemplateListViewModel?
    @State private var workoutHistoryVM: WorkoutHistoryViewModel?

    var body: some View {
        Group {
            if let user {
                mainTabView(user: user)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if user == nil {
                bootstrapUser()
            }
        }
    }

    // MARK: - Main Tab View

    private func mainTabView(user: User) -> some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Home
            HomeView(
                user: user,
                onStartFromTemplate: { template in
                    startFromTemplate(template, user: user)
                },
                onStartAdHoc: {
                    startAdHoc(user: user)
                },
                onLogWorkout: {
                    logWorkout(user: user)
                }
            )
            .tag(0)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            // Tab 1: Templates
            if let templateListVM {
                TemplateListView(viewModel: templateListVM)
                    .tag(1)
                    .tabItem {
                        Label("Templates", systemImage: "list.clipboard")
                    }
            }

            // Tab 2: History
            if let workoutHistoryVM {
                WorkoutHistoryView(viewModel: workoutHistoryVM)
                    .tag(2)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
            }

            // Tab 3: Profile
            ProfileView(user: user, onDeleteAccount: deleteAccount)
                .tag(3)
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        // Active workout is presented as a full-screen cover.
        .fullScreenCover(item: $activeWorkoutVM) { vm in
            ActiveWorkoutView(viewModel: vm)
        }
        // Onboarding sheet on first launch.
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(user: user) {
                showingOnboarding = false
                try? modelContext.save()
            }
        }
    }

    // MARK: - Workout Lifecycle

    private func startFromTemplate(_ template: WorkoutTemplate, user: User) {
        let vm = ActiveWorkoutViewModel(modelContext: modelContext, user: user)
        vm.startFromTemplate(template)
        activeWorkoutVM = vm
    }

    private func startAdHoc(user: User) {
        let vm = ActiveWorkoutViewModel(modelContext: modelContext, user: user)
        vm.startAdHoc(name: "Quick Workout")
        activeWorkoutVM = vm
    }

    private func logWorkout(user: User) {
        let vm = ActiveWorkoutViewModel(modelContext: modelContext, user: user)
        vm.startManualEntry(name: "Workout Log")
        activeWorkoutVM = vm
    }


    // MARK: - Delete Account

    private func deleteAccount() {
        // Delete all ExerciseDefinitions (not cascade-deleted by User)
        let defDescriptor = FetchDescriptor<ExerciseDefinition>()
        if let allDefs = try? modelContext.fetch(defDescriptor) {
            for def in allDefs {
                modelContext.delete(def)
            }
        }

        // Delete the user (cascade-deletes templates, sessions, badge awards, scheduled workouts)
        if let currentUser = user {
            modelContext.delete(currentUser)
        }

        try? modelContext.save()

        // Reset state and re-bootstrap fresh
        user = nil
        templateListVM = nil
        workoutHistoryVM = nil
        activeWorkoutVM = nil

        // Re-bootstrap immediately — creates new user, seeds data, shows onboarding
        bootstrapUser()
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
                initViewModels(user: existing)
            } else {
                let newUser = User(name: "Athlete")
                modelContext.insert(newUser)
                seedExerciseCatalog()
                seedExampleTemplates(owner: newUser)
                try modelContext.save()
                user = newUser
                initViewModels(user: newUser)
                showingOnboarding = true
            }
        } catch {
            print("[ContentView] Failed to bootstrap user: \(error)")
            let fallback = User(name: "Athlete")
            modelContext.insert(fallback)
            user = fallback
            initViewModels(user: fallback)
        }
    }

    private func initViewModels(user: User) {
        templateListVM = TemplateListViewModel(modelContext: modelContext, user: user)
        workoutHistoryVM = WorkoutHistoryViewModel(modelContext: modelContext)
    }

    // MARK: - Data Seeding

    private func seedExerciseCatalog() {
        let exercises: [(String, MuscleGroup, String)] = [
            // Chest
            ("Push-ups", .chest, "Bodyweight"),
            ("Bench Press", .chest, "Barbell"),
            ("Dumbbell Flyes", .chest, "Dumbbell"),
            ("Incline Bench Press", .chest, "Barbell"),
            ("Cable Crossovers", .chest, "Cable"),
            // Back
            ("Pull-ups", .back, "Bodyweight"),
            ("Barbell Rows", .back, "Barbell"),
            ("Lat Pulldown", .back, "Cable"),
            ("Seated Cable Row", .back, "Cable"),
            ("Deadlift", .back, "Barbell"),
            // Legs
            ("Squats", .legs, "Barbell"),
            ("Lunges", .legs, "Bodyweight"),
            ("Leg Press", .legs, "Machine"),
            ("Romanian Deadlift", .legs, "Barbell"),
            ("Calf Raises", .legs, "Machine"),
            // Shoulders
            ("Overhead Press", .shoulders, "Barbell"),
            ("Lateral Raises", .shoulders, "Dumbbell"),
            ("Face Pulls", .shoulders, "Cable"),
            ("Arnold Press", .shoulders, "Dumbbell"),
            // Arms
            ("Bicep Curls", .arms, "Dumbbell"),
            ("Tricep Pushdowns", .arms, "Cable"),
            ("Hammer Curls", .arms, "Dumbbell"),
            ("Skull Crushers", .arms, "Barbell"),
            // Core
            ("Plank", .core, "Bodyweight"),
            ("Crunches", .core, "Bodyweight"),
            ("Hanging Leg Raises", .core, "Bodyweight"),
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

#Preview {
    ContentView()
        .modelContainer(for: [
            User.self, Badge.self, BadgeAward.self,
            ExerciseDefinition.self,
            WorkoutTemplate.self, ExerciseTemplate.self, SetGoal.self, StretchGoal.self,
            WorkoutSession.self, ExerciseSession.self, PerformedSet.self, StretchEntry.self,
            WorkoutExercise.self, ExerciseSet.self,
            ScheduledWorkout.self,
        ], inMemory: true)
}
