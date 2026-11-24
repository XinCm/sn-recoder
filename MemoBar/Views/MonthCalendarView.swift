import SwiftUI

/// The month page: header, Monday-first weekday strip, and the day-box grid.
struct MonthCalendarView: View {
    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel

    private var grid: MonthGrid { panel.displayedGrid }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 16)
                .padding(.horizontal, Theme.horizontalPadding)
                .frame(height: 30 + 16, alignment: .top)

            weekdayHeader
                .padding(.top, 12)
                .padding(.horizontal, Theme.horizontalPadding)

            monthGrid
                .padding(.top, 8)
                .padding(.horizontal, Theme.horizontalPadding)
        }
        .padding(.bottom, 16)
        .frame(width: Theme.panelWidth, height: Theme.panelHeight, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            HeaderIconButton(systemName: "chevron.left", help: "上个月") {
                withAnimation(.easeInOut(duration: 0.16)) {
                    panel.shiftMonth(by: -1)
                }
            }

            Text(grid.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 120, alignment: .leading)

            HeaderIconButton(systemName: "chevron.right", help: "下个月") {
                withAnimation(.easeInOut(duration: 0.16)) {
                    panel.shiftMonth(by: 1)
                }
            }

            CapsuleTextButton(
                title: "回到今天",
                systemImage: "arrow.uturn.backward",
                tint: panel.isViewingCurrentMonth ? Theme.neutralIcon : .accentColor
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    panel.goToToday()
                }
            }
            .help("回到当前月份并高亮今天")

            Spacer(minLength: 8)

            Text(monthSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HeaderIconButton(systemName: "gearshape", help: "设置") {
                panel.openSettings()
            }
        }
        .frame(height: 30)
    }

    private var monthSummary: String {
        let monthItems = store.items(inMonthWithPrefix: grid.monthPrefix)
        if monthItems.isEmpty {
            return "本月暂无事项"
        }
        let pending = monthItems.reduce(into: 0) { count, item in
            if !item.isCompleted { count += 1 }
        }
        return "本月 \(pending) 项待办 · \(monthItems.count - pending) 项已完成"
    }

    // MARK: - Weekday strip

    private var weekdayHeader: some View {
        HStack(spacing: PanelMetrics.gridSpacing) {
            ForEach(0..<7, id: \.self) { index in
                Text(CalendarText.weekdayShort[index])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(index >= 5 ? Color.secondary.opacity(0.75) : Color.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 18)
    }

    // MARK: - Grid

    /// Rows fill the available grid height, so 4-row months get taller boxes
    /// instead of leaving a gap under the weekday strip.
    private var rowHeight: CGFloat {
        let rows = CGFloat(grid.rowCount)
        let available = PanelMetrics.gridAreaHeight - (rows - 1) * PanelMetrics.gridSpacing
        return max(72, available / rows)
    }

    private var monthGrid: some View {
        VStack(spacing: PanelMetrics.gridSpacing) {
            ForEach(0..<grid.rowCount, id: \.self) { row in
                HStack(spacing: PanelMetrics.gridSpacing) {
                    ForEach(0..<7, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
        .frame(height: PanelMetrics.gridAreaHeight, alignment: .top)
        .animation(.easeInOut(duration: 0.16), value: grid.monthPrefix)
    }

    @ViewBuilder
    private func cell(row: Int, column: Int) -> some View {
        if let day = grid.day(at: row * 7 + column) {
            DayBoxView(day: day, todayKey: panel.todayKey, boxHeight: rowHeight)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
        }
    }

}
