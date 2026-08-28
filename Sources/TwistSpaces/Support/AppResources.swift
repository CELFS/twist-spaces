import Foundation

enum AppResources {
    static let bundle: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.url(forResource: "TwistSpaces_TwistSpaces", withExtension: "bundle"),
                  let bundle = Bundle(url: url) else {
                preconditionFailure("The app's resource bundle is missing. Rebuild the app.")
            }
            return bundle
        }
        // Direct SwiftPM execution uses its generated resource accessor.
        return Bundle.module
    }()
}
