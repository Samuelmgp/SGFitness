import SwiftUI
import SwiftData

// MARK: - WorkoutDetailView
// Target folder: Views/WorkoutHistory/
//
// Displays a single completed workout session with full drill-down.
// Shows summary stats (duration, total volume, template origin),
// the full exercise list with performed sets, and supports an edit mode
// for correcting past data.
//
// Binds to: WorkoutDetailViewModel

struct WorkoutDetailView: View {

    @Bindable var viewModel: WorkoutDetailViewModel
    @State private var showingSavedAsTemplateAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - Summary Header
                summaryHeader

                Divider()

                // MARK: - Exercise List
                // Binds to: viewModel.exercises (sorted by order)
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    exerciseSection(exercise)
                }

                // MARK: - Stretch List
                if !viewModel.stretches.isEmpty {
                    stretchesSection
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isEditing {
                    // In edit mode — a prominent Done button saves and exits.
                    Button("Done") {
                        viewModel.save()
                        viewModel.toggleEditing()
                    }
                    .fontWeight(.semibold)
                } else {
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            viewModel.toggleEditing()
                        }
                        Button("Save as Template", systemImage: "square.and.arrow.down") {
                            viewModel.saveAsTemplate()
                            showingSavedAsTemplateAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Saved as Template", isPresented: $showingSavedAsTemplateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(viewModel.session.name)\" has been added to your Templates.")
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Binds to: viewModel.templateName
            if let templateName = viewModel.templateName {
                Label(templateName, systemImage: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                // Binds to: viewModel.duration
                statItem(
                    label: "Duration",
                    value: formatDuration(viewModel.duration)
                )

                // Binds to: viewModel.totalVolume
                statItem(
                    label: "Volume",
                    value: formatVolume(viewModel.totalVolume)
                )

                // Binds to: viewModel.exercises.count
                statItem(
                    label: "Exercises",
                    value: "\(viewModel.exercises.count)"
                )
            }

            // Binds to: viewModel.session.notes
            if !viewModel.session.notes.isEmpty {
                Text(viewModel.session.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Exercise Section

    private func exerciseSection(_ exercise: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Binds to: exercise.name
                Text(exercise.name)
                    .font(.headline)

                Spacer()

                // Binds to: exercise.effort
                if let effort = exercise.effort {
                    Text("Effort: \(effort)/10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Binds to: exercise.performedSets (sorted by order)
            let sortedSets = exercise.performedSets.sorted { $0.order < $1.order }
            ForEach(sortedSets, id: \.id) { set in
                HStack {
                    Text("Set \(set.order + 1)")
                        .frame(width: 50, alignment: .leading)

                    // Binds to: set.reps
                    Text("\(set.reps) reps")
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Binds to: set.weight
                    Text(set.weight.map { "\(Int($0)) kg" } ?? "BW")
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Binds to: set.isCompleted
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(set.isCompleted ? .green : .red)
                }
                .font(.subheadline)
            }

            Divider()
        }
    }

    // MARK: - Stretch Section

    private var stretchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Stretches", systemImage: "figure.flexibility")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.stretches.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.stretches, id: \.id) { stretch in
                HStack {
                    Text(stretch.name)
                        .font(.subheadline)
                    Spacer()
                    if let dur = stretch.durationSeconds {
                        Text("\(dur)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
        }
    }

    // MARK: - Helpers

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }
}
