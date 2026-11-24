import Foundation

/// "Launch at login" implemented with a per-user LaunchAgent.
///
/// The agent plist is written to `~/Library/LaunchAgents` and simply points at
/// the app's executable. It is independent of code signing and works for a
/// locally built, unsigned app, which `SMAppService.mainApp` does not reliably
/// do outside of `/Applications`.
enum LaunchAtLogin {
    static let agentLabel = "com.sean.memobar"

    static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    /// Returns an optional human readable warning when the plist was written but
    /// launchd could not be told about it right away.
    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> String? {
        let fileManager = FileManager.default

        if enabled {
            guard let executableURL = Bundle.main.executableURL else {
                throw LaunchAtLoginError.missingExecutable
            }
            try fileManager.createDirectory(
                at: agentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let plist: [String: Any] = [
                "Label": agentLabel,
                "ProgramArguments": [executableURL.path],
                "RunAtLoad": true,
                "KeepAlive": false,
                "LimitLoadToSessionType": "Aqua",
                "ProcessType": "Interactive"
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: agentURL, options: [.atomic])
            return nil
        } else {
            if fileManager.fileExists(atPath: agentURL.path) {
                try fileManager.removeItem(at: agentURL)
            }
            return nil
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case missingExecutable

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "找不到应用可执行文件，无法设置开机启动。"
        }
    }
}
