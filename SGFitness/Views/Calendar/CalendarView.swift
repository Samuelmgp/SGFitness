import SwiftUI
import SwiftData

// MARK: - CalendarView
// Secondary detailed month-view calendar.
// Pushed from WorkoutHistoryView's navigation bar calendar button.
//
// Each day cell shows:
//   • Background tint: workout-status colour (green / yellow / purple)
//   • Coloured dots:   muscle groups trained that day
//   • Medal icon:      best PR medal earned that day (🥇🥈🥉)
//
// Tapping a day opens WorkoutPreviewView — a sheet listing all sessions
// with full exercise breakdown.

struct CalendarView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CalendarViewModel?
    @State private var selectedDay: Date?

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                let vm = CalendarViewModel(modelContext: modelContext)
                vm.fetchMonthData()
                viewModel = vm
            }
        }
    }

    // MARK: - Main Content

    private func content(vm: CalendarViewModel) -> some View {
        VStack(spacing: 0) {
            monthHeader(vm: vm)

            // Day-of-week column labels
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            Divider()

            // Calendar grid rows
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(vm.calendarGrid.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 2) {
                            ForEach(0..<7, id: \.self) { col in
                                if let date = week[col] {
                                    DayCell(
                                        date: date,
                                        data: vm.dayData[Calendar.current.startOfDay(for: date)],
                                        isToday: Calendar.current.isDateInToday(date)
                                    )
                                    .onTapGesture {
                                        if vm.dayData[Calendar.current.startOfDay(for: date)] != nil {
                                            selectedDay = date
                                        }
                                    }
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                // Legend
                calendarLegend
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedDay != nil },
            set: { if !$0 { selectedDay = nil } }
        )) {
            if let day = selectedDay,
               let data = viewModel?.dayData[Calendar.current.startOfDay(for: day)] {
                WorkoutPreviewView(day: day, dayData: data)
            }
        }
    }

    // MARK: - Month Header

    private func monthHeader(vm: CalendarViewModel) -> some View {
        HStack {
            Button {
                vm.navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(vm.monthTitle)
                .font(.headline)

            Spacer()

            Button {
                vm.navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Legend

    private var calendarLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                legendItem(color: .green,  label: "Target met")
                legendItem(color: .yellow, label: "Partial")
                legendItem(color: .purple, label: "Exceeded")
            }

            Text("Muscle Groups")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    legendItem(color: muscleGroupColor(group), label: group.rawValue)
                }
                legendItem(color: .cyan, label: "Cardio")
            }
        }
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - DayCell

private struct DayCell: View {

    let date: Date
    let data: CalendarDayData?
    let isToday: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cellBackground)

            if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.primary, lineWidth: 1.5)
            }

            VStack(spacing: 2) {
                // Day number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? .primary : .primary)

                if let data {
                    // Muscle-group dots (max 4)
                    muscleDots(data)

                    // PR medal
                    if let medal = data.bestMedal {
                        Image(systemName: medal.sfSymbol)
                            .font(.system(size: 9))
                            .foregroundStyle(medalColor(medal))
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
    }

    // MARK: - Helpers

    private var cellBackground: Color {
        guard let status = data?.dominantStatus else {
            return Color(.systemGray6)
        }
        switch status {
        case .exceeded:  return .purple.opacity(0.25)
        case .targetMet: return .green.opacity(0.25)
        case .partial:   return .yellow.opacity(0.25)
        }
    }

    @ViewBuilder
    private func muscleDots(_ data: CalendarDayData) -> some View {
        let dots: [Color] = {
            var colors: [Color] = data.muscleGroups.prefix(4).map { muscleGroupColor($0) }
            if data.hasCardio && colors.count < 4 { colors.append(.cyan) }
            return colors
        }()

        if !dots.isEmpty {
            HStack(spacing: 2) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 5, height: 5)
                }
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
}

// MARK: - Shared colour helpers (file-private)

func muscleGroupColor(_ group: MuscleGroup) -> Color {
    switch group {
    case .chest:     return .red
    case .back:      return .blue
    case .legs:      return .orange
    case .shoulders: return .purple
    case .arms:      return .green
    case .core:      return .yellow
    }
}
