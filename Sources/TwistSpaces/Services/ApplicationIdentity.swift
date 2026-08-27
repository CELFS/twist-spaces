import Foundation

enum ApplicationIdentity {
    static func displayName(primary: String, alternateNames: [String], language: AppLanguage? = nil) -> String {
        var names = [primary]
        for candidate in alternateNames {
            let name = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        guard names.count > 1 else { return primary }
        return String(format: L10n.text("applications.nameWithAliases", language: language), primary,
                      names.dropFirst().joined(separator: L10n.text("applications.aliasSeparator", language: language)))
    }

    static func read(at url: URL, runningName: String? = nil) -> SavedApplication? {
        guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier, !identifier.isEmpty else { return nil }
        let primary = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? runningName ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let alternates = bundle.object(forInfoDictionaryKey: "CFBundleAlternateNames") as? [String] ?? []
        return SavedApplication(name: displayName(primary: primary, alternateNames: alternates),
                                bundleIdentifier: identifier, bundlePath: url.standardizedFileURL.path)
    }
}
