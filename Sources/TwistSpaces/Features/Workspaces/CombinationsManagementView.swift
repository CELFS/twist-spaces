import SwiftUI

struct CombinationsManagementView: View {
    @ObservedObject var model: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("control.combinations")).font(.headline)
                Spacer()
                Button(L10n.text("workspace.new")) { model.newWorkspace() }
                    .disabled(!model.canSave || model.isBusy)
            }
            if model.library.workspaces.isEmpty {
                ContentUnavailableView(L10n.text("control.empty"), systemImage: "rectangle.stack")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.library.workspaces) { workspace in
                            WorkspaceManagementRow(workspace: workspace, model: model)
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}
