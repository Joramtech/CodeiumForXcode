import ChatGPTChatTab
import ChatService
import ChatTab
import Foundation
import PromptToCodeService
import SuggestionModel
import SuggestionWidget
import XcodeInspector

#if canImport(ProChatTabs)
import ProChatTabs

enum ChatTabFactory {
    static var chatTabBuilderCollection: [ChatTabBuilderCollection] {
        func folderIfNeeded(
            _ builders: [any ChatTabBuilder],
            title: String
        ) -> ChatTabBuilderCollection? {
            if builders.count > 1 {
                return .folder(title: title, kinds: builders.map(ChatTabKind.init))
            }
            if let first = builders.first { return .kind(ChatTabKind(first)) }
            return nil
        }

        let collection = [
            folderIfNeeded(ChatGPTChatTab.chatBuilders(), title: ChatGPTChatTab.name),
            folderIfNeeded(BrowserChatTab.chatBuilders(externalDependency: .init(
                getEditorContent: {
                    guard let editor = XcodeInspector.shared.focusedEditor else {
                        return .init(selectedText: "", language: "", fileContent: "")
                    }
                    let content = editor.content
                    return .init(
                        selectedText: content.selectedContent,
                        language: languageIdentifierFromFileURL(
                            XcodeInspector.shared
                                .activeDocumentURL
                        )
                        .rawValue,
                        fileContent: content.content
                    )
                },
                handleCustomCommand: { command, prompt in
                    switch command.feature {
                    case let .chatWithSelection(extraSystemPrompt, _, useExtraSystemPrompt):
                        let service = ChatService()
                        return try await service.processMessage(
                            systemPrompt: nil,
                            extraSystemPrompt: (useExtraSystemPrompt ?? false) ? extraSystemPrompt :
                                nil,
                            prompt: prompt
                        )
                    case let .customChat(systemPrompt, _):
                        let service = ChatService()
                        return try await service.processMessage(
                            systemPrompt: systemPrompt,
                            extraSystemPrompt: nil,
                            prompt: prompt
                        )
                    case let .singleRoundDialog(
                        systemPrompt,
                        overwriteSystemPrompt,
                        _,
                        _
                    ):
                        let service = ChatService()
                        return try await service.handleSingleRoundDialogCommand(
                            systemPrompt: systemPrompt,
                            overwriteSystemPrompt: overwriteSystemPrompt ?? false,
                            prompt: prompt
                        )
                    case let .promptToCode(extraSystemPrompt, instruction, _, _):
                        let service = PromptToCodeService(
                            code: prompt,
                            selectionRange: .outOfScope,
                            language: .plaintext,
                            identSize: 4,
                            usesTabsForIndentation: true,
                            projectRootURL: .init(fileURLWithPath: "/"),
                            fileURL: .init(fileURLWithPath: "/"),
                            allCode: prompt,
                            extraSystemPrompt: extraSystemPrompt,
                            generateDescriptionRequirement: false
                        )
                        try await service.modifyCode(prompt: instruction ?? "Modify content.")
                        return service.code
                    }
                }
            )), title: BrowserChatTab.name),
        ].compactMap { $0 }

        return collection
    }
}

#else

enum ChatTabFactory {
    static var chatTabBuilderCollection: [ChatTabBuilderCollection] {
        func folderIfNeeded(
            _ builders: [any ChatTabBuilder],
            title: String
        ) -> ChatTabBuilderCollection? {
            if builders.count > 1 {
                return .folder(title: title, kinds: builders.map(ChatTabKind.init))
            }
            if let first = builders.first { return .kind(ChatTabKind(first)) }
            return nil
        }

        return [
            folderIfNeeded(ChatGPTChatTab.chatBuilders(), title: ChatGPTChatTab.name),
        ].compactMap { $0 }
    }
}

#endif

