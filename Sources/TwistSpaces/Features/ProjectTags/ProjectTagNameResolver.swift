import Foundation

enum ProjectTagNameResolver {
    private static let separators = [" — ", " – ", " - "]
    private static let cursorBundleIdentifier = "com.todesktop.230313mzl4w4u92"
    private static let genericNames = [
        "cursor", "codex", "chatgpt", "new window", "untitled", "welcome"
    ]
    private static let cursorSourceControlStates = [
        "added", "conflict", "conflicted", "copied", "deleted", "ignored", "index modified",
        "modified", "renamed", "staged", "untracked", "working tree modified"
    ]

    static func projectName(windowTitle: String, applicationName: String,
                            bundleIdentifier: String = "") -> String? {
        var title = cleaned(windowTitle)
        guard !title.isEmpty else { return nil }
        for separator in separators where title.contains(separator) {
            var components = title.components(separatedBy: separator).map(cleaned).filter { !$0.isEmpty }
            while let last = components.last,
                  isApplicationName(last, applicationName: applicationName)
                    || bundleIdentifier == cursorBundleIdentifier
                        && cursorSourceControlStates.contains(last.lowercased()) {
                components.removeLast()
            }
            if let project = components.last { title = project }
            break
        }
        guard !isApplicationName(title, applicationName: applicationName),
              !genericNames.contains(title.lowercased()) else { return nil }
        return title
    }

    private static func cleaned(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "●•"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isApplicationName(_ value: String, applicationName: String) -> Bool {
        value.caseInsensitiveCompare(applicationName) == .orderedSame
            || ["Cursor", "Codex", "ChatGPT"].contains {
                value.caseInsensitiveCompare($0) == .orderedSame
            }
    }
}
