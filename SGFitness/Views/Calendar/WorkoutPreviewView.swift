import SwiftUI
import SwiftData

// MARK: - WorkoutPreviewView
// Day-detail sheet opened when the user taps a day in CalendarView.
// Shows all sessions logged on that day with exercise breakdown
// and PR medal indicators.

struct WorkoutPreviewView: View {

    let day: Date
    let dayData: CalendarDayData

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var dateTitle: String {
        day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(dayData.sessions, id: \.id) { session in
                    sessionSection(session)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Session Section

    @ViewBuilder
    private func sessionSection(_ session: WorkoutSession) -> some View {
        Section {
            // Summary row
            HStack(spacing: 12) {
                // Status dot
                Circle()
                    .fill(statusColor(session.workoutStatus))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name).font(.headline)
                    if let dur = session.durationMinutes {
                        Text("\(dur) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // PR medal if any
                if session.hasPRs, let medal = bestMedal(for: session) {
                    Image(systemName: medal.sfSymbol)
                        .foregroundStyle(medalColor(medal))
                        .font(.title3)
                }
            }
            .padding(.vertical, 2)

            // Exercise rows
            ForEach(session.exercises.sorted { $0.order < $1.order }, id: \.id) { exercise in
                exerciseRow(exercise)
            }
        }
    }

    // MARK: - Exercise Row

    private func exerciseRow(_ exercise: ExerciseSession) -> some View {
        HStack(spacing: 8) {
            // Muscle group colour indicator
            if let mg = exercise.exerciseDefinition?.muscleGroup {
                RoundedRectangle(cornerRadius: 2)
                    .fill(muscleGroupColor(mg))
                    .frame(width: 4, height: 36)
            } else if exercise.exerciseDefinition?.exerciseType == .cardio {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.cyan)
                    .frame(width: 4, height: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.subheadline)

                let completedSets = exercise.performedSets
                    .filter(\.isCompleted)
                    .sorted { $0.order < $1.order }

                if !completedSets.isEmpty {
                    Text(setsSummary(completedSets, isCardio: exercise.exerciseDefinition?.exerciseType == .cardio))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Per-exercise PR indicator
            if let definition = exercise.exerciseDefinition {
                let sessionPRs = definition.personalRecords.filter {
                    $0.workoutSession?.id == exercise.workoutSession?.id
                }
                if let best = sessionPRs.min(by: { $0.medal.rank < $1.medal.rank }) {
                    Image(systemName: best.medal.sfSymbol)
                        .font(.caption)
                        .foregroundStyle(medalColor(best.medal))
                }
            }
        }
    }

    // MARK: - Helpers

    private func bestMedal(for session: WorkoutSession) -> PRMedal? {
        var best: PRMedal? = nil
        for exercise in session.exercises {
            guard let def = exercise.exerciseDefinition else { continue }
            for pr in def.personalRecords where pr.workoutSession?.id == session.id {
                if best == nil || pr.medal.rank < best!.rank { best = pr.medal }
            }
        }
        return best
    }

    private func setsSummary(_ sets: [PerformedSet], isCardio: Bool) -> String {
        if isCardio {
            return sets.map { set -> String in
                let dist = "\(set.reps)m"
                return set.durationSeconds.map { "\(dist) in \(formatDuration($0))" } ?? dist
            }.joined(separator: "  •  ")
        } else {
            let grouped = Dictionary(grouping: sets) { set -> String in
                set.weight.map { "\(formatWeight($0))kg" } ?? "BW"
            }
            return grouped.map { weight, s in "\(s.count)×\(weight)" }
                .sorted()
                .joined(separator: "  •  ")
        }
    }

    private func statusColor(_ status: WorkoutStatus?) -> Color {
        switch status {
        case .exceeded:  return .purple
        case .targetMet: return .green
        case .partial:   return .yellow
        case .none:      return Color(.systemGray4)
        }
    }

    private func medalColor(_ medal: PRMedal) -> Color {
        switch medal {
        case .gold:   return .yellow
        case .silver: return Color(.systemGray)
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(format: "%.1f", weight)
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
