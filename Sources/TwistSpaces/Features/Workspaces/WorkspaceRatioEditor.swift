import AppKit
import SwiftUI

struct WorkspaceRatioEditor: View {
    @ObservedObject var draft: WorkspaceDraft
    @State private var dragStartPercentage: Double?
    @State private var dividerHovered = false
    @FocusState private var dividerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("workspace.ratio"))
                Spacer()
                Text(String(format: L10n.text("workspace.ratioValue"), Int(draft.leftPercentage), 100 - Int(draft.leftPercentage)))
                    .foregroundStyle(.secondary)
            }
            SplitScreenPreview(leftPercentage: draft.leftPercentage, leftApplication: draft.leftApplication,
                               rightApplication: draft.rightApplication, showsDividerHandle: true,
                               dividerHovered: dividerHovered, dividerDragging: dragStartPercentage != nil)
                .overlay {
                    GeometryReader { geometry in
                        Color.clear
                            .frame(width: 28, height: geometry.size.height)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active:
                                    dividerHovered = true
                                case .ended:
                                    dividerHovered = false
                                }
                                updateDividerCursor()
                            }
                            .position(x: SplitRatioInteraction.dividerPosition(percentage: draft.leftPercentage, width: geometry.size.width),
                                      y: geometry.size.height / 2)
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("splitRatioPreview"))
                                .onChanged { value in
                                    dividerFocused = true
                                    if dragStartPercentage == nil { dragStartPercentage = draft.leftPercentage }
                                    updateDividerCursor()
                                    guard let start = dragStartPercentage else { return }
                                    // Use translation from the original ratio so the moving divider does not feed back into the drag.
                                    draft.leftPercentage = SplitRatioInteraction.draggedPercentage(start: start,
                                        translation: value.translation.width, width: geometry.size.width)
                                }
                                .onEnded { _ in
                                    dragStartPercentage = nil
                                    updateDividerCursor()
                                })
                    }
                }
                .coordinateSpace(name: "splitRatioPreview")
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(width: 360, height: 202.5)
                .focusable()
                .focused($dividerFocused)
                .onKeyPress(.leftArrow) { adjust(by: -5); return .handled }
                .onKeyPress(.rightArrow) { adjust(by: 5); return .handled }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.text("workspace.ratio"))
                .accessibilityValue(String(format: L10n.text("workspace.ratioValue"), Int(draft.leftPercentage), 100 - Int(draft.leftPercentage)))
                .accessibilityHint(L10n.text("workspace.ratioDragHint"))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: adjust(by: 5)
                    case .decrement: adjust(by: -5)
                    @unknown default: break
                    }
                }
                .frame(maxWidth: .infinity)
            Text(L10n.text("workspace.ratioDragHint")).font(.caption).foregroundStyle(.secondary)
            Text(L10n.text("workspace.ratioNotApplied")).font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear {
            if dividerHovered || dragStartPercentage != nil { NSCursor.arrow.set() }
            dividerHovered = false
            dragStartPercentage = nil
        }
    }

    private func updateDividerCursor() {
        if dragStartPercentage != nil { NSCursor.closedHand.set() }
        else if dividerHovered { NSCursor.openHand.set() }
        else { NSCursor.arrow.set() }
    }

    private func adjust(by amount: Double) {
        draft.leftPercentage = SplitRatioInteraction.steppedPercentage(draft.leftPercentage + amount)
    }
}
