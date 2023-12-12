import SuggestionModel
import Foundation

public struct EditorContent: Codable {
    public struct Selection: Codable {
        public var start: CursorPosition
        public var end: CursorPosition

        public init(start: CursorPosition, end: CursorPosition) {
            self.start = start
            self.end = end
        }
    }

    public init(
        content: String,
        lines: [String],
        uti: String,
        cursorPosition: CursorPosition,
        selections: [Selection],
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) {
        self.content = content
        self.lines = lines
        self.uti = uti
        self.cursorPosition = cursorPosition
        self.selections = selections
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
    }

    public var content: String
    public var lines: [String]
    public var uti: String
    public var cursorPosition: CursorPosition
    public var selections: [Selection]
    public var tabSize: Int
    public var indentSize: Int
    public var usesTabsForIndentation: Bool

    public func selectedCode(in selection: Selection) -> String {
        return XPCShared.selectedCode(in: selection, for: lines)
    }
}

public struct UpdatedContent: Codable {
    public init(content: String, newSelection: CursorRange? = nil, modifications: [Modification]) {
        self.content = content
        self.newSelection = newSelection
        self.modifications = modifications
    }

    public var content: String
    public var newSelection: CursorRange?
    public var modifications: [Modification]
}

func selectedCode(in selection: EditorContent.Selection, for lines: [String]) -> String {
    let startPosition = selection.start
    let endPosition = CursorPosition(
        line: selection.end.line,
        character: selection.end.character - 1
    )

    guard startPosition.line >= 0, startPosition.line < lines.count else { return "" }
    guard startPosition.character >= 0,
          startPosition.character < lines[startPosition.line].count else { return "" }
    guard endPosition.line >= 0,
          endPosition.line < lines.count
            || (endPosition.line == lines.count && endPosition.character == -1)
    else { return "" }
    guard endPosition.line >= startPosition.line else { return "" }
    guard endPosition.character >= -1 else { return "" }
    
    if endPosition.line < lines.endIndex {
        guard endPosition.character < lines[endPosition.line].count else { return "" }
    }

    var code = ""
    if startPosition.line == endPosition.line {
        guard endPosition.character >= startPosition.character else { return "" }
        let line = lines[startPosition.line]
        let startIndex = line.index(line.startIndex, offsetBy: startPosition.character)
        let endIndex = line.index(line.startIndex, offsetBy: endPosition.character)
        code = String(line[startIndex...endIndex])
    } else {
        let startLine = lines[startPosition.line]
        let startIndex = startLine.index(
            startLine.startIndex,
            offsetBy: startPosition.character
        )
        code += String(startLine[startIndex...])

        if startPosition.line + 1 < endPosition.line {
            for line in lines[startPosition.line + 1...endPosition.line - 1] {
                code += line
            }
        }

        if endPosition.character >= 0, endPosition.line < lines.endIndex {
            let endLine = lines[endPosition.line]
            let endIndex = endLine.index(endLine.startIndex, offsetBy: endPosition.character)
            code += String(endLine[...endIndex])
        }
    }

    return code
}
