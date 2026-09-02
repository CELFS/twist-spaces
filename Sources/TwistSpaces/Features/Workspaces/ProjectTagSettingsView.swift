import SwiftUI

struct ProjectTagSettingsView: View {
    @ObservedObject var settings: PanelSettings
    @State private var hiddenName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(L10n.text("projectTags.enabled"), isOn: $settings.projectTagsEnabled)
                .appControlHover()
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("projectTags.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(L10n.text("projectTags.hoverEnabled"), isOn: $settings.projectTagHoverEnabled)
                    .appControlHover()
                HStack {
                    TextField(L10n.text("projectTags.hiddenNamePlaceholder"), text: $hiddenName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addHiddenName)
                    Button(L10n.text("projectTags.add"), action: addHiddenName)
                        .disabled(PanelSettings.normalizedProjectTagName(hiddenName).isEmpty)
                }
                if !settings.hiddenProjectTagNames.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(settings.hiddenProjectTagNames, id: \.self) { name in
                                HStack(spacing: 6) {
                                    Text(verbatim: name).lineLimit(1)
                                    Button {
                                        settings.removeHiddenProjectTagName(name)
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                    .buttonStyle(.plain)
                                    .help(L10n.text("projectTags.remove"))
                                    .accessibilityLabel(String(format: L10n.text("projectTags.removeNamed"), name))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.quaternary, in: Capsule())
                            }
                        }
                    }
                    .frame(height: 30)
                }
            }
            .disabled(!settings.projectTagsEnabled)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func addHiddenName() {
        let name = PanelSettings.normalizedProjectTagName(hiddenName)
        guard !name.isEmpty else { return }
        settings.addHiddenProjectTagName(name)
        hiddenName = ""
    }
}
