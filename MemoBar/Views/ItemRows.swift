import SwiftUI

/// One memo inside a day box in the month grid.
struct CompactItemRow: View {
    let item: MemoItem

    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 3) {
            Text(item.text)
                .font(.system(size: 11))
                .strikethrough(item.isCompleted, color: Color.secondary)
                .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(item.text)
                .onTapGesture(count: 2) {
                    panel.openDay(item.dateKey)
                    panel.beginEditing(item)
                }

            Spacer(minLength: 0)

            CompletionCircle(isCompleted: item.isCompleted, size: 12) {
                store.toggleCompletion(item.id)
            }
        }
        .frame(height: 18)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(item.isCompleted ? "标记为未完成" : "标记为已完成") {
                store.toggleCompletion(item.id)
            }
            Button("编辑") {
                panel.openDay(item.dateKey)
                panel.beginEditing(item)
            }
            Divider()
            Button("删除", role: .destructive) {
                panel.delete(item, in: store)
            }
        }
    }
}

/// Inline editor shown inside a day box right after pressing "+".
struct InlineAddField: View {
    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 3) {
            TextField("新事项…", text: $panel.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($focused)
                .onSubmit {
                    panel.commitAdd(in: store)
                }
                .onExitCommand {
                    panel.cancelAdd()
                }

            Button {
                panel.cancelAdd()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary.opacity(0.40))
            }
            .buttonStyle(.plain)
            .help("取消（Esc）")
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }
}
