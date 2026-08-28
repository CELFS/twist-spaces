import SwiftUI

struct AboutView: View {
    private var version: String {
        // The build script writes version.json into the packaged app's Info.plist.
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else {
            preconditionFailure("The app's version is missing. Rebuild and launch the app bundle.")
        }
        return version
    }

    var body: some View {
        SettingsPage {
            AppLogoView(size: 64)
            Text(L10n.text("app.name"))
                .font(.title2.bold())
            HStack {
                Text(L10n.text("about.version"))
                Text(verbatim: version)
            }
            .foregroundStyle(.secondary)
            GitHubLink(showsAddress: true)
            Text(L10n.text("about.copyright"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
