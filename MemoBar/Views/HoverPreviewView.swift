import SwiftUI

/// Floating "quick look" card shown when the pointer rests on a day with memos.
/// It lives inside the menu bar panel, is positioned next to the day box and
/// stays open while the pointer moves onto it, so long notes can be scrolled.
struct HoverPreviewOverlay: View {
    @EnvironmentObject private var panel: PanelModel

    var body: some View {
        GeometryReader { proxy in
            if let preview = panel.hoverPreview {
                HoverPreviewPlacement(
                    dateKey: preview.dateKey,
                    anchorFrame: preview.anchorFrame,
                    panelSize: proxy.size
                )
                .id(preview.dateKey)
                .transition(.opacity)
            }
        }
        .allowsHitTesting(panel.hoverPreview != nil)
        .animation(.easeOut(duration: 0.12), value: panel.hoverPreview)
    }
}

/// Measures the card, then decides whether it sits to the right or the left of
/// the hovered day box.
private struct HoverPreviewPlacement: View {
    let dateKey: String
    let anchorFrame: CGRect
    let panelSize: CGSize

    @EnvironmentObject private var store: MemoStore

    private let margin: CGFloat = 14
    private let gap: CGFloat = 16

    var body: some View {
        let items = store.items(for: dateKey)
        let size = CGSize(
            width: HoverPreviewMetrics.width,
            height: HoverPreviewMetrics.cardHeight(for: items)
        )

        HoverPreviewCard(dateKey: dateKey)
            .frame(width: HoverPreviewMetrics.width)
            .position(position(for: size))
    }

    private func position(for size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height

        let rightSpace = panelSize.width - anchorFrame.maxX - margin
        let leftSpace = anchorFrame.minX - margin
        let required = width + gap

        var x: CGFloat
        if rightSpace >= required {
            x = anchorFrame.maxX + gap + width / 2
        } else if leftSpace >= required {
            x = anchorFrame.minX - gap - width / 2
        } else {
            x = rightSpace >= leftSpace
                ? anchorFrame.maxX + gap + width / 2
                : anchorFrame.minX - gap - width / 2
        }
        x = min(max(x, margin + width / 2), panelSize.width - margin - width / 2)

        var y = anchorFrame.midY
        y = min(max(y, margin + height / 2), panelSize.height - margin - height / 2)
        return CGPoint(x: x, y: y)
    }
}

private struct HoverPreviewCard: View {
    let dateKey: String

    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var measuredItemsHeight: CGFloat = 0

    var body: some View {
        let items = store.items(for: dateKey)
        let completed = items.reduce(into: 0) { count, item in
            if item.isCompleted { count += 1 }
        }
        let estimatedHeight = HoverPreviewMetrics.estimatedItemsHeight(for: items)
        let effectiveHeight = measuredItemsHeight > 0 ? measuredItemsHeight : estimatedHeight
        let itemsViewport = min(max(effectiveHeight, 1), HoverPreviewMetrics.maxItemsHeight)
        let scrolls = effectiveHeight > HoverPreviewMetrics.maxItemsHeight

        VStack(alignment: .leading, spacing: 0) {
            header(items: items, completed: completed)
                .padding(.bottom, 10)

            Divider().opacity(0.5)

            ScrollView(.vertical, showsIndicators: scrolls) {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(items) { item in
                        HoverPreviewItemRow(item: item)
                    }
                }
                .padding(.vertical, 10)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HoverItemsHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .frame(height: itemsViewport)
            .onPreferenceChange(HoverItemsHeightKey.self) { height in
                measuredItemsHeight = height
            }

            Divider().opacity(0.5)

            footer(items: items, scrolls: scrolls)
                .padding(.top, 10)
        }
        .padding(16)
        .frame(width: HoverPreviewMetrics.width, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thickMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.62))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.22),
            radius: 22,
            y: 10
        )
        .onHover { inside in
            panel.previewHoverChanged(inside)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(CalendarText.dayTitle(for: dateKey)) 快速预览")
    }

    // MARK: - Header

    private func header(items: [MemoItem], completed: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(CalendarText.dayTitle(for: dateKey))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    if dateKey == panel.todayKey {
                        StatusBadge(text: "今天", tint: .accentColor)
                    } else if dateKey < panel.todayKey {
                        StatusBadge(text: "已过去", tint: .secondary)
                    }
                }

                Text(subtitle(items: items, completed: completed))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                panel.dismissHoverPreview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.neutralIcon)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("关闭预览")
        }
    }

    private func subtitle(items: [MemoItem], completed: Int) -> String {
        let weekday = CalendarText.weekdayLong(for: dateKey)
        if items.isEmpty {
            return "\(weekday) · 暂无事项"
        }
        return "\(weekday) · \(items.count) 项 · \(completed) 项已完成"
    }

    // MARK: - Footer

    private func footer(items: [MemoItem], scrolls: Bool) -> some View {
        HStack(spacing: 8) {
            Text(scrolls ? "滚动查看全部内容" : "快速预览")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 8)

            Button("查看全部") {
                panel.openDay(dateKey)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(items.isEmpty)
        }
    }

}

/// Geometry shared by the card, its scroll viewport and the positioning logic.
enum HoverPreviewMetrics {
    static let width: CGFloat = 380
    static let maxItemsHeight: CGFloat = 360
    static let chromeHeight: CGFloat = 116

    /// Rough content height used for positioning before the card has laid out.
    static func estimatedItemsHeight(for items: [MemoItem]) -> CGFloat {
        guard !items.isEmpty else { return 30 }
        let usableWidth: CGFloat = width - 32 - 14 - 8
        let charsPerLine = max(12, usableWidth / 12.5)

        var lineCount: CGFloat = 0
        for item in items {
            let visualLength = item.text.reduce(CGFloat(0)) { length, character in
                length + (character.isASCII ? 0.55 : 1)
            }
            lineCount += max(1, ceil(visualLength / charsPerLine))
        }
        return lineCount * 18 + CGFloat(items.count) * 9 + 20
    }

    static func cardHeight(for items: [MemoItem]) -> CGFloat {
        let itemsHeight = min(
            max(estimatedItemsHeight(for: items), 1),
            maxItemsHeight
        )
        return chromeHeight + itemsHeight
    }
}

private struct HoverPreviewItemRow: View {
    let item: MemoItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            PreviewStatusDot(isCompleted: item.isCompleted)
                .padding(.top, 2)

            Text(item.text)
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .strikethrough(item.isCompleted, color: Color.secondary)
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct PreviewStatusDot: View {
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.accentColor.opacity(0.16) : Color.clear)
            Circle()
                .strokeBorder(
                    isCompleted ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.30),
                    lineWidth: 1.2
                )
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 14, height: 14)
    }
}

private struct HoverItemsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
