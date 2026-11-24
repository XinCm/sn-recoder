import AppKit
import SwiftUI

/// Offline renderer used during development to inspect the panel without
/// clicking the menu bar icon. Produces PNGs in build/previews/.
@main
struct PreviewRenderer {
    @MainActor
    static func main() {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let dataDirectory = root.appendingPathComponent(".build/preview-data", isDirectory: true)
        let outputDirectory = root.appendingPathComponent("build/previews", isDirectory: true)

        try? fileManager.removeItem(at: dataDirectory)
        try? fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let fileStore = MemoFileStore(directory: dataDirectory)
        do {
            try fileStore.save(MemoDatabase(items: DemoData.items))
        } catch {
            fatalError("Could not seed preview data: \(error)")
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let store = MemoStore(fileStore: fileStore)
        let today = DateKey.date(for: "2026-11-24") ?? Date()
        let panel = PanelModel(now: today)

        render(
            name: "month-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory
        )
        render(
            name: "month-dark",
            panel: panel,
            store: store,
            route: .month,
            appearance: .darkAqua,
            colorScheme: .dark,
            outputDirectory: outputDirectory
        )
        render(
            name: "day-light",
            panel: panel,
            store: store,
            route: .day("2026-11-24"),
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory
        )
        render(
            name: "day-dark",
            panel: panel,
            store: store,
            route: .day("2026-11-24"),
            appearance: .darkAqua,
            colorScheme: .dark,
            outputDirectory: outputDirectory
        )
        print("Hover render state before:", String(describing: panel.hoverPreview))
        render(
            name: "hover-preview-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                panel.hoverPreview = PanelModel.HoverPreview(
                    dateKey: "2026-11-18",
                    anchorFrame: CGRect(x: 273, y: 398, width: 119, height: 97)
                )
                print("Hover render state after configure:", String(describing: panel.hoverPreview))
            }
        )
        render(
            name: "hover-preview-dark",
            panel: panel,
            store: store,
            route: .month,
            appearance: .darkAqua,
            colorScheme: .dark,
            outputDirectory: outputDirectory,
            configure: { panel in
                panel.hoverPreview = PanelModel.HoverPreview(
                    dateKey: "2026-11-18",
                    anchorFrame: CGRect(x: 273, y: 398, width: 119, height: 97)
                )
            }
        )
        render(
            name: "hover-long-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                panel.hoverPreview = PanelModel.HoverPreview(
                    dateKey: "2026-11-20",
                    anchorFrame: CGRect(x: 527, y: 398, width: 119, height: 97)
                )
            }
        )
        render(
            name: "settings-light",
            panel: panel,
            store: store,
            route: .settings,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory
        )
        render(
            name: "month-adding-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                panel.beginAdd(for: "2026-11-24")
            }
        )
        render(
            name: "day-empty-light",
            panel: panel,
            store: store,
            route: .day("2026-11-28"),
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory
        )
        render(
            name: "day-editing-light",
            panel: panel,
            store: store,
            route: .day("2026-11-24"),
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                if let item = store.items(for: "2026-11-24").first {
                    panel.beginEditing(item)
                }
            }
        )
        render(
            name: "month-undo-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                if let item = store.items(for: "2026-11-24").first {
                    panel.undo = PanelModel.UndoState(item: item)
                }
            }
        )
        render(
            name: "month-february-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                if let date = DateKey.date(for: "2027-02-10") {
                    panel.now = date
                    panel.displayedMonth = MonthGrid.monthStart(containing: date)
                    // onAppear calls refreshNow(), which would otherwise jump
                    // this preview back to the real current month.
                    panel.followsToday = false
                }
            }
        )
        render(
            name: "month-june-light",
            panel: panel,
            store: store,
            route: .month,
            appearance: .aqua,
            colorScheme: .light,
            outputDirectory: outputDirectory,
            configure: { panel in
                if let date = DateKey.date(for: "2026-06-10") {
                    panel.now = date
                    panel.displayedMonth = MonthGrid.monthStart(containing: date)
                    panel.followsToday = false
                }
            }
        )
        // Restore the demo date for any later render.
        panel.now = today
        panel.displayedMonth = MonthGrid.monthStart(containing: today)
        panel.followsToday = true
    }

    @MainActor
    private static func render(
        name: String,
        panel: PanelModel,
        store: MemoStore,
        route: PanelModel.Route,
        appearance: NSAppearance.Name,
        colorScheme: ColorScheme,
        outputDirectory: URL,
        configure: ((PanelModel) -> Void)? = nil
    ) {
        panel.route = route
        panel.cancelAdd()
        panel.cancelEditing()
        panel.dismissHoverPreview()
        panel.undo = nil
        panel.followsToday = true
        configure?(panel)

        NSApplication.shared.appearance = NSAppearance(named: appearance)

        let backdrop = colorScheme == .dark
            ? Color(red: 0.16, green: 0.16, blue: 0.17)
            : Color(red: 0.95, green: 0.95, blue: 0.96)

        let content = ZStack {
            backdrop
            RootPanelView()
                .environmentObject(store)
                .environmentObject(panel)
        }
        .environment(\.colorScheme, colorScheme)

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: PanelMetrics.width,
            height: PanelMetrics.height
        )
        hosting.wantsLayer = true

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isOpaque = true
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
        window.orderFrontRegardless()

        // Give SwiftUI a moment to lay out text fields and scroll views.
        for _ in 0..<3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))
            hosting.layoutSubtreeIfNeeded()
        }

        // RootPanelView.onAppear clears transient preview state, so apply the
        // requested state again after the first layout pass.
        configure?(panel)
        for _ in 0..<2 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))
            hosting.layoutSubtreeIfNeeded()
        }

        let scale: CGFloat = 2
        let pixelWidth = Int(hosting.bounds.width * scale)
        let pixelHeight = Int(hosting.bounds.height * scale)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("Could not allocate bitmap for \(name)")
        }
        representation.size = hosting.bounds.size
        hosting.cacheDisplay(in: hosting.bounds, to: representation)

        window.orderOut(nil)

        guard let data = representation.representation(using: .png, properties: [:]) else {
            fatalError("Could not encode \(name)")
        }

        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
            print("Rendered \(url.path)")
        } catch {
            fatalError("Could not write \(name): \(error)")
        }
    }

}

enum DemoData {
    static let items: [MemoItem] = {
        func make(_ dateKey: String, _ text: String, completed: Bool = false, order: Int) -> MemoItem {
            let date = DateKey.date(for: dateKey) ?? Date()
            return MemoItem(
                dateKey: dateKey,
                text: text,
                isCompleted: completed,
                sortOrder: order,
                createdAt: date.addingTimeInterval(TimeInterval(order)),
                updatedAt: date.addingTimeInterval(TimeInterval(order))
            )
        }

        return [
            make("2026-11-01", "准备月度复盘", order: 0),
            make("2026-11-03", "阅读《深度工作》第三章", completed: true, order: 0),
            make("2026-11-05", "预约牙医", order: 0),
            make("2026-11-09", "整理上周会议纪要", order: 0),
            make("2026-11-10", "给设计稿补注释", order: 0),
            make("2026-11-12", "团队周会 · 产品评审", order: 0),
            make("2026-11-12", "更新接口文档", completed: true, order: 1),
            make("2026-11-16", "整理实验数据", order: 0),
            make("2026-11-18", "回复邮件", completed: true, order: 0),
            make("2026-11-18", "把本月的差旅发票按项目分类整理好，扫描后上传到财务系统，并在备注里写清楚对应的项目编号和报销人。", order: 1),
            make("2026-11-19", "提交报销单", order: 0),
            make("2026-11-23", "阅读资料", order: 0),
            make("2026-11-23", "整理笔记", completed: true, order: 1),
            make("2026-11-24", "完成项目报告", order: 0),
            make("2026-11-24", "阅读课程资料", completed: true, order: 1),
            make("2026-11-24", "整理实验数据", order: 2),
            make("2026-11-24", "备份项目文件", order: 3),
            make("2026-11-25", "提交作业", order: 0),
            make("2026-11-20", "把本周的会议纪要整理成文档，发给产品、设计和研发三个小组，并在群里同步下周的评审时间。", order: 0),
            make("2026-11-20", "检查新版本在低电量模式下的内存占用，记录数据并补充到性能报告里。", order: 1),
            make("2026-11-20", "给外部合作方回一封邮件，确认合同里的付款节点和交付清单。", order: 2),
            make("2026-11-20", "整理用户访谈记录，按主题归档到共享文件夹，并标记出需要跟进的问题。", order: 3),
            make("2026-11-20", "准备下周的分享会大纲，列出三个核心案例和对应的演示脚本。", order: 4),
            make("2026-11-20", "检查设计稿的深色模式适配，把发现的对比度问题写进任务列表。", order: 5),
            make("2026-11-20", "更新个人 OKR 的进度，补充本月已经完成的事项和下周计划。", order: 6),
            make("2026-11-20", "预约下个月的体检，确认需要空腹的项目和具体时间。", completed: true, order: 7),
            make("2026-11-26", "午休前回复客户消息", order: 0),
            make("2026-11-27", "预约牙医", order: 0),
            make("2026-11-30", "整理发票", order: 0),
            make("2026-06-02", "季度目标复盘", order: 0),
            make("2026-06-15", "准备设计评审", order: 0),
            make("2026-06-15", "整理竞品资料", completed: true, order: 1),
            make("2026-06-15", "给团队发周报", order: 2),
            make("2026-06-15", "备份设计稿", order: 3),
            make("2027-02-10", "春节前收尾", order: 0),
            make("2027-02-10", "整理年度照片", completed: true, order: 1),
            make("2027-02-10", "预约体检", order: 2),
            make("2027-02-10", "更新简历", order: 3)
        ]
    }()
}
