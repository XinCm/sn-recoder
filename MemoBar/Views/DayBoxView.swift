import SwiftUI

/// A single day cell in the month grid. Every day owns its own box: date,
/// memo previews and the add button all live inside it.
struct DayBoxView: View {
    let day: MonthGrid.Day
    let todayKey: String
    let boxHeight: CGFloat

    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    @State private var addHovering = false
    @State private var boxFrame: CGRect = .zero

    private var isToday: Bool { day.key == todayKey }
    private var isPast: Bool { day.key < todayKey }
    private var isAdding: Bool { panel.addingKey == day.key }

    var body: some View {
        let items = store.items(for: day.key)
        let previewLimit = boxHeight >= 108 ? 3 : 2
        let preview = Array(items.prefix(previewLimit))
        let hiddenCount = max(0, items.count - previewLimit)
        let completedCount = items.reduce(into: 0) { count, item in
            if item.isCompleted { count += 1 }
        }

        VStack(alignment: .leading, spacing: 2) {
            header(itemCount: items.count, completedCount: completedCount)

            if isAdding {
                InlineAddField()
                    .padding(.top, 1)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(preview) { item in
                        CompactItemRow(item: item)
                    }
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 0)

            footer(hiddenCount: hiddenCount)
        }
        .padding(.horizontal, 7)
        .padding(.top, 6)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: boxHeight, alignment: .top)
        .background(
            boxBackground
                .contentShape(RoundedRectangle(cornerRadius: Theme.boxCornerRadius, style: .continuous))
                .onTapGesture(count: 2) {
                    guard panel.addingKey != day.key else { return }
                    panel.beginAdd(for: day.key)
                }
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        boxFrame = proxy.frame(in: .global)
                    }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.boxCornerRadius, style: .continuous))
        .onHover { inside in
            hovering = inside
            guard !isAdding else { return }
            if inside {
                guard !items.isEmpty, boxFrame != .zero else { return }
                panel.scheduleHoverPreview(for: day.key, anchorFrame: boxFrame)
            } else {
                panel.hoverDidExit(dateKey: day.key)
            }
        }
        .contextMenu {
            Button("添加事项") { panel.beginAdd(for: day.key) }
            Button("查看全部") { panel.openDay(day.key) }
        }
    }

    // MARK: - Pieces

    private func header(itemCount: Int, completedCount: Int) -> some View {
        HStack(spacing: 4) {
            Button {
                panel.openDay(day.key)
            } label: {
                Text(String(day.day))
                    .font(.system(size: 13, weight: isToday ? .bold : .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dateColor)
                    .frame(height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("查看 \(CalendarText.dayTitle(for: day.key)) 的全部事项")

            if isToday {
                StatusBadge(text: "今天", tint: .accentColor)
            }

            Spacer(minLength: 0)

            if itemCount > 0 && completedCount > 0 {
                Text("\(completedCount)/\(itemCount)")
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 16)
    }

    private func footer(hiddenCount: Int) -> some View {
        HStack(spacing: 4) {
            if isAdding {
                Text("回车保存 · Esc 取消")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else if hiddenCount > 0 {
                Button {
                    panel.openDay(day.key)
                } label: {
                    Text("还有 \(hiddenCount) 项")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.accentColor.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            if !isAdding {
                Button {
                    panel.beginAdd(for: day.key)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(addHovering ? Color.accentColor : Theme.neutralIcon)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle().fill(
                                addHovering
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.primary.opacity(hovering ? 0.05 : 0)
                            )
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .onHover { addHovering = $0 }
                .help("给 \(CalendarText.dayTitle(for: day.key)) 添加事项")
            }
        }
        .frame(height: 20)
    }

    private var dateColor: Color {
        if isToday { return .accentColor }
        if isPast { return Color.secondary.opacity(0.60) }
        return .primary
    }

    private var borderColor: Color {
        if isToday { return .accentColor }
        if isPast { return Color.primary.opacity(0.05) }
        return Color.primary.opacity(hovering ? 0.20 : 0.10)
    }

    private var pastTint: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.05)
    }

    private var boxBackground: some View {
        RoundedRectangle(cornerRadius: Theme.boxCornerRadius, style: .continuous)
            .fill(Theme.boxFill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.boxCornerRadius, style: .continuous)
                    .fill(isToday ? Theme.todayTint : (isPast ? pastTint : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.boxCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isToday ? 2 : 1)
            )
            .shadow(
                color: Color.black.opacity(isToday ? 0.10 : 0.03),
                radius: isToday ? 5 : 2,
                y: 1
            )
    }
}
