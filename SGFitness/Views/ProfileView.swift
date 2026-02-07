import SwiftUI
import SwiftData

// MARK: - ProfileView
// User profile and settings screen (4th tab).
// Displays user info, preferences, and workout stats.

struct ProfileView: View {

    @Environment(\.modelContext) private var modelContext
    let user: User

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
            }
            .navigationTitle("Profile")
        }
    }
}
