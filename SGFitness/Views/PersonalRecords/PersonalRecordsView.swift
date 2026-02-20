import SwiftUI
import SwiftData

// MARK: - PersonalRecordsView
// Lists all-time personal records grouped by muscle group.
// Accessible from Profile → Stats section.

struct PersonalRecordsView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var prResults: [(ExerciseDefinition, ExercisePRs)] = []
    @State private var pickerViewModel: ExercisePickerViewModel?


    var body: some View {
        Group {
            if prResults.filter({ hasPR($0.1) }).isEmpty {
                ContentUnavailableView(
                    "No Records Yet",
                    systemImage: "trophy",
                    description: Text("Complete your first workout to see records.")
                )
            } else {
                recordsList
            }
        }
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadPRs() }
    }

    // MARK: - Records List

    private var recordsList: some View {
        List {
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                let groupPRs = prResults.filter { $0.0.muscleGroup == group && hasPR($0.1) }
                if !groupPRs.isEmpty {
                    Section(group.rawValue) {
                        ForEach(groupPRs, id: \.0.id) { definition, prs in
                            if let vm = pickerViewModel {
                                NavigationLink {
                                    ExerciseDefinitionDetailView(definition: definition, viewModel: vm)
                                } label: {
                                    prRow(definition: definition, prs: prs)
                                }
                            }
                        }
                    }
                }
            }

            // Uncategorized / other
            let otherPRs = prResults.filter { $0.0.muscleGroup == nil && hasPR($0.1) }
            if !otherPRs.isEmpty {
                Section("Other") {
                    ForEach(otherPRs, id: \.0.id) { definition, prs in
                        if let vm = pickerViewModel {
                            NavigationLink {
                                ExerciseDefinitionDetailView(definition: definition, viewModel: vm)
                            } label: {
                                prRow(definition: definition, prs: prs)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Row

    private func prRow(definition: ExerciseDefinition, prs: ExercisePRs) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name)
                    .font(.body)
                Text(topMetric(definition: definition, prs: prs))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
        }
    }

    // MARK: - Helpers

    private func hasPR(_ prs: ExercisePRs) -> Bool {
        prs.maxWeightKg != nil || prs.bestVolumeKg != nil || !prs.cardioRecords.isEmpty
    }

    private func topMetric(definition: ExerciseDefinition, prs: ExercisePRs) -> String {
        if definition.exerciseType == .cardio {
            if let (distance, record) = prs.cardioRecords.min(by: { $0.value.bestTimeSeconds < $1.value.bestTimeSeconds }) {
                return "\(formatDistance(distance)): \(formatDuration(record.bestTimeSeconds))"
            }
            return "No records"
        } else {
            if let weight = prs.maxWeightKg, let reps = prs.maxWeightReps {
                return "Max: \(formatWeight(weight))kg × \(reps)"
            }
            return "No records"
        }
    }

    private func loadPRs() {
        let vm = ExercisePickerViewModel(modelContext: modelContext)
        vm.fetchDefinitions()
        pickerViewModel = vm

        let prsVM = PRsViewModel(modelContext: modelContext)
        prResults = prsVM.computeAllPRs()
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
