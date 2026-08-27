import AppKit

@MainActor
enum ReportClipboard {
    static func copy(_ report: String, to pasteboard: NSPasteboard = .general) -> Bool {
        // Do not clear the user's clipboard when there is no report to copy.
        guard !report.isEmpty else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(report, forType: .string)
    }
}
