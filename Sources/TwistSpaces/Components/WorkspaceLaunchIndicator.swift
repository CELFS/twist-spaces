import SwiftUI

struct WorkspaceLaunchIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotates = false
    @State private var breathes = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.22), .purple.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 48
                    )
                )
                .scaleEffect(breathes ? 1.14 : 0.92)
            Circle()
                .trim(from: 0.06, to: 0.78)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .purple, .pink, .orange, .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(rotates ? 360 : 0))
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
                .padding(8)
            AppLogoView(size: 54)
                .scaleEffect(breathes ? 1.04 : 0.97)
                .shadow(color: .purple.opacity(0.38), radius: 12)
        }
        .frame(width: 92, height: 92)
        .onAppear(perform: startAnimation)
        .onChange(of: reduceMotion) { _, _ in startAnimation() }
        .accessibilityHidden(true)
    }

    private func startAnimation() {
        rotates = false
        breathes = false
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            rotates = true
        }
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
            breathes = true
        }
    }
}
