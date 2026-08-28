import Foundation

enum L10n {
    private static let resources = AppResources.bundle

    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        // Standard bundle localization; an unknown key stays visible as the key.
        let selected = language ?? AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app.language") ?? "system") ?? .system
        // SwiftPM normalizes localization directory names (for example, zh-hans.lproj).
        let code = resources.localizations.first { $0.caseInsensitiveCompare(selected.localization) == .orderedSame } ?? selected.localization
        guard let url = resources.resourceURL?.appendingPathComponent("\(code).lproj"),
              let bundle = Bundle(url: url) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
