import AppKit
import Foundation

@main
@MainActor
enum TwistSpacesMain {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())

        if arguments.isEmpty {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.setActivationPolicy(.regular)
            app.delegate = delegate
            withExtendedLifetime(delegate) {
                app.run()
            }
            return
        }

        do {
            switch arguments {
            case ["--help"], ["-h"]:
                print(L10n.text("cli.help"))
            case ["--list-apps"]:
                print(try DiagnosticJSON.string(from: ApplicationCatalog.runningApplications()))
            default:
                guard arguments.count == 2,
                      arguments[0] == "--inspect",
                      let pid = Int32(arguments[1]), pid > 0 else {
                    FileHandle.standardError.write(Data((L10n.text("cli.help") + "\n").utf8))
                    exit(64)
                }
                guard let app = ApplicationCatalog.runningApplications().first(where: { $0.pid == pid }) else {
                    FileHandle.standardError.write(Data((L10n.text("diagnostics.appUnavailable") + "\n").utf8))
                    exit(1)
                }
                let report = await WindowInspector().inspect(app)
                print(try DiagnosticJSON.string(from: report))
                // A permission-blocked scan is not a successful window inspection.
                if !report.accessibilityTrusted {
                    exit(2)
                }
                if report.windowsErrorCode != nil {
                    exit(1)
                }
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}
