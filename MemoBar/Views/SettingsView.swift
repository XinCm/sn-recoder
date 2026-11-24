import AppKit
import SwiftUI

/// Settings live inside the panel (no separate preferences window), keeping the
/// app to a single surface.
struct SettingsView: View {
    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var panel: PanelModel

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 16)
                .padding(.horizontal, Theme.horizontalPadding)
                .frame(height: 30 + 16, alignment: .top)

            Divider().opacity(0.6)

            ScrollView {
                VStack(spacing: 14) {
                    launchCard
                    dataCard
                    tipsCard
                    aboutCard
                    quitButton
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.vertical, 16)
            }
        }
        .frame(width: Theme.panelWidth, height: Theme.panelHeight, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            CapsuleTextButton(title: "月历", systemImage: "chevron.left", tint: Theme.neutralIcon) {
                panel.backToMonth()
            }
            .help("返回月历")

            Text("设置")
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            Spacer()

            Text("MemoBar 1.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 30)
    }

    // MARK: - Cards

    private var launchCard: some View {
        SettingsCard(title: "启动") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("开机时自动启动")
                        .font(.system(size: 13, weight: .medium))
                    Text("登录后自动在菜单栏启动，不需要 Dock 图标。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: launchBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if let launchError {
                Text(launchError)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else {
                Text("通过 ~/Library/LaunchAgents/\(LaunchAtLogin.agentLabel).plist 实现")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = LaunchAtLogin.isEnabled
                    launchError = nil
                } catch {
                    launchError = error.localizedDescription
                }
            }
        )
    }

    private var dataCard: some View {
        SettingsCard(title: "数据") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.neutralIcon)
                    Text(store.dataFileURL.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(store.dataFileURL.path)
                    Spacer(minLength: 8)
                    Button("在 Finder 中显示") {
                        revealDataFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider().opacity(0.5)

                HStack {
                    Text("保存状态")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let error = store.saveErrorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    } else {
                        Text("已自动保存 · 共 \(store.totalItemCount) 条记录")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("每次修改后立即写入；写文件时采用原子替换，并保留上一份可读取的备份。")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var tipsCard: some View {
        SettingsCard(title: "使用提示") {
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "hand.point.up.left", text: "点击菜单栏日历图标打开面板，点击面板外部收起")
                tipRow(icon: "plus.circle", text: "双击日期框空白处或点右下角 ＋ 添加事项，回车保存")
                tipRow(icon: "checkmark.circle", text: "点击事项右侧圆点标记完成，再次点击恢复未完成")
                tipRow(icon: "pencil", text: "双击事项编辑，右键可完成或删除；删除后 6 秒内可撤销")
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.neutralIcon)
                .frame(width: 16, alignment: .center)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutCard: some View {
        SettingsCard(title: "关于") {
            VStack(alignment: .leading, spacing: 6) {
                Text("MemoBar · 菜单栏备忘录")
                    .font(.system(size: 13, weight: .medium))
                Text("按月展示每日事项，所有数据只保存在本机，不联网、不需要登录。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("版本 \(appVersion) · 支持 macOS 13 及以上")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var quitButton: some View {
        HStack {
            Button("退出 MemoBar") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut("q", modifiers: [.command])

            Spacer()

            Text("退出后菜单栏图标消失，数据仍会保留。")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 2)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func revealDataFolder() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: store.dataDirectoryURL, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: store.dataFileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([store.dataFileURL])
        } else {
            NSWorkspace.shared.open(store.dataDirectoryURL)
        }
    }
}
