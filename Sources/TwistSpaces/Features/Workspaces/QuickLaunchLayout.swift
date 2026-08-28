import Foundation

enum QuickLaunchLayout {
    static let spacing = 8.0

    static func columnCount(width: Double, showNames: Bool) -> Int {
        guard width.isFinite else { return 1 }
        let minimumWidth = showNames ? 88.0 : 52.0
        return max(1, Int((max(0, width) + spacing) / (minimumWidth + spacing)))
    }

    static func displayedApplications(_ applications: [SavedApplication], width: Double, showNames: Bool,
                                      expanded: Bool) -> [SavedApplication] {
        expanded ? applications : Array(applications.prefix(columnCount(width: width, showNames: showNames)))
    }
}
