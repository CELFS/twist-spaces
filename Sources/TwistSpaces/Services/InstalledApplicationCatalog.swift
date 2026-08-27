import Foundation

enum InstalledApplicationCatalog {
    static var directories: [URL] {
        [URL(fileURLWithPath: "/Applications"),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
         URL(fileURLWithPath: "/System/Applications"),
         URL(fileURLWithPath: "/System/Library/CoreServices/Applications")]
    }

    static func applications(in directories: [URL]) -> [SavedApplication] {
        var applications: [SavedApplication] = []
        var seen = Set<String>()
        for directory in directories {
            guard let files = FileManager.default.enumerator(at: directory,
                includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in files where url.pathExtension.lowercased() == "app" {
                // Application packages are leaves, not directories of independently selectable helpers.
                files.skipDescendants()
                guard (Bundle(url: url)?.object(forInfoDictionaryKey: "LSBackgroundOnly") as? NSNumber)?.boolValue != true,
                      let application = ApplicationIdentity.read(at: url), seen.insert(application.id).inserted else { continue }
                applications.append(application)
            }
        }
        return applications
    }
}
