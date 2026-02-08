import SwiftUI

struct YearGridView: View {

    @Bindable var viewModel: YearGridViewModel

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Year header
            HStack {
                Button { viewModel.navigateYear(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }

                Text("\(String(viewModel.year))")
                    .font(.subheadline.bold())

                Button { viewModel.navigateYear(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }

                Spacer()

                // Legend
                legendView
            }

            // Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(weeksInYear(), id: \.self) { weekStart in
                        VStack(spacing: cellSpacing) {
                            ForEach(daysInWeek(from: weekStart), id: \.self) { day in
                                let status = viewModel.cellData[calendar.startOfDay(for: day)] ?? .none
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForStatus(status))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }

            // Month labels
            monthLabels
        }
        .padding()
        .onAppear { viewModel.fetchYearData() }
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 4) {
            legendDot(.green, label: "Done")
            legendDot(.yellow, label: "Partial")
            legendDot(.red, label: "Skipped")
        }
        .font(.caption2)
    }

    private func legendDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Month Labels

    private var monthLabels: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { month in
                    Text(formatter.shortMonthSymbols[month])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: (cellSize + cellSpacing) * 4.3, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Date Calculations

    private func weeksInYear() -> [Date] {
        var components = DateComponents()
        components.year = viewModel.year
        components.month = 1
        components.day = 1
        guard let yearStart = calendar.date(from: components) else { return [] }

        // Find the start of the week containing Jan 1
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: yearStart))!

        var weeks: [Date] = []
        var current = weekStart

        var endComponents = DateComponents()
        endComponents.year = viewModel.year + 1
        endComponents.month = 1
        endComponents.day = 1
        let yearEnd = calendar.date(from: endComponents) ?? yearStart

        while current < yearEnd {
            weeks.append(current)
            current = calendar.date(byAdding: .weekOfYear, value: 1, to: current)!
        }

        return weeks
    }

    private func daysInWeek(from weekStart: Date) -> [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private func colorForStatus(_ status: DayStatus) -> Color {
        switch status {
        case .completed: return .green
        case .partial: return .yellow
        case .skipped: return .red
        case .none: return Color(.systemGray5)
        }
    }
}
