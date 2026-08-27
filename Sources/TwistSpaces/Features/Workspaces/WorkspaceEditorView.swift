import SwiftUI

struct WorkspaceEditorView: View {
    @ObservedObject var model: WorkspaceViewModel
    @Binding var draft: WorkspaceDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text(draft.original == nil ? "workspace.new" : "workspace.edit")).font(.title2.bold())
            TextField(L10n.text("workspace.name"), text: $draft.name)
            HStack {
                TextField(L10n.text("workspace.projectFolder"), text: $draft.projectPath)
                Button(L10n.text("workspace.chooseFolder")) { model.chooseProject() }
            }
            Text(L10n.text("workspace.selectPairHelp")).font(.callout).foregroundStyle(.secondary)
            WorkspaceWindowPicker(titleKey: "workspace.leftWindow", windows: model.windows, selection: $draft.leftToken, saved: draft.original?.left)
            WorkspaceWindowPicker(titleKey: "workspace.rightWindow", windows: model.windows, selection: $draft.rightToken, saved: draft.original?.right)
            Toggle(L10n.text("workspace.confirmPair"), isOn: $draft.confirmedPair)
            HStack {
                Button(L10n.text("workspace.refreshWindows")) { Task { await model.refreshWindows() } }
                if model.isBusy { ProgressView().controlSize(.small) }
                Spacer()
                Text(String(format: L10n.text("workspace.windowCount"), model.windows.count)).foregroundStyle(.secondary)
            }
            if !model.accessibilityTrusted {
                Button(L10n.text("permission.request")) { model.requestPermission() }
            }
            ForEach(Array(model.scanIssues.enumerated()), id: \.offset) { _, issue in
                Text(verbatim: issue).font(.caption).foregroundStyle(.orange)
            }
            Text(L10n.text("workspace.identityHelp")).font(.caption).foregroundStyle(.secondary)
            Divider()
            Label(L10n.text("workspace.nativeLayout"), systemImage: "rectangle.split.2x1")
            Text(L10n.text("workspace.openBoundary")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L10n.text("workspace.cancel")) { model.draft = nil }.keyboardShortcut(.cancelAction)
                Button(L10n.text("workspace.save")) { model.saveDraft() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.confirmedPair || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.projectPath.hasPrefix("/") || !model.canSave)
            }
        }
        .padding(24)
        .frame(width: 520)
        .disabled(model.isBusy)
        .onChange(of: draft.leftToken) { draft.confirmedPair = false }
        .onChange(of: draft.rightToken) { draft.confirmedPair = false }
        .onChange(of: draft.projectPath) { draft.confirmedPair = false }
    }
}

struct WorkspaceWindowPicker: View {
    let titleKey: String
    let windows: [WorkspaceWindow]
    @Binding var selection: Int?
    let saved: SavedWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(L10n.text(titleKey), selection: $selection) {
                Text(L10n.text(saved == nil ? "workspace.chooseWindow" : "workspace.keepSavedWindow")).tag(nil as Int?)
                ForEach(windows) { window in
                    Text(verbatim: "\(window.saved.applicationName) · \(window.saved.title.isEmpty ? L10n.text("workspace.untitledWindow") : window.saved.title) · #\(window.id)")
                        .tag(Optional(window.id))
                }
            }
            if selection == nil, let saved {
                Text(verbatim: "\(saved.applicationName) · \(saved.title)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
