import SwiftUI

struct DiagnosticsView: View {
    @StateObject private var model = DiagnosticsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("diagnostics.title"))
                .font(.title2.bold())
            Text(L10n.text("diagnostics.description"))
                .foregroundStyle(.secondary)

            HStack {
                Label(
                    L10n.text(model.accessibilityTrusted ? "permission.granted" : "permission.required"),
                    systemImage: model.accessibilityTrusted ? "checkmark.shield" : "lock.shield"
                )
                Spacer()
                Button(L10n.text("permission.request")) {
                    model.requestPermission()
                }
                .disabled(model.accessibilityTrusted || model.isInspecting)
                Button(L10n.text("diagnostics.refresh")) {
                    model.refresh()
                }
                .disabled(model.isInspecting)
            }

            HStack {
                Picker(L10n.text("diagnostics.application"), selection: $model.selectedPID) {
                    Text(L10n.text("diagnostics.chooseApplication"))
                        .tag(nil as Int32?)
                    ForEach(model.applications) { app in
                        Text(verbatim: "\(app.name) · \(app.bundleIdentifier ?? String(app.pid)) · \(app.pid)")
                            .tag(Optional(app.pid))
                    }
                }
                .disabled(model.isInspecting)
                Button(L10n.text("diagnostics.inspect")) {
                    Task { await model.inspect() }
                }
                .disabled(model.selectedPID == nil || !model.accessibilityTrusted || model.isInspecting)
                if model.isInspecting {
                    ProgressView().controlSize(.small)
                }
            }

            ScrollView([.vertical, .horizontal]) {
                Text(verbatim: model.report.isEmpty ? L10n.text("diagnostics.empty") : model.report)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))

            Text(L10n.text("diagnostics.boundary"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 480)
        .onAppear { model.refresh() }
    }
}
