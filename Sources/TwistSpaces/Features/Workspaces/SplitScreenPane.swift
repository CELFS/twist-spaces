import AppKit
import SwiftUI

struct SplitScreenPane: View {
    let application: SavedApplication?
    let percentage: Int
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 5) {
                if let application {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: application.bundlePath))
                        .resizable().scaledToFit().frame(width: 28, height: 28)
                } else {
                    Image(systemName: "macwindow")
                        .resizable().scaledToFit().foregroundStyle(tint).frame(width: 24, height: 28)
                }
                Text(Double(percentage) / 100, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 11, weight: .medium, design: .rounded)).monospacedDigit()
            }
            .fixedSize()
            .scaleEffect(min(1, geometry.size.width / 40, geometry.size.height / 64))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(tint.opacity(0.12).gradient)
        .clipped()
    }
}
