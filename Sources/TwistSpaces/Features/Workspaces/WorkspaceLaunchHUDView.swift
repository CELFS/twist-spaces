import SwiftUI

struct WorkspaceLaunchHUDView: View {
    let progress: WorkspaceLaunchProgress?
    @ObservedObject private var language = LanguageSettings.shared

    private var currentStage: Int {
        guard let phase = progress?.phase else { return 0 }
        return WorkspaceLaunchPhase.allCases.firstIndex(of: phase) ?? 0
    }

    var body: some View {
        if let progress {
            HStack(spacing: 24) {
                WorkspaceLaunchIndicator()
                VStack(alignment: .leading, spacing: 10) {
                    Text(progress.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(progress.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                    HStack(spacing: 7) {
                        ForEach(Array(WorkspaceLaunchPhase.allCases.enumerated()), id: \.offset) { index, _ in
                            Capsule()
                                .fill(index <= currentStage ? Color.accentColor : Color.secondary.opacity(0.24))
                                .frame(width: index == currentStage ? 30 : 10, height: 6)
                        }
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.76), value: currentStage)
                    .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(width: 460, height: 164)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.65), .purple.opacity(0.72), .pink.opacity(0.58)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
            }
            .shadow(color: .black.opacity(0.28), radius: 28, y: 14)
            .padding(34)
            .id(language.selection)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(progress.title), \(progress.message)")
        }
    }
}
