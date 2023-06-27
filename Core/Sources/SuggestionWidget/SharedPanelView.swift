import Environment
import Preferences
import SwiftUI

@MainActor
final class SharedPanelViewModel: ObservableObject {
    enum Content {
        case suggestion(SuggestionProvider)
        case promptToCode(PromptToCodeProvider)
        case error(String)

        var contentHash: String {
            switch self {
            case let .error(e):
                return "error: \(e)"
            case let .suggestion(provider):
                return "suggestion: \(provider.code.hashValue)"
            case let .promptToCode(provider):
                return "provider: \(provider.id)"
            }
        }
    }

    @Published var content: Content?
    @Published var colorScheme: ColorScheme

    init(
        content: Content? = nil,
        colorScheme: ColorScheme = .dark
    ) {
        self.content = content
        self.colorScheme = colorScheme
    }
}

@MainActor
final class SharedPanelDisplayController: ObservableObject {
    @Published var alignTopToAnchor = false
    @Published var isPanelDisplayed: Bool = false

    init(
        alignTopToAnchor: Bool = false,
        isPanelDisplayed: Bool = false
    ) {
        self.alignTopToAnchor = alignTopToAnchor
        self.isPanelDisplayed = isPanelDisplayed
    }
}

extension View {
    @ViewBuilder
    func animation<V: Equatable>(
        featureFlag: KeyPath<UserDefaultPreferenceKeys, FeatureFlag>,
        _ animation: Animation?,
        value: V
    ) -> some View {
        let isOn = UserDefaults.shared.value(for: featureFlag)
        if isOn {
            self.animation(animation, value: value)
        } else {
            self
        }
    }
}

struct SharedPanelView: View {
    @ObservedObject var viewModel: SharedPanelViewModel
    @ObservedObject var displayController: SharedPanelDisplayController
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

    var body: some View {
        VStack(spacing: 0) {
            if !displayController.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            VStack {
                if let content = viewModel.content {
                    ZStack(alignment: .topLeading) {
                        switch content {
                        case let .suggestion(suggestion):
                            switch suggestionPresentationMode {
                            case .nearbyTextCursor:
                                EmptyView()
                            case .floatingWidget:
                                CodeBlockSuggestionPanel(suggestion: suggestion)
                            }
                        case let .promptToCode(provider):
                            PromptToCodePanel(provider: provider)
                        case let .error(description):
                            ErrorPanel(
                                viewModel: viewModel,
                                displayController: displayController,
                                description: description
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(displayController.isPanelDisplayed)
                }
            }
            .frame(maxWidth: .infinity)

            if displayController.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(viewModel.colorScheme)
        .opacity({
            guard displayController.isPanelDisplayed else { return 0 }
            guard viewModel.content != nil else { return 0 }
            return 1
        }())
        .animation(
            featureFlag: \.animationACrashSuggestion,
            .easeInOut(duration: 0.2),
            value: viewModel.content?.contentHash
        )
        .animation(
            featureFlag: \.animationBCrashSuggestion,
            .easeInOut(duration: 0.2),
            value: displayController.isPanelDisplayed
        )
        .frame(maxWidth: Style.panelWidth, maxHeight: Style.panelHeight)
    }
}

struct CommandButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

// MARK: - Previews

struct SuggestionPanelView_Error_Preview: PreviewProvider {
    static var previews: some View {
        SharedPanelView(viewModel: .init(
            content: .error("This is an error\nerror")
        ), displayController: .init(isPanelDisplayed: true))
        .frame(width: 450, height: 200)
    }
}

struct SuggestionPanelView_Both_DisplayingSuggestion_Preview: PreviewProvider {
    static var previews: some View {
        SharedPanelView(viewModel: .init(
            content: .suggestion(SuggestionProvider(
                code: """
                - (void)addSubview:(UIView *)view {
                    [self addSubview:view];
                }
                """,
                language: "objective-c",
                startLineIndex: 8,
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            colorScheme: .dark
        ), displayController: .init(isPanelDisplayed: true))
        .frame(width: 450, height: 200)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

