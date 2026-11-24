import AppKit
import SwiftUI

/// UI state for the menu bar panel: which month is visible, which sub-page is
/// open, inline editing drafts, and the short-lived undo affordance.
@MainActor
final class PanelModel: ObservableObject {
    enum Route: Equatable {
        case month
        case day(String)
        case settings
    }

    struct UndoState: Identifiable, Equatable {
        let id: UUID
        let item: MemoItem

        init(item: MemoItem) {
            self.id = UUID()
            self.item = item
        }
    }

    /// A day box currently under the pointer, anchored in panel coordinates.
    struct HoverPreview: Equatable {
        let dateKey: String
        let anchorFrame: CGRect
    }

    @Published var displayedMonth: Date
    @Published var route: Route = .month
    @Published var now: Date
    @Published var addingKey: String?
    @Published var draft: String = ""
    @Published var undo: UndoState?
    @Published var editingItemID: UUID?
    @Published var editDraft: String = ""
    @Published var followsToday = true
    @Published var hoverPreview: HoverPreview?

    private var observerTokens: [NSObjectProtocol] = []
    private var midnightTimer: Timer?
    private var undoTask: Task<Void, Never>?
    private var hoverShowTask: Task<Void, Never>?
    private var hoverHideTask: Task<Void, Never>?
    private var isPreviewHovered = false

    init(now: Date = Date()) {
        self.now = now
        self.displayedMonth = MonthGrid.monthStart(containing: now)
        observeSystemChanges()
        scheduleMidnightRefresh()
    }

    // MARK: - Derived values

    var todayKey: String { DateKey.key(for: now) }

    var displayedGrid: MonthGrid { MonthGrid(containing: displayedMonth) }

    var isViewingCurrentMonth: Bool {
        displayedGrid.monthPrefix == todayKey.prefix(7)
    }

    // MARK: - Navigation

    func shiftMonth(by delta: Int) {
        dismissHoverPreview()
        displayedMonth = MonthGrid.shifting(months: delta, from: displayedMonth)
        followsToday = false
        cancelAdd()
    }

    func goToToday() {
        dismissHoverPreview()
        now = Date()
        displayedMonth = MonthGrid.monthStart(containing: now)
        followsToday = true
        route = .month
        cancelAdd()
    }

    func openDay(_ key: String) {
        dismissHoverPreview()
        route = .day(key)
        cancelAdd()
        editingItemID = nil
    }

    func openSettings() {
        dismissHoverPreview()
        route = .settings
        cancelAdd()
        editingItemID = nil
    }

    func backToMonth() {
        dismissHoverPreview()
        route = .month
        cancelAdd()
        cancelEditing()
    }

    // MARK: - Inline add (month grid)

    func beginAdd(for key: String) {
        dismissHoverPreview()
        addingKey = key
        draft = ""
        route = .month
    }

    func cancelAdd() {
        addingKey = nil
        draft = ""
    }

    @discardableResult
    func commitAdd(in store: MemoStore) -> Bool {
        guard let key = addingKey else { return false }
        let added = store.add(text: draft, to: key)
        cancelAdd()
        return added != nil
    }

    // MARK: - Editing

    func beginEditing(_ item: MemoItem) {
        editingItemID = item.id
        editDraft = item.text
    }

    func cancelEditing() {
        editingItemID = nil
        editDraft = ""
    }

    @discardableResult
    func commitEditing(in store: MemoStore) -> Bool {
        guard let id = editingItemID else { return false }
        let changed = store.updateText(id, text: editDraft)
        cancelEditing()
        return changed
    }

    // MARK: - Deletion + undo

    func delete(_ item: MemoItem, in store: MemoStore) {
        guard let removed = store.delete(item.id) else { return }
        if editingItemID == removed.id {
            cancelEditing()
        }
        registerUndo(for: removed)
    }

    func performUndo(in store: MemoStore) {
        guard let state = undo else { return }
        store.restore(state.item)
        dismissUndo()
    }

    func dismissUndo() {
        undoTask?.cancel()
        undoTask = nil
        undo = nil
    }

    private func registerUndo(for item: MemoItem) {
        undoTask?.cancel()
        undo = UndoState(item: item)
        let stateID = undo?.id
        undoTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.undo?.id == stateID {
                self.undo = nil
            }
        }
    }

    // MARK: - Hover preview

    /// Schedules the enlarged day card after a short intent delay, so moving
    /// across the calendar does not flash previews.
    func scheduleHoverPreview(for dateKey: String, anchorFrame: CGRect) {
        guard route == .month, addingKey == nil else { return }
        hoverHideTask?.cancel()
        hoverShowTask?.cancel()

        if hoverPreview?.dateKey == dateKey { return }

        isPreviewHovered = false
        hoverShowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.route == .month, self.addingKey == nil else { return }
            self.hoverPreview = HoverPreview(dateKey: dateKey, anchorFrame: anchorFrame)
        }
    }

    func hoverDidExit(dateKey: String) {
        hoverShowTask?.cancel()
        guard hoverPreview?.dateKey == dateKey else { return }
        // The pointer may have moved straight onto the preview card; in that
        // case the card's own hover state keeps it alive.
        guard !isPreviewHovered else { return }
        scheduleHoverHide(after: 0.30)
    }

    func previewHoverChanged(_ inside: Bool) {
        isPreviewHovered = inside
        if inside {
            hoverHideTask?.cancel()
        } else {
            scheduleHoverHide(after: 0.30)
        }
    }

    func dismissHoverPreview() {
        hoverShowTask?.cancel()
        hoverHideTask?.cancel()
        hoverShowTask = nil
        hoverHideTask = nil
        isPreviewHovered = false
        hoverPreview = nil
    }

    private func scheduleHoverHide(after delay: TimeInterval) {
        hoverHideTask?.cancel()
        hoverHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hoverPreview = nil
            self?.isPreviewHovered = false
        }
    }

    // MARK: - Date refresh

    /// Re-evaluates "today" after midnight, wake, time-zone or clock changes.
    func refreshNow() {
        now = Date()
        if followsToday {
            displayedMonth = MonthGrid.monthStart(containing: now)
        }
        scheduleMidnightRefresh()
    }

    private func observeSystemChanges() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .NSCalendarDayChanged,
            .NSSystemTimeZoneDidChange,
            .NSSystemClockDidChange
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            }
            observerTokens.append(token)
        }

        let wakeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        observerTokens.append(wakeToken)
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        let calendar = DateKey.calendar
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return }
        let interval = max(1, startOfTomorrow.timeIntervalSinceNow + 1)

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }
}
