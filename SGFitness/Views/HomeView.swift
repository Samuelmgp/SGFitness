import SwiftUI
import SwiftData

struct HomeView: View {

    @Environment(\.modelContext) private var modelContext

    let user: User
    let onStartFromTemplate: (WorkoutTemplate) -> Void
    let onStartAdHoc: () -> Void
    let onLogWorkout: (String, Date) -> Void
    let onLogWorkoutFromTemplate: (WorkoutTemplate, String, Date) -> Void

    @State private var showingTemplatePicker = false
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var showingLogSetup = false
    @State private var todayCompletion: Double = 0
    @State private var todaySessions: [WorkoutSession] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 32)

                    // MARK: - Completion Ring
                    completionRing

                    Spacer(minLength: 48)

                    // MARK: - Today Summary
                    todaySummary

                    Spacer(minLength: 40)

                    // MARK: - Actions
                    VStack(spacing: 12) {
                        Button {
                            showingTemplatePicker = true
                        } label: {
                            Label("Record Workout", systemImage: "figure.strengthtraining.traditional")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            onStartAdHoc()
                        } label: {
                            Label("Start from Scratch", systemImage: "plus.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            showingLogSetup = true
                        } label: {
                            Label("Log a Workout", systemImage: "square.and.pencil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("SGFitness")
            .onAppear { fetchTodayData() }
            // MARK: - Log Workout Setup Sheet
            .sheet(isPresented: $showingLogSetup) {
                LogWorkoutSetupSheet(modelContext: modelContext) { name, date, template in
                    showingLogSetup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let tmpl = template {
                            onLogWorkoutFromTemplate(tmpl, name, date)
                        } else {
                            onLogWorkout(name, date)
                        }
                    }
                }
            }
            // MARK: - Template Picker Sheet (Record Workout)
            .sheet(isPresented: $showingTemplatePicker, onDismiss: {
                if let template = pendingTemplate {
                    pendingTemplate = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onStartFromTemplate(template)
                    }
                }
            }) {
                NavigationStack {
                    RecordWorkoutTemplatePickerSheet(
                        modelContext: modelContext,
                        onSelect: { template in
                            pendingTemplate = template
                            showingTemplatePicker = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Completion Ring

    private var completionRing: some View {
        VStack(spacing: 12) {
            ZStack {
                SemiCircleArc()
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 180, height: 100)

                SemiCircleArc()
                    .trim(from: 0, to: todayCompletion)
                    .stroke(
                        todayCompletion > 0 ? Color.green : Color(.systemGray5),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 180, height: 100)
                    .animation(.easeInOut(duration: 0.6), value: todayCompletion)

                Text(completionText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(todayCompletion > 0 ? .primary : .secondary)
                    .offset(y: 10)
            }
            .frame(height: 110)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var completionText: String {
        if todaySessions.isEmpty { return "0%" }
        return "\(Int(todayCompletion * 100))%"
    }

    private var statusMessage: String {
        if todaySessions.isEmpty { return "No workouts logged today" }
        let count = todaySessions.count
        return "\(count) workout\(count == 1 ? "" : "s") logged today"
    }

    // MARK: - Today Summary

    private var todaySummary: some View {
        Group {
            if !todaySessions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(todaySessions, id: \.id) { session in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(session.name)
                                .font(.subheadline)
                            Spacer()
                            Text(session.startedAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 32)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func fetchTodayData() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.startedAt >= todayStart && session.startedAt < todayEnd && session.completedAt != nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        todaySessions = (try? modelContext.fetch(descriptor)) ?? []

        if todaySessions.isEmpty {
            todayCompletion = 0
        } else {
            let allSets = todaySessions.flatMap { $0.exercises.flatMap(\.performedSets) }
            let completed = allSets.filter(\.isCompleted).count
            todayCompletion = allSets.isEmpty ? 1.0 : Double(completed) / Double(allSets.count)
        }
    }
}

// MARK: - Semi-Circle Arc Shape

private struct SemiCircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.maxY),
                radius: rect.width / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
        }
    }
}

// MARK: - Log Workout Setup Sheet
// Single sheet with internal NavigationStack.
// Root view shows an optional template selector + date (+ name if no template).
// Tapping "From Template" pushes the template picker within the same sheet.
// Selecting a template pops back to the root form with the template pre-filled.

private struct LogWorkoutSetupSheet: View {

    let modelContext: ModelContext
    /// Called when user taps Continue. Parent owns the dismiss + delay.
    let onConfirm: (_ name: String, _ date: Date, _ template: WorkoutTemplate?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date = .now
    @State private var selectedTemplate: WorkoutTemplate? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Template selector
                Section {
                    if let template = selectedTemplate {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.headline)
                                Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove") {
                                selectedTemplate = nil
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        NavigationLink {
                            LogTemplatePickerView(modelContext: modelContext) { template in
                                selectedTemplate = template
                            }
                        } label: {
                            Label("From Template", systemImage: "list.clipboard")
                        }
                    }
                } header: {
                    Text("Template (Optional)")
                }

                // Workout details
                Section("Details") {
                    if selectedTemplate == nil {
                        TextField("Workout name", text: $name)
                    }
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Log a Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Continue") {
                        let finalName: String
                        if let template = selectedTemplate {
                            finalName = template.name
                        } else {
                            let trimmed = name.trimmingCharacters(in: .whitespaces)
                            finalName = trimmed.isEmpty ? "Workout Log" : trimmed
                        }
                        onConfirm(finalName, date, selectedTemplate)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Log Template Picker View
// Pushed within LogWorkoutSetupSheet's NavigationStack.
// Uses environment dismiss to pop back to the setup form after selection.

private struct LogTemplatePickerView: View {
    let modelContext: ModelContext
    let onSelect: (WorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
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
                        dismiss() // pop back to setup form
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                            Text("\(template.exercises.count) exercise\(template.exercises.count == 1 ? "" : "s")")
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
        .navigationTitle("Choose Template")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let descriptor = FetchDescriptor<WorkoutTemplate>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            templates = (try? modelContext.fetch(descriptor)) ?? []
        }
    }
}

// MARK: - Record Workout Template Picker Sheet
// Used by the "Record Workout" button. Separate from LogTemplatePickerView
// because it needs a Cancel button (it's the root of its own NavigationStack sheet).

private struct RecordWorkoutTemplatePickerSheet: View {

    let modelContext: ModelContext
    let onSelect: (WorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
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
        .navigationTitle("Choose Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
