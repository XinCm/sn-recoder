import SwiftUI

/// Short-lived "deleted, undo?" pill shown at the bottom of the panel.
struct UndoToast: View {
    let state: PanelModel.UndoState

    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(Theme.neutralIcon)

            Text("已删除「\(state.item.text)」")
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 280, alignment: .leading)

            Button("撤销") {
                panel.performUndo(in: store)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                panel.dismissUndo()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.neutralIcon)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Theme.boxFill)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.10))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
    }
}
