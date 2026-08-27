import Foundation

struct CursorAccessibilityResult: Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case succeeded
        case failed
        case permissionRequired
        case unsupportedApplication
        case applicationUnavailable
    }

    let attribute: String
    let requestedValue: Bool
    let status: Status
    let errorCode: Int32?
}
