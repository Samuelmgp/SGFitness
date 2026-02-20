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

    var body: some View {
        List {
            // MARK: - Header Chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let muscleGroup = definition.muscleGroup {
                            ExerciseChip(text: muscleGroup.rawValue, systemImage: "figure.strengthtraining.traditional")
                        }
                        if let equipment = definition.equipment {
                            ExerciseChip(text: equipment, systemImage: "dumbbell")
                        }
                        ExerciseChip(
                            text: definition.exerciseType.displayName,
                            systemImage: definition.exerciseType.sfSymbol
                        )
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: - Personal Bests (Podium)
            Section("Personal Bests") {
                if definition.exerciseType == .cardio {
                    cardioPodium
                } else {
                    strengthPodium
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
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditSheet = false }
                    }
                }
            }
        }
    }

    // MARK: - Podium Views

    private var strengthPodium: some View {
        let maxWeightRecords = definition.personalRecords
            .filter { $0.recordTypeRaw == PRRecordType.maxWeight.rawValue }
            .sorted { $0.medal.rank < $1.medal.rank }

        let bestVolumeRecords = definition.personalRecords
            .filter { $0.recordTypeRaw == PRRecordType.bestVolume.rawValue }
            .sorted { $0.medal.rank < $1.medal.rank }

        return Group {
            if maxWeightRecords.isEmpty && bestVolumeRecords.isEmpty {
                Text("No records yet")
                    .foregroundStyle(.secondary)
            }

            if !maxWeightRecords.isEmpty {
                ForEach(maxWeightRecords, id: \.id) { record in
                    let valueText = record.valueKg.map { kg in
                        let repsStr = record.reps.map { " × \($0) reps" } ?? ""
                        return "\(formatWeight(kg)) kg\(repsStr)"
                    } ?? ""
                    podiumRow(record: record, label: "Max Weight", valueText: valueText)
                }
            }

            if !bestVolumeRecords.isEmpty {
                ForEach(bestVolumeRecords, id: \.id) { record in
                    let valueText = record.valueKg.map { "\(formatWeight($0)) kg" } ?? ""
                    podiumRow(record: record, label: "Best Volume", valueText: valueText)
                }
            }
        }
    }

    private var cardioPodium: some View {
        let goldRecords = definition.personalRecords
            .filter { $0.recordTypeRaw == PRRecordType.cardioTime.rawValue && $0.medalRaw == PRMedal.gold.rawValue }
            .sorted { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }

        return Group {
            if goldRecords.isEmpty {
                Text("No records yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goldRecords, id: \.id) { record in
                    let distLabel = record.distanceMeters.map { formatDistance($0) } ?? ""
                    let timeText = record.durationSeconds.map { formatDuration($0) } ?? ""
                    podiumRow(record: record, label: distLabel, valueText: timeText)
                }
            }
        }
    }

    private func podiumRow(record: PersonalRecord, label: String, valueText: String) -> some View {
        HStack {
            Image(systemName: record.medal.sfSymbol)
                .foregroundStyle(medalColor(record.medal))
            Text(label)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(valueText).font(.body.bold())
                Text(record.achievedAt, style: .date).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func medalColor(_ medal: PRMedal) -> Color {
        switch medal {
        case .gold:   return .yellow
        case .silver: return Color(.systemGray)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }

    // MARK: - Helpers

    private func setsSummary(for session: ExerciseSession) -> String {
        let completed = session.performedSets
            .filter(\.isCompleted)
            .sorted { $0.order < $1.order }
        if completed.isEmpty { return "No sets logged" }

        if definition.exerciseType == .cardio {
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
