import SwiftUI

struct DiagnosticReportView: View {
    let report: String
    let isInspecting: Bool

    @State private var copyStatus: CopyStatus = .idle

    private enum CopyStatus {
        case idle
        case copied
        case failed
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                if copyStatus == .copied {
                    Text(L10n.text("diagnostics.copied"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if copyStatus == .failed {
                    Text(L10n.text("diagnostics.copyFailed"))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button {
                    // Copy the complete report, independent of selection or scroll position.
                    copyStatus = ReportClipboard.copy(report) ? .copied : .failed
                } label: {
                    Image(systemName: copyStatus == .copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(L10n.text("diagnostics.copy"))
                .accessibilityLabel(L10n.text("diagnostics.copy"))
                .disabled(report.isEmpty || isInspecting)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            ScrollView([.vertical, .horizontal]) {
                Text(verbatim: report.isEmpty ? L10n.text("diagnostics.empty") : report)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
        }
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: report) { _, _ in
            copyStatus = .idle
        }
    }
}
