import Foundation

enum WindowStabilityPolicy {
    static let defaultMinimumAge: TimeInterval = 2.5
    static let minimumAgeRange: ClosedRange<TimeInterval> = 0.5...8
    static let minimumAgeStep: TimeInterval = 0.5

    static func clampedMinimumAge(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return defaultMinimumAge }
        return min(max(value, minimumAgeRange.lowerBound), minimumAgeRange.upperBound)
    }
}
