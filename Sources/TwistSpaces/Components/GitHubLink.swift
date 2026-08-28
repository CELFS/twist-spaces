import SwiftUI

struct GitHubLink: View {
    static let repositoryURL = URL(string: "https://github.com/CELFS/twist-spaces")!
    static let repositoryAddress = "github.com/CELFS/twist-spaces"
    var showsAddress = false
    @ObservedObject private var language = LanguageSettings.shared

    var body: some View {
        Link(destination: Self.repositoryURL) {
            HStack(spacing: 6) {
                GitHubMark().frame(width: 16, height: 16)
                if showsAddress {
                    Text(verbatim: Self.repositoryAddress)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AppTextButtonStyle())
        .help(L10n.text("about.github", language: language.selection))
        .accessibilityLabel(L10n.text("about.github", language: language.selection))
    }
}
