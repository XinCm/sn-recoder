import AppKit
import SwiftUI

enum Theme {
    static let panelWidth = PanelMetrics.width
    static let panelHeight = PanelMetrics.height

    static let horizontalPadding: CGFloat = 18
    static let boxCornerRadius: CGFloat = 10

    /// A translucent, appearance-adaptive card fill. It reads as a solid card
    /// over the menu bar panel material in both light and dark mode without
    /// needing two separate color sets.
    static let boxFill = Color.primary.opacity(0.035)
    static let todayTint = Color.accentColor.opacity(0.10)

    /// Explicit neutral icon color. `Color.secondary` can be rendered with
    /// vibrancy inside the menu bar panel and washes out on some systems.
    static let neutralIcon = Color.primary.opacity(0.55)
    static let controlFill = Color.primary.opacity(0.06)
    static let controlBorder = Color.primary.opacity(0.10)
}

/// Small square icon button used in panel headers.
struct HeaderIconButton: View {
    let systemName: String
    let help: String
    var isActive = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : Theme.neutralIcon)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Capsule text button used for "回到今天" and "月历".
struct CapsuleTextButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = .primary
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(hovering ? 0.10 : 0.06)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Round completion toggle shown at the trailing edge of a memo.
struct CompletionCircle: View {
    let isCompleted: Bool
    var size: CGFloat = 13
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.accentColor.opacity(0.16) : Color.clear)
                Circle()
                    .strokeBorder(
                        isCompleted
                            ? Color.accentColor.opacity(0.75)
                            : Color.primary.opacity(hovering ? 0.85 : 0.35),
                        lineWidth: 1.2
                    )
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.56, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: size, height: size)
            .padding(2.5)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(isCompleted ? "标记为未完成" : "标记为已完成")
        .accessibilityLabel(isCompleted ? "已完成，点击恢复未完成" : "未完成，点击标记完成")
    }
}

/// A soft badge such as "今天" or "已过去".
struct StatusBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(tint.opacity(0.13)))
            .fixedSize()
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.boxFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

struct PanelBanner: View {
    enum Kind {
        case error
        case info

        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .error: return .orange
            case .info: return .accentColor
            }
        }
    }

    let text: String
    let kind: Kind
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kind.tint)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(actionTitle, action: action)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(kind.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(kind.tint.opacity(0.35))
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
    }
}
