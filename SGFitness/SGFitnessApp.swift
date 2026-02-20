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
            StretchGoal.self,
            WorkoutSession.self,
            ExerciseSession.self,
            PerformedSet.self,
            StretchEntry.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            ScheduledWorkout.self,
            PersonalRecord.self,
        ])
    }
}
