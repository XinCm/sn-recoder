import SwiftUI

/// Panel root. Switches between the month calendar, the day detail page and
/// settings, and owns the transient toast/banner overlays.
struct RootPanelView: View {
    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel

    var body: some View {
        ZStack {
            routeContent

            if case .month = panel.route {
                HoverPreviewOverlay()
            }
        }
        .frame(width: Theme.panelWidth, height: Theme.panelHeight)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let undo = panel.undo {
                    UndoToast(state: undo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                banner
            }
            .padding(.bottom, overlayBottomPadding)
        }
        .animation(.easeInOut(duration: 0.18), value: panel.undo?.id)
        .animation(.easeInOut(duration: 0.18), value: store.saveErrorMessage)
        .animation(.easeInOut(duration: 0.18), value: store.notice)
        .onAppear {
            panel.dismissHoverPreview()
            panel.refreshNow()
        }
        .onDisappear {
            panel.dismissHoverPreview()
        }
    }

    @ViewBuilder
    private var routeContent: some View {
        switch panel.route {
        case .month:
            MonthCalendarView()
        case .day(let dateKey):
            DayDetailView(dateKey: dateKey)
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let message = store.saveErrorMessage {
            PanelBanner(text: message, kind: .error, actionTitle: "重试") {
                store.retrySave()
            }
            .frame(maxWidth: 640)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if let notice = store.notice {
            PanelBanner(text: notice, kind: .info, actionTitle: "知道了") {
                store.dismissNotice()
            }
            .frame(maxWidth: 640)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var overlayBottomPadding: CGFloat {
        switch panel.route {
        case .month:
            return 52
        case .day:
            return 82
        case .settings:
            return 24
        }
    }
}
