import SwiftUI

struct ProjectTagView: View {
    let projectName: String

    var body: some View {
        Text(verbatim: projectName)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
    }
}
