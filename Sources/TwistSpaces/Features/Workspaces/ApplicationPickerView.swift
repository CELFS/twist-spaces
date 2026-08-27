import SwiftUI

struct ApplicationPickerView: View {
    let titleKey: String
    let applications: [SavedApplication]
    @Binding var selection: SavedApplication?
    let browse: () -> Void

    var body: some View {
        HStack {
            AppPicker(titleKey: titleKey, selection: Binding<String?>(
                get: { selection?.id },
                set: { id in selection = applications.first { $0.id == id } }
            )) {
                Text(L10n.text("applications.select")).tag(nil as String?)
                ForEach(applications) { application in
                    Text(verbatim: application.name).tag(Optional(application.id))
                }
            }
            Button(L10n.text("applications.browse"), action: browse)
        }
    }
}
