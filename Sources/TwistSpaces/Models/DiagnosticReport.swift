import Foundation

struct ApplicationSnapshot: Codable, Identifiable, Sendable {
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let bundlePath: String?

    // Process IDs identify only this running session, never a saved project.
    var id: Int32 { pid }
}

struct AttributeObservation: Codable, Sendable {
    let name: String
    let value: String?
    let errorCode: Int32?
}

struct ButtonObservation: Codable, Sendable {
    let attribute: String
    let lookupErrorCode: Int32?
    let actions: [String]?
    let actionsErrorCode: Int32?
}

struct WindowSnapshot: Codable, Sendable {
    // This ordinal is only for reading a single report. It is not a stable window ID.
    let ordinal: Int
    let supportedAttributes: [String]?
    let supportedAttributesErrorCode: Int32?
    let attributes: [AttributeObservation]
    let buttons: [ButtonObservation]
}

struct DiagnosticReport: Codable, Sendable {
    let application: ApplicationSnapshot
    let accessibilityTrusted: Bool
    let windowsErrorCode: Int32?
    let windows: [WindowSnapshot]
}

enum DiagnosticJSON {
    static func string<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
