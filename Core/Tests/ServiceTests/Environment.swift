import AppKit
import Client
import SuggestionModel
import GitHubCopilotService
import Environment
import Foundation
import XCTest
import XPCShared

@testable import Service

@ServiceActor func clearEnvironment() {
    workspaces = [:]

    Environment.now = { Date() }

    Environment.fetchCurrentProjectRootURLFromXcode = { 
        URL(fileURLWithPath: "/path/to/project")
    }

    Environment.fetchCurrentFileURL = {
        URL(fileURLWithPath: "/path/to/project/file.swift")
    }

    Environment.triggerAction = { _ in }
    
    Environment.guessProjectRootURLForFile = { $0 }
}

func completion(text: String, range: CursorRange, uuid: String = "") -> CodeSuggestion {
    .init(text: text, position: range.start, uuid: uuid, range: range, displayText: text)
}

class MockSuggestionService: GitHubCopilotSuggestionServiceType {
    func terminate() async {
        fatalError()
    }
    
    func cancelRequest() async {
        fatalError()
    }
    
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }
    
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }
    
    func notifyCloseTextDocument(fileURL: URL) async throws {
        fatalError()
    }
    
    func notifySaveTextDocument(fileURL: URL) async throws {
        fatalError()
    }
    
    var completions = [CodeSuggestion]()
    var accepted: String?
    var rejected: [String] = []

    init(completions: [CodeSuggestion]) {
        self.completions = completions
    }

    func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool,
        ignoreTrailingNewLinesAndSpaces: Bool
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        completions
    }

    func notifyAccepted(_ completion: CodeSuggestion) async {
        accepted = completion.uuid
    }

    func notifyRejected(_ completions: [CodeSuggestion]) async {
        rejected = completions.map(\.uuid)
    }
}
