import SwiftUI

@MainActor
final class WidgetViewModel: ObservableObject {
    enum Position {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    var position: Position
    @Published var isProcessing: Bool

    init(position: Position = .topRight, isProcessing: Bool = false) {
        self.position = position
        self.isProcessing = isProcessing
    }
}

struct WidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var panelViewModel: SuggestionPanelViewModel
    @State var isHovering: Bool = false
    @State var processingProgress: Double = 0

    var body: some View {
        Circle().fill(isHovering ? .white.opacity(0.8) : .white.opacity(0.3))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    panelViewModel.isPanelDisplayed.toggle()
                }
            }
            .overlay {
                let minimumLineWidth: Double = 4
                let lineWidth = (1 - processingProgress) * 28 + minimumLineWidth
                let scale = max(processingProgress * 1, 0.0001)

                ZStack {
                    Circle()
                        .stroke(
                            Color(nsColor: .darkGray),
                            style: .init(lineWidth: minimumLineWidth)
                        )
                        .padding(2)

                    #warning("TODO: Tweak the animation")
                    // how do I stop the repeatForever animation without removing the view?
                    // I tried many solutions found on stackoverflow but non of them works.
                    if viewModel.isProcessing {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(
                                !panelViewModel.suggestion.isEmpty || viewModel.isProcessing ? 1 : 0
                            )
                            .animation(
                                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: processingProgress
                            )
                    } else {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(
                                !panelViewModel.suggestion.isEmpty || viewModel.isProcessing ? 1 : 0
                            )
                            .animation(.easeInOut(duration: 1), value: processingProgress)
                    }
                }
            }
            .onChange(of: viewModel.isProcessing) { isProcessing in
                Task {
                    await Task.yield()
                    if isProcessing {
                        processingProgress = 1 - processingProgress
                    } else {
                        processingProgress = panelViewModel.suggestion.isEmpty ? 0 : 1
                    }
                }
            }
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }
    }
}

struct WidgetView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: false),
                panelViewModel: .init(),
                isHovering: false
            )

            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: false),
                panelViewModel: .init(),
                isHovering: true
            )

            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: true),
                panelViewModel: .init(),
                isHovering: false
            )

            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: false),
                panelViewModel: .init(suggestion: ["Hello"]),
                isHovering: false
            )
        }
        .frame(width: 30)
        .background(Color.black)
    }
}