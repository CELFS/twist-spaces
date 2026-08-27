import Foundation

struct MatchedWindow: Equatable, Sendable {
    let applicationName: String
    let title: String
    let isFullscreen: Bool

    var message: String {
        let name = title.isEmpty || title == applicationName
            ? applicationName
            : String(format: L10n.text("launch.windowWithTitle"), applicationName, title)
        return String(format: L10n.text("launch.windowMatched"), name)
    }
}

enum MatchedWindowLayout: Equatable {
    case preserved
    case failed(String)

    var message: String {
        switch self {
        case .preserved: L10n.text("launch.fullscreenPreserved")
        case .failed(let reason): reason
        }
    }
}
