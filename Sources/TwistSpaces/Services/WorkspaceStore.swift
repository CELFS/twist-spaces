import Foundation

struct WorkspaceStore {
    let url: URL

    static var standard: WorkspaceStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Twist Spaces", isDirectory: true)
        return WorkspaceStore(url: directory.appendingPathComponent("workspaces.json"))
    }

    func load() throws -> WorkspaceLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return WorkspaceLibrary() }
        let library = try JSONDecoder().decode(WorkspaceLibrary.self, from: Data(contentsOf: url))
        try library.validate()
        return library
    }

    func save(_ library: WorkspaceLibrary) throws {
        try library.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Commit a complete file atomically. The caller only updates UI state after a successful write.
        try data.write(to: url, options: .atomic)
    }
}
