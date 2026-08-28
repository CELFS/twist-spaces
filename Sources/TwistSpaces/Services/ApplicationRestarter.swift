import AppKit
import Combine

@MainActor
final class ApplicationRestarter: NSObject, ObservableObject {
    static let shared = ApplicationRestarter()
    @Published private(set) var isRestarting = false

    private let scheduleRelaunch: () throws -> Void
    private let terminate: () -> Void
    private let reportError: (Error) -> Void

    init(scheduleRelaunch: @escaping () throws -> Void = { try ApplicationRestarter.scheduleRelaunch() },
         terminate: @escaping () -> Void = { NSApplication.shared.terminate(nil) },
         reportError: @escaping (Error) -> Void = { error in
             let alert = NSAlert()
             alert.messageText = L10n.text("restart.failed")
             alert.informativeText = error.localizedDescription
             alert.alertStyle = .warning
             alert.runModal()
         }) {
        self.scheduleRelaunch = scheduleRelaunch
        self.terminate = terminate
        self.reportError = reportError
        super.init()
    }

    @objc func restart(_ sender: Any?) {
        guard !isRestarting else { return }
        isRestarting = true
        do {
            try scheduleRelaunch()
            terminate()
        } catch {
            isRestarting = false
            reportError(error)
        }
    }

    static func scheduleRelaunch(applicationURL: URL = Bundle.main.bundleURL) throws {
        guard applicationURL.pathExtension == "app",
              let executable = Bundle(url: applicationURL)?.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw RestartError.unavailableApplication
        }
        try makeRelaunchProcess(applicationURL: applicationURL,
                              processIdentifier: ProcessInfo.processInfo.processIdentifier).run()
    }

    static func makeRelaunchProcess(applicationURL: URL, processIdentifier: Int32,
                                   openerURL: URL = URL(fileURLWithPath: "/usr/bin/open")) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait for the old process to exit, rather than racing a fixed-delay launch.
        // Pass paths as positional arguments so spaces and shell characters stay literal.
        process.arguments = ["-c", """
        attempts=0
        while /bin/kill -0 "$1" 2>/dev/null; do
            attempts=$((attempts + 1))
            [ "$attempts" -lt 100 ] || exit 1
            /bin/sleep 0.1
        done
        exec "$3" -n "$2"
        """, "twist-spaces-restart", String(processIdentifier), applicationURL.path, openerURL.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return process
    }
}

private enum RestartError: LocalizedError {
    case unavailableApplication

    var errorDescription: String? { L10n.text("restart.unavailableApplication") }
}
