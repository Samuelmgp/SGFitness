import SwiftUI
import SwiftData

// MARK: - ExerciseDetailView
// Shows exercise metadata, personal records, and recent history.
// Accessible from ExerciseLibraryView (replaces direct-to-editor navigation).

struct ExerciseDefinitionDetailView: View {

    let definition: ExerciseDefinition
    let viewModel: ExercisePickerViewModel

    @Environment(\.modelContext) private var modelContext
    @State private var showingEditSheet = false
    @State private var prs: ExercisePRs?

    var body: some View {
        List {
            // MARK: - Header Chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let muscleGroup = definition.muscleGroup {
                            ExerciseChip(text: muscleGroup, systemImage: "figure.strengthtraining.traditional")
                        }
                        if let equipment = definition.equipment {
                            ExerciseChip(text: equipment, systemImage: "dumbbell")
                        }
                        ExerciseChip(
                            text: definition.exerciseType == "cardio" ? "Cardio" : "Strength",
                            systemImage: definition.exerciseType == "cardio" ? "figure.run" : "bolt.fill"
                        )
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: - Personal Bests
            Section("Personal Bests") {
                if let prs {
                    if definition.exerciseType == "cardio" {
                        if prs.cardioRecords.isEmpty {
                            Text("No records yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(prs.cardioRecords.keys.sorted(), id: \.self) { distance in
                                if let record = prs.cardioRecords[distance] {
                                    HStack {
                                        Text(formatDistance(distance))
                                            .font(.body)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(formatDuration(record.bestTimeSeconds))
                                                .font(.body.bold())
                                            Text(record.date, style: .date)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        if prs.maxWeightKg == nil && prs.bestVolumeKg == nil {
                            Text("No records yet")
                                .foregroundStyle(.secondary)
                        }
                        if let maxWeight = prs.maxWeightKg, let reps = prs.maxWeightReps, let date = prs.maxWeightDate {
                            HStack {
                                Label("Max Weight", systemImage: "trophy")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(formatWeight(maxWeight)) kg × \(reps) reps")
                                        .font(.body.bold())
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let volume = prs.bestVolumeKg, let date = prs.bestVolumeDate {
                            HStack {
                                Label("Best Volume", systemImage: "chart.bar.fill")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(formatWeight(volume)) kg")
                                        .font(.body.bold())
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }

            // MARK: - Recent History
            Section("Recent History") {
                let recentSessions = definition.exerciseSessions
                    .filter { $0.workoutSession?.completedAt != nil }
                    .sorted { ($0.workoutSession?.completedAt ?? .distantPast) > ($1.workoutSession?.completedAt ?? .distantPast) }
                    .prefix(5)

                if recentSessions.isEmpty {
                    Text("No workout history yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recentSessions), id: \.id) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.workoutSession?.name ?? "Workout")
                                    .font(.subheadline.bold())
                                Spacer()
                                if let date = session.workoutSession?.completedAt {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(setsSummary(for: session))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ExerciseEditorView(viewModel: viewModel, mode: .edit(definition)) {
                    viewModel.fetchDefinitions()
                    loadPRs()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditSheet = false }
                    }
                }
            }
        }
        .onAppear { loadPRs() }
    }

    // MARK: - Helpers

    private func loadPRs() {
        let prsVM = PRsViewModel(modelContext: modelContext)
        prs = prsVM.computePRs(for: definition)
    }

    private func setsSummary(for session: ExerciseSession) -> String {
        let completed = session.performedSets
            .filter(\.isCompleted)
            .sorted { $0.order < $1.order }
        if completed.isEmpty { return "No sets logged" }

        if definition.exerciseType == "cardio" {
            let parts = completed.map { set -> String in
                let dist = "\(set.reps)m"
                if let dur = set.durationSeconds {
                    return "\(dist) in \(formatDuration(dur))"
                }
                return dist
            }
            return parts.joined(separator: ", ")
        } else {
            let parts = completed.map { set -> String in
                if let weight = set.weight {
                    return "\(set.reps) × \(formatWeight(weight))kg"
                }
                return "\(set.reps) reps"
            }
            return parts.joined(separator: ", ")
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    private func formatDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            let km = Double(meters) / 1000.0
            if km.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(km))km"
            }
            return String(format: "%.1fkm", km)
        }
        return "\(meters)m"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - ExerciseChip

struct ExerciseChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.fill.tertiary)
            .clipShape(Capsule())
    }
}
