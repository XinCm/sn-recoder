import Darwin
import Foundation

@main
struct MemoBarTests {
    @MainActor
    static func main() {
        var failures = 0
        var checks = 0

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1
            if condition() {
                print("  ok  \(message)")
            } else {
                failures += 1
                print("  FAIL \(message)")
            }
        }

        print("MonthGrid")
        let november = MonthGrid(containing: DateKey.date(for: "2026-11-24")!)
        expect(november.year == 2026 && november.month == 11, "November 2026 title parts")
        expect(november.leadingBlanks == 6, "Nov 1 2026 starts on Sunday (6 leading blanks)")
        expect(november.days.count == 30, "November has 30 days")
        expect(november.rowCount == 6, "November 2026 needs 6 rows")
        expect(november.day(at: 6)?.key == "2026-11-01", "first day lands in Sunday column")
        expect(november.day(at: 5) == nil, "blank cells before the 1st are empty")
        expect(november.day(at: 35)?.key == "2026-11-30", "the 30th lands on the last Monday")
        expect(november.day(at: 36) == nil, "trailing blanks are empty")

        let leapFebruary = MonthGrid(containing: DateKey.date(for: "2024-02-10")!)
        expect(leapFebruary.days.count == 29, "February 2024 has 29 days (leap year)")
        expect(leapFebruary.leadingBlanks == 3, "Feb 1 2024 is a Thursday")
        expect(leapFebruary.rowCount == 5, "February 2024 fits in 5 rows")

        let february = MonthGrid(containing: DateKey.date(for: "2026-02-10")!)
        expect(february.days.count == 28, "February 2026 has 28 days")
        expect(february.leadingBlanks == 6, "Feb 1 2026 is a Sunday")
        expect(february.rowCount == 5, "February 2026 fits in 5 rows")

        let august = MonthGrid(containing: DateKey.date(for: "2026-08-10")!)
        expect(august.days.count == 31, "August has 31 days")
        expect(august.rowCount == 6, "August 2026 spans 6 rows")

        print("Month navigation")
        let december = MonthGrid.monthStart(containing: DateKey.date(for: "2026-12-15")!)
        let january = MonthGrid.shifting(months: 1, from: december)
        expect(DateKey.key(for: january) == "2027-01-01", "December + 1 month rolls into 2027")
        let previousDecember = MonthGrid.shifting(months: -1, from: january)
        expect(DateKey.key(for: previousDecember) == "2026-12-01", "January - 1 month rolls back to 2026")

        print("Weekday labels")
        expect(
            CalendarText.weekdayShort == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
            "month header uses Mon-Sun"
        )

        print("DateKey")
        expect(DateKey.key(for: DateKey.date(for: "2026-01-05")!) == "2026-01-05", "date key round-trips")
        expect(DateKey.isPast("2026-11-23", todayKey: "2026-11-24"), "earlier date is past")
        expect(!DateKey.isPast("2026-11-24", todayKey: "2026-11-24"), "today is not past")
        expect(DateKey.isFuture("2026-11-25", todayKey: "2026-11-24"), "later date is future")

        print("MemoStore CRUD + persistence")
        let directory = TestDirectory.make()
        defer { try? FileManager.default.removeItem(at: directory.url) }

        let store = MemoStore(fileStore: MemoFileStore(directory: directory.url))
        expect(store.totalItemCount == 0, "starts empty")

        let first = store.add(text: "  完成项目报告  ", to: "2026-11-24")
        expect(first?.text == "完成项目报告", "trims whitespace when adding")
        expect(store.add(text: "   ", to: "2026-11-24") == nil, "rejects empty items")
        let second = store.add(text: "阅读课程资料", to: "2026-11-24")
        let otherDay = store.add(text: "提交作业", to: "2026-11-25")
        expect(store.items(for: "2026-11-24").map(\.text) == ["完成项目报告", "阅读课程资料"], "items keep insertion order")
        expect(otherDay?.dateKey == "2026-11-25", "items stay on their own date")

        store.toggleCompletion(second!.id)
        expect(store.items(for: "2026-11-24").map(\.text) == ["完成项目报告", "阅读课程资料"], "toggling completion keeps position")
        expect(store.items(for: "2026-11-24")[1].isCompleted, "completion flag is set")

        expect(store.updateText(first!.id, text: "完成项目报告（终稿）"), "edit text")
        expect(!store.updateText(first!.id, text: "   "), "empty edit is rejected")

        let removed = store.delete(first!.id)
        expect(removed != nil && store.itemCount(for: "2026-11-24") == 1, "delete removes the item")
        store.restore(removed!)
        expect(store.items(for: "2026-11-24").map(\.text) == ["完成项目报告（终稿）", "阅读课程资料"], "undo restores original order")

        let reloaded = MemoStore(fileStore: MemoFileStore(directory: directory.url))
        expect(reloaded.totalItemCount == 3, "all items reload from disk")
        expect(reloaded.items(for: "2026-11-24").map(\.text) == ["完成项目报告（终稿）", "阅读课程资料"], "text and order survive a restart")
        expect(reloaded.items(for: "2026-11-24")[1].isCompleted, "completion state survives a restart")
        expect(reloaded.saveErrorMessage == nil && reloaded.notice == nil, "clean load has no warnings")
        expect(FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("memos.json").path), "writes memos.json")

        print("Atomic save + backup recovery")
        let backupDirectory = TestDirectory.make()
        defer { try? FileManager.default.removeItem(at: backupDirectory.url) }
        let backupFileStore = MemoFileStore(directory: backupDirectory.url)
        let backupStore = MemoStore(fileStore: backupFileStore)
        let original = backupStore.add(text: "版本一", to: "2026-11-24")!
        backupStore.add(text: "版本二", to: "2026-11-24")
        // Second save rotates the readable file into the backup slot.
        try? Data("{ not json".utf8).write(to: backupFileStore.fileURL)

        let recovered = backupFileStore.load()
        expect(recovered.database?.items.map(\.text) == ["版本一"], "loads the previous readable backup after corruption")
        expect(recovered.notice?.contains("备份") == true, "tells the user the backup was used")
        expect(FileManager.default.fileExists(atPath: backupFileStore.backupURL.path), "backup file exists")
        expect(original.text == "版本一", "backup contains the older snapshot")

        let secondLoad = backupFileStore.load()
        expect(secondLoad.database?.items.map(\.text) == ["版本一"], "recovered data is written back to the main file")
        expect(secondLoad.notice == nil, "second launch is clean after repair")
        let recoveredCorruptFiles = try? FileManager.default.contentsOfDirectory(atPath: backupDirectory.url.path)
        expect(recoveredCorruptFiles?.contains(where: { $0.hasPrefix("memos.corrupt-") }) == true, "damaged original is preserved after repair")

        print("Corrupt file without backup is preserved")
        let corruptDirectory = TestDirectory.make()
        defer { try? FileManager.default.removeItem(at: corruptDirectory.url) }
        try? Data("{ broken".utf8).write(to: corruptDirectory.url.appendingPathComponent("memos.json"))
        let corruptResult = MemoFileStore(directory: corruptDirectory.url).load()
        expect(corruptResult.database == nil, "unreadable data is not presented as memos")
        expect(corruptResult.notice?.contains("memos.corrupt-") == true, "notice mentions the preserved copy")
        let preserved = try? FileManager.default.contentsOfDirectory(atPath: corruptDirectory.url.path)
        expect(preserved?.contains(where: { $0.hasPrefix("memos.corrupt-") }) == true, "corrupt original is kept on disk")

        print("Month prefix query")
        expect(store.items(inMonthWithPrefix: "2026-11").count == 3, "month prefix finds all November items")
        expect(store.items(inMonthWithPrefix: "2026-12").isEmpty, "other months are empty")

        print("Hover preview bridge")
        let hoverPanel = PanelModel(now: DateKey.date(for: "2026-11-24") ?? Date())
        let hoverKey = "2026-11-18"
        let hoverAnchor = CGRect(x: 100, y: 100, width: 100, height: 100)
        let wait = { (seconds: TimeInterval) in
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }

        hoverPanel.hoverPreview = PanelModel.HoverPreview(dateKey: hoverKey, anchorFrame: hoverAnchor)
        hoverPanel.hoverDidExit(dateKey: hoverKey)
        hoverPanel.previewHoverChanged(true)
        wait(0.5)
        expect(hoverPanel.hoverPreview != nil, "card stays when leaving the day into the card")

        hoverPanel.previewHoverChanged(false)
        wait(0.4)
        expect(hoverPanel.hoverPreview == nil, "card hides after leaving both day and card")

        hoverPanel.hoverPreview = PanelModel.HoverPreview(dateKey: hoverKey, anchorFrame: hoverAnchor)
        hoverPanel.previewHoverChanged(true)
        hoverPanel.hoverDidExit(dateKey: hoverKey)
        wait(0.5)
        expect(hoverPanel.hoverPreview != nil, "card stays when card hover arrives first")

        hoverPanel.dismissHoverPreview()
        expect(hoverPanel.hoverPreview == nil, "explicit dismissal clears the card")

        print("Hover preview placement")
        let panelSize = CGSize(width: PanelMetrics.width, height: PanelMetrics.height)
        let horizontalPadding: CGFloat = 18
        let columnWidth = (panelSize.width - horizontalPadding * 2 - PanelMetrics.gridSpacing * 6) / 7
        let gridTop: CGFloat = 16 + 30 + 12 + 18 + 8
        let cardHeights: [CGFloat] = [150, 300, HoverPreviewLayout.chromeHeight + HoverPreviewLayout.maxItemsHeight]

        for rows in [4, 5, 6] {
            let rowHeight = (PanelMetrics.gridAreaHeight - CGFloat(rows - 1) * PanelMetrics.gridSpacing) / CGFloat(rows)
            var problems: [String] = []

            for row in 0..<rows {
                for column in 0..<7 {
                    let anchor = CGRect(
                        x: horizontalPadding + CGFloat(column) * (columnWidth + PanelMetrics.gridSpacing),
                        y: gridTop + CGFloat(row) * (rowHeight + PanelMetrics.gridSpacing),
                        width: columnWidth,
                        height: rowHeight
                    )
                    for cardHeight in cardHeights {
                        let cardSize = CGSize(width: HoverPreviewLayout.width, height: cardHeight)
                        let frame = HoverPreviewLayout.cardFrame(
                            anchor: anchor,
                            panelSize: panelSize,
                            cardSize: cardSize
                        )
                        if frame.intersects(anchor) {
                            problems.append("overlaps row \(row) column \(column) height \(cardHeight)")
                        }
                        let safeBounds = CGRect(origin: .zero, size: panelSize)
                            .insetBy(dx: HoverPreviewLayout.margin - 0.5, dy: HoverPreviewLayout.margin - 0.5)
                        if !safeBounds.contains(frame) {
                            problems.append("outside panel row \(row) column \(column)")
                        }
                    }
                }
            }

            expect(problems.isEmpty, "hover card stays clear of every day box in \(rows)-row months")
        }

        print("")
        if failures == 0 {
            print("All \(checks) checks passed.")
            exit(0)
        } else {
            print("\(failures) of \(checks) checks failed.")
            exit(1)
        }
    }
}

private struct TestDirectory {
    let url: URL

    static func make() -> TestDirectory {
        let base = FileManager.default.currentDirectoryPath + "/.build/tests"
        let url = URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return TestDirectory(url: url)
    }
}
