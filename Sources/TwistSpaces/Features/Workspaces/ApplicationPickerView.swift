import SwiftUI

struct ApplicationPickerView: View {
    let titleKey: String
    let applications: [SavedApplication]
    @Binding var selection: SavedApplication?
    let browse: () -> Void

    var body: some View {
        HStack {
            Picker(L10n.text(titleKey), selection: $selection) {
                Text(L10n.text("applications.select")).tag(nil as SavedApplication?)
                ForEach(applications) { application in
                    Text(verbatim: application.name).tag(Optional(application))
                }
            }
            Button(L10n.text("applications.browse"), action: browse)
        }
    }
}
