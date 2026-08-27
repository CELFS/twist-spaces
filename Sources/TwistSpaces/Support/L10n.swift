import Foundation

enum L10n {
    private static let resources: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.url(forResource: "TwistSpaces_TwistSpaces", withExtension: "bundle"),
                  let bundle = Bundle(url: url) else {
                preconditionFailure("The app's localization resource bundle is missing. Rebuild the app.")
            }
            return bundle
        }
        // Direct SwiftPM execution uses its generated resource accessor.
        return Bundle.module
    }()

    static func text(_ key: String) -> String {
        // Standard bundle localization; an unknown key stays visible as the key.
        resources.localizedString(forKey: key, value: nil, table: nil)
    }
}
