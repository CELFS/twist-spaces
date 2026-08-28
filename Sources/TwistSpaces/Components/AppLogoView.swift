import AppKit
import SwiftUI

struct AppLogoView: View {
    var size: CGFloat = 24
    var monochrome = false

    private static let colorImage = loadImage("AppLogo")
    private static let monochromeImage = loadImage("AppLogoWhiteMask")

    private static func loadImage(_ name: String) -> NSImage {
        guard let url = AppResources.bundle.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("The app's logo resource is missing. Rebuild the app.")
        }
        return image
    }

    var body: some View {
        Group {
            if monochrome {
                // The generated source has luminance, not alpha: use it as a UI mask,
                // so its black background never appears as a solid template rectangle.
                Color.white.mask {
                    Image(nsImage: Self.monochromeImage)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .contrast(2)
                        .luminanceToAlpha()
                }
            } else {
                Image(nsImage: Self.colorImage)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
