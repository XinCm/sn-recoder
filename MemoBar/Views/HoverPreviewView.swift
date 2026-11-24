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

/// Places the card beside the hovered day box. The placement math lives in
/// `HoverPreviewLayout` and guarantees the card never covers the anchor box.
private struct HoverPreviewPlacement: View {
    let dateKey: String
    let anchorFrame: CGRect
    let panelSize: CGSize

    @EnvironmentObject private var store: MemoStore

    var body: some View {
        let items = store.items(for: dateKey)
        let size = CGSize(
            width: HoverPreviewLayout.width,
            height: HoverPreviewLayout.cardHeight(for: items)
        )
        let origin = HoverPreviewLayout.cardOrigin(
            anchor: anchorFrame,
            panelSize: panelSize,
            cardSize: size
        )

        HoverPreviewCard(dateKey: dateKey)
            .frame(width: size.width)
            .position(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
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
        let estimatedHeight = HoverPreviewLayout.estimatedItemsHeight(for: items)
        let effectiveHeight = measuredItemsHeight > 0 ? measuredItemsHeight : estimatedHeight
        let itemsViewport = min(max(effectiveHeight, 1), HoverPreviewLayout.maxItemsHeight)
        let scrolls = effectiveHeight > HoverPreviewLayout.maxItemsHeight

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
        .frame(width: HoverPreviewLayout.width, alignment: .leading)
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
