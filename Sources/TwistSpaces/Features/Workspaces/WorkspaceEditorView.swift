import SwiftUI

struct WorkspaceEditorView: View {
    @ObservedObject var model: WorkspaceViewModel
    // The editor retains its draft through dismissal; clearing the sheet never unwraps a nil binding.
    @ObservedObject var draft: WorkspaceDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text(draft.original == nil ? "workspace.new" : "workspace.edit")).font(.title2.bold())
            TextField(L10n.text("workspace.name"), text: $draft.name).textFieldStyle(.roundedBorder)
            ApplicationPickerView(titleKey: "applications.left", applications: model.applications, selection: $draft.leftApplication) {
                model.chooseApplication(for: draft, left: true)
            }
            ApplicationPickerView(titleKey: "applications.right", applications: model.applications, selection: $draft.rightApplication) {
                model.chooseApplication(for: draft, left: false)
            }
            HStack {
                TextField(L10n.text("applications.projectNote"), text: $draft.projectPath).textFieldStyle(.roundedBorder)
                Button(L10n.text("workspace.chooseFolder")) { model.chooseProject(for: draft) }
            }
            if let error = draft.error {
                Text(verbatim: error).font(.callout).foregroundStyle(.red)
            }
            HStack {
                Button(L10n.text("applications.refresh")) { model.refreshApplications() }
                Spacer()
                Button(L10n.text("workspace.cancel")) { model.dismissEditor() }.keyboardShortcut(.cancelAction)
                Button(L10n.text("workspace.save")) { model.saveDraft(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.canSave || !model.canSave)
            }
        }
        .padding(24)
        .frame(width: 520)
        .disabled(model.isBusy)
    }
}
