import SwiftUI
import SwiftData

@main
struct SGFitnessApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            User.self,
            Badge.self,
            BadgeAward.self,
            ExerciseDefinition.self,
            WorkoutTemplate.self,
            ExerciseTemplate.self,
            SetGoal.self,
            WorkoutSession.self,
            ExerciseSession.self,
            PerformedSet.self,
            ScheduledWorkout.self,
        ])
    }
}
