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
        }
        // Active workout is presented as a full-screen cover.
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            if let activeWorkoutVM {
                ActiveWorkoutView(viewModel: activeWorkoutVM)
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

                Text("Ready to train?")
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
                        Label("Start from Template", systemImage: "list.clipboard")
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
    // Ensures a User exists in the store. On first launch, creates one.
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
                try modelContext.save()
                user = newUser
            }
        } catch {
            print("[ContentView] Failed to bootstrap user: \(error)")
            // Create in-memory fallback so the app doesn't hang on the spinner.
            let fallback = User(name: "Athlete")
            modelContext.insert(fallback)
            user = fallback
        }
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
