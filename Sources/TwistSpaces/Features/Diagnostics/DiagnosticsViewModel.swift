import AppKit
import Combine

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published private(set) var applications: [ApplicationSnapshot] = []
    @Published var selectedPID: Int32? {
        didSet { report = "" }
    }
    @Published private(set) var accessibilityTrusted = AccessibilityPermission.isTrusted
    @Published private(set) var isInspecting = false
    @Published private(set) var report = ""

    private let inspector = WindowInspector()

    func refresh() {
        applications = ApplicationCatalog.runningApplications()
        accessibilityTrusted = AccessibilityPermission.isTrusted
        if let selectedPID, !applications.contains(where: { $0.pid == selectedPID }) {
            self.selectedPID = nil
        }
    }

    func requestPermission() {
        AccessibilityPermission.requestFromUser()
        // The system prompt is asynchronous. Refresh after changing the setting.
        accessibilityTrusted = AccessibilityPermission.isTrusted
    }

    func inspect() async {
        guard !isInspecting else { return }
        refresh()
        guard let selectedPID,
              let application = applications.first(where: { $0.pid == selectedPID }) else {
            report = L10n.text("diagnostics.appUnavailable")
            return
        }
        isInspecting = true
        report = ""
        defer { isInspecting = false }

        let snapshot = await inspector.inspect(application)
        accessibilityTrusted = snapshot.accessibilityTrusted
        do {
            report = try DiagnosticJSON.string(from: snapshot)
        } catch {
            report = error.localizedDescription
        }
    }
}
