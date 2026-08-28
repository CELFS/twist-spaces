import SwiftUI

enum WorkspaceControlTab: Hashable, CaseIterable {
    case combinations, quickLaunch, display, language, about

    var titleKey: String {
        switch self {
        case .combinations: "control.combinations"
        case .quickLaunch: "quickLaunch.title"
        case .display: "control.display"
        case .language: "language.title"
        case .about: "about.title"
        }
    }

    var symbol: String {
        switch self {
        case .combinations: "rectangle.split.2x1"
        case .quickLaunch: "bolt"
        case .display: "slider.horizontal.3"
        case .language: "globe"
        case .about: "info.circle"
        }
    }
}

struct WorkspaceControlSidebar: View {
    @Binding var selection: WorkspaceControlTab
    let showPanel: () -> Void
    @FocusState private var focusedTab: WorkspaceControlTab?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                WorkspaceControlNavigationButton(titleKey: "control.layoutPanel", symbol: "sidebar.right",
                                                 isSelected: false, showsArrow: true, action: showPanel)
                ForEach([WorkspaceControlTab.combinations, .quickLaunch], id: \.self) { tab in
                    WorkspaceControlNavigationButton(titleKey: tab.titleKey, symbol: tab.symbol, isSelected: selection == tab) {
                        selection = tab
                        focusedTab = tab
                    }
                    .focused($focusedTab, equals: tab)
                }
            }
            Spacer(minLength: 24)
            VStack(spacing: 0) {
                ForEach([WorkspaceControlTab.display, .language, .about], id: \.self) { tab in
                    WorkspaceControlNavigationButton(titleKey: tab.titleKey, symbol: tab.symbol, isSelected: selection == tab) {
                        selection = tab
                        focusedTab = tab
                    }
                    .focused($focusedTab, equals: tab)
                }
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity)
        .background(.bar)
        .frame(width: 180)
        .onMoveCommand { direction in
            guard let focusedTab, let index = WorkspaceControlTab.allCases.firstIndex(of: focusedTab) else { return }
            let offset: Int
            switch direction {
            case .up: offset = -1
            case .down: offset = 1
            default: return
            }
            let nextIndex = index + offset
            guard WorkspaceControlTab.allCases.indices.contains(nextIndex) else { return }
            let tab = WorkspaceControlTab.allCases[nextIndex]
            selection = tab
            self.focusedTab = tab
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("control.title"))
    }
}
