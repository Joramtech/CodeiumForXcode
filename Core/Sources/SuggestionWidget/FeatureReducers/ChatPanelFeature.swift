import ActiveApplicationMonitor
import AppKit
import ChatTab
import ComposableArchitecture
import SwiftUI

public enum ChatTabBuilderCollection: Equatable {
    case folder(title: String, kinds: [ChatTabKind])
    case kind(ChatTabKind)
}

public struct ChatTabKind: Equatable {
    public var builder: any ChatTabBuilder
    var title: String { builder.title }

    public init(_ builder: any ChatTabBuilder) {
        self.builder = builder
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
    }
}

public struct ChatPanelFeature: ReducerProtocol {
    public struct ChatTabGroup: Equatable {
        public var tabs: [BaseChatTab]
        public var tabInfo: [ChatTabInfo]
        public var tabCollection: [ChatTabBuilderCollection]
        public var selectedTabId: String?

        init(
            tabs: [BaseChatTab] = [],
            tabInfo: [ChatTabInfo] = [],
            tabCollection: [ChatTabBuilderCollection] = [],
            selectedTabId: String? = nil
        ) {
            self.tabs = tabs
            self.tabInfo = tabInfo
            self.tabCollection = tabCollection
            self.selectedTabId = selectedTabId
        }

        public var activeChatTab: BaseChatTab? {
            guard let id = selectedTabId else { return tabs.first }
            guard let tab = tabs.first(where: { $0.id == id }) else { return tabs.first }
            return tab
        }
    }

    public struct State: Equatable {
        public var chatTapGroup = ChatTabGroup()
        var colorScheme: ColorScheme = .light
        var isPanelDisplayed = false
        var chatPanelInASeparateWindow = false
    }

    public enum Action: Equatable {
        // Window
        case hideButtonClicked
        case closeActiveTabClicked
        case toggleChatPanelDetachedButtonClicked
        case detachChatPanel
        case attachChatPanel
        case presentChatPanel(forceDetach: Bool)

        // Tabs
        case updateChatTabInfo([ChatTabInfo])
        case createNewTapButtonHovered
        case closeTabButtonClicked(id: String)
        case createNewTapButtonClicked(kind: ChatTabKind?)
        case tabClicked(id: String)
        case appendAndSelectTab(BaseChatTab)
        case switchToNextTab
        case switchToPreviousTab
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activatePreviouslyActiveXcode) var activatePreviouslyActiveXcode
    @Dependency(\.activateExtensionService) var activateExtensionService
    @Dependency(\.chatTabBuilderCollection) var chatTabBuilderCollection

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .hideButtonClicked:
                state.isPanelDisplayed = false

                return .run { _ in
                    await activatePreviouslyActiveXcode()
                }

            case .closeActiveTabClicked:
                if let id = state.chatTapGroup.selectedTabId {
                    return .run { send in
                        await send(.closeTabButtonClicked(id: id))
                    }
                }

                state.isPanelDisplayed = false
                return .none

            case .toggleChatPanelDetachedButtonClicked:
                state.chatPanelInASeparateWindow.toggle()
                return .none

            case .detachChatPanel:
                state.chatPanelInASeparateWindow = true
                return .none

            case .attachChatPanel:
                state.chatPanelInASeparateWindow = false
                return .none

            case let .presentChatPanel(forceDetach):
                if forceDetach {
                    state.chatPanelInASeparateWindow = true
                }
                state.isPanelDisplayed = true
                return .run { _ in
                    await activateExtensionService()
                }

            case let .updateChatTabInfo(chatTabInfo):
                let previousSelectedIndex = state.chatTapGroup.tabInfo
                    .firstIndex(where: { $0.id == state.chatTapGroup.selectedTabId })
                state.chatTapGroup.tabInfo = chatTabInfo
                if !chatTabInfo.contains(where: { $0.id == state.chatTapGroup.selectedTabId }) {
                    if let previousSelectedIndex {
                        let proposedSelectedIndex = previousSelectedIndex - 1
                        if proposedSelectedIndex >= 0,
                           proposedSelectedIndex < chatTabInfo.endIndex
                        {
                            state.chatTapGroup.selectedTabId = chatTabInfo[proposedSelectedIndex].id
                        } else {
                            state.chatTapGroup.selectedTabId = chatTabInfo.first?.id
                        }
                    } else {
                        state.chatTapGroup.selectedTabId = nil
                    }
                }
                return .none

            case let .closeTabButtonClicked(id):
                state.chatTapGroup.tabs.removeAll { $0.id == id }
                if state.chatTapGroup.tabs.isEmpty {
                    state.isPanelDisplayed = false
                }
                return .none

            case .createNewTapButtonHovered:
                state.chatTapGroup.tabCollection = chatTabBuilderCollection()
                return .none

            case .createNewTapButtonClicked:
                return .none // handled elsewhere

            case let .tabClicked(id):
                guard state.chatTapGroup.tabInfo.contains(where: { $0.id == id }) else {
                    state.chatTapGroup.selectedTabId = nil
                    return .none
                }
                state.chatTapGroup.selectedTabId = id
                return .none

            case let .appendAndSelectTab(tab):
                guard !state.chatTapGroup.tabInfo.contains(where: { $0.id == tab.id })
                else { return .none }
                state.chatTapGroup.tabs.append(tab)
                state.chatTapGroup.selectedTabId = tab.id
                return .none

            case .switchToNextTab:
                let selectedId = state.chatTapGroup.selectedTabId
                guard let index = state.chatTapGroup.tabInfo
                    .firstIndex(where: { $0.id == selectedId })
                else { return .none }
                let nextIndex = index + 1
                if nextIndex >= state.chatTapGroup.tabInfo.endIndex {
                    return .none
                }
                let targetId = state.chatTapGroup.tabInfo[nextIndex].id
                state.chatTapGroup.selectedTabId = targetId
                return .none

            case .switchToPreviousTab:
                let selectedId = state.chatTapGroup.selectedTabId
                guard let index = state.chatTapGroup.tabInfo
                    .firstIndex(where: { $0.id == selectedId })
                else { return .none }
                let previousIndex = index - 1
                if previousIndex < 0 || previousIndex >= state.chatTapGroup.tabInfo.endIndex {
                    return .none
                }
                let targetId = state.chatTapGroup.tabInfo[previousIndex].id
                state.chatTapGroup.selectedTabId = targetId
                return .none
            }
        }
    }
}

