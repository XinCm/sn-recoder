import SwiftUI

/// Full list for one day, shown inside the same panel as the month view.
struct DayDetailView: View {
    let dateKey: String

    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel
    @State private var newText = ""
    @FocusState private var addFocused: Bool

    private var isToday: Bool { dateKey == panel.todayKey }
    private var isPast: Bool { dateKey < panel.todayKey }

    var body: some View {
        let items = store.items(for: dateKey)
        let completed = items.reduce(into: 0) { count, item in
            if item.isCompleted { count += 1 }
        }

        VStack(spacing: 0) {
            header(items: items, completed: completed)
                .padding(.top, 16)
                .padding(.horizontal, Theme.horizontalPadding)
                .frame(height: 30 + 16, alignment: .top)

            Divider().opacity(0.6)

            content(items: items)
                .frame(maxHeight: .infinity)

            Divider().opacity(0.6)

            addBar
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 16)
        }
        .frame(width: Theme.panelWidth, height: Theme.panelHeight, alignment: .top)
    }

    // MARK: - Header

    private func header(items: [MemoItem], completed: Int) -> some View {
        HStack(spacing: 8) {
            CapsuleTextButton(title: "月历", systemImage: "chevron.left", tint: Theme.neutralIcon) {
                panel.backToMonth()
            }
            .help("返回月历")

            Text(CalendarText.dayTitle(for: dateKey))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text(CalendarText.weekdayLong(for: dateKey))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if isToday {
                StatusBadge(text: "今天", tint: .accentColor)
            } else if isPast {
                StatusBadge(text: "已过去", tint: .secondary)
            }

            Spacer(minLength: 8)

            Text(summary(items: items, completed: completed))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(height: 30)
    }

    private func summary(items: [MemoItem], completed: Int) -> String {
        if items.isEmpty { return "暂无事项" }
        let pending = items.count - completed
        return "\(pending) 项待办 · \(completed) 项已完成"
    }

    // MARK: - List

    @ViewBuilder
    private func content(items: [MemoItem]) -> some View {
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.primary.opacity(0.18))
                Text("这一天还没有事项")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("在下方输入内容，按回车即可添加")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { item in
                        DetailItemRow(item: item)
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Add bar

    private var addBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.40))

                TextField("添加一条事项，回车保存…", text: $newText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($addFocused)
                    .onSubmit { addItem() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10))
            )

            Button("添加") {
                addItem()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(trimmedNewText.isEmpty)
        }
    }

    private var trimmedNewText: String {
        newText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addItem() {
        guard store.add(text: newText, to: dateKey) != nil else { return }
        newText = ""
        addFocused = true
    }
}

/// A single editable memo row in the day detail page.
struct DetailItemRow: View {
    let item: MemoItem

    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel
    @State private var hovering = false
    @FocusState private var editFocused: Bool

    private var isEditing: Bool { panel.editingItemID == item.id }

    var body: some View {
        HStack(spacing: 9) {
            CompletionCircle(isCompleted: item.isCompleted, size: 17) {
                store.toggleCompletion(item.id)
            }

            if isEditing {
                editField
            } else {
                Text(item.text)
                    .font(.system(size: 13))
                    .strikethrough(item.isCompleted, color: Color.secondary)
                    .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 8)

            if isEditing {
                Button("保存") {
                    panel.commitEditing(in: store)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            } else if hovering {
                Button {
                    panel.delete(item, in: store)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.neutralIcon)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.045) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) {
            if !isEditing {
                panel.beginEditing(item)
            }
        }
        .contextMenu {
            Button(item.isCompleted ? "标记为未完成" : "标记为已完成") {
                store.toggleCompletion(item.id)
            }
            Button("编辑") {
                panel.beginEditing(item)
            }
            Divider()
            Button("删除", role: .destructive) {
                panel.delete(item, in: store)
            }
        }
    }

    private var editField: some View {
        TextField("事项内容", text: $panel.editDraft)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($editFocused)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.55))
            )
            .onSubmit {
                panel.commitEditing(in: store)
            }
            .onExitCommand {
                panel.cancelEditing()
            }
            .onAppear {
                DispatchQueue.main.async { editFocused = true }
            }
    }
}
