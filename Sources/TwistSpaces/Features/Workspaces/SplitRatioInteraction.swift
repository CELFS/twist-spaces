import Foundation

enum SplitRatioInteraction {
    static let inset = 5.0
    static let dividerWidth = 2.0

    static func contentWidth(in width: Double) -> Double {
        max(0, width - inset * 2 - dividerWidth)
    }

    static func dividerPosition(percentage: Double, width: Double) -> Double {
        inset + contentWidth(in: width) * percentage / 100 + dividerWidth / 2
    }

    static func draggedPercentage(start: Double, translation: Double, width: Double) -> Double {
        let contentWidth = contentWidth(in: width)
        guard contentWidth > 0 else { return start }
        return steppedPercentage(start + translation / contentWidth * 100)
    }

    static func steppedPercentage(_ percentage: Double) -> Double {
        min(90, max(10, (percentage / 5).rounded() * 5))
    }
}
