import SwiftUI

struct ControlTitlebarActions: View {
    let showPanel: () -> Void
    @ObservedObject private var language = LanguageSettings.shared
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            GitHubLink().frame(width: 40, height: 28)
            ShowPanelButton(title: L10n.text("control.showPanel", language: language.selection), action: showPanel)
                .frame(width: 40, height: 28)
                .background(Color.primary.opacity(hovered ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 6))
                .appControlHover($hovered)
                .animation(.easeInOut(duration: 0.12), value: hovered)
        }
    }
}
