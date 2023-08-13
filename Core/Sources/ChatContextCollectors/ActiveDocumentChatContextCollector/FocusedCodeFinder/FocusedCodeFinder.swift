import Foundation
import SuggestionModel

struct CodeContext: Equatable {
    enum Scope: Equatable {
        case file
        case top
        case scope(signature: [String])
    }

    var scopeSignatures: [String] {
        switch scope {
        case .file:
            return []
        case .top:
            return ["Top level of the file"]
        case let .scope(signature):
            return signature
        }
    }

    var scope: Scope
    var contextRange: CursorRange
    var focusedRange: CursorRange
    var focusedCode: String
    var imports: [String]

    static var empty: CodeContext {
        .init(scope: .file, contextRange: .zero, focusedRange: .zero, focusedCode: "", imports: [])
    }
}

protocol FocusedCodeFinder {
    func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext
}

struct UnknownLanguageFocusedCodeFinder: FocusedCodeFinder {
    let proposedSearchRange: Int

    init(proposedSearchRange: Int) {
        self.proposedSearchRange = proposedSearchRange
    }

    func findFocusedCode(
        containingRange: CursorRange,
        activeDocumentContext: ActiveDocumentContext
    ) -> CodeContext {
        guard !activeDocumentContext.lines.isEmpty else { return .empty }

        // when user is not selecting any code.
        if containingRange.start == containingRange.end {
            // search up and down for up to `proposedSearchRange * 2 + 1` lines.
            let lines = activeDocumentContext.lines
            let proposedLineCount = proposedSearchRange * 2 + 1
            let startLineIndex = max(containingRange.start.line - proposedSearchRange, 0)
            let endLineIndex = max(
                startLineIndex,
                min(startLineIndex + proposedLineCount - 1, lines.count - 1)
            )

            let focusedLines = lines[startLineIndex...endLineIndex]

            let contextStartLine = max(startLineIndex - 5, 0)
            let contextEndLine = min(endLineIndex + 5, lines.count - 1)

            return .init(
                scope: .top,
                contextRange: .init(
                    start: .init(line: contextStartLine, character: 0),
                    end: .init(line: contextEndLine, character: lines[contextEndLine].count)
                ),
                focusedRange: .init(
                    start: .init(line: startLineIndex, character: 0),
                    end: .init(line: endLineIndex, character: lines[endLineIndex].count)
                ),
                focusedCode: focusedLines.joined(),
                imports: []
            )
        }

        let startLine = max(containingRange.start.line, 0)
        let endLine = min(containingRange.end.line, activeDocumentContext.lines.count - 1)

        if endLine < startLine { return .empty }

        let focusedLines = activeDocumentContext.lines[startLine...endLine]
        let contextStartLine = max(startLine - 3, 0)
        let contextEndLine = min(endLine + 3, activeDocumentContext.lines.count - 1)

        return CodeContext(
            scope: .top,
            contextRange: .init(
                start: .init(line: contextStartLine, character: 0),
                end: .init(
                    line: contextEndLine,
                    character: activeDocumentContext.lines[contextEndLine].count
                )
            ),
            focusedRange: containingRange,
            focusedCode: focusedLines.joined(),
            imports: []
        )
    }
}

