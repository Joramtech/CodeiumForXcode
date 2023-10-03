import Foundation
import SuggestionModel
import XCTest
import FocusedCodeFinder

@testable import ActiveDocumentChatContextCollector

final class SwiftFocusedCodeFinder_Selection_Tests: XCTestCase {
    func context(code: String) -> ActiveDocumentContext {
        .init(
            filePath: "",
            relativePath: "",
            language: .builtIn(.swift),
            fileContent: code,
            lines: code.components(separatedBy: "\n").map { "\($0)\n" },
            selectedCode: "", selectionRange: .zero,
            lineAnnotations: [],
            imports: []
        )
    }

    func test_collecting_imports() {
        let code = """
        import var Darwin.stderr
        public struct A: B, C {
            let a = 1
        }
        import Bar
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 2, character: 1)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context.imports, ["Darwin.stderr", "Bar"])
    }

    func test_selecting_a_line_inside_the_function_the_scope_should_be_the_function() {
        let code = """
        public struct A: B, C {
            @ViewBuilder private func f(_ a: String) -> String {
                let a = 1
                let b = 2
                let c = 3
                let d = 4
                let e = 5
            }
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 4, character: 0),
            end: CursorPosition(line: 4, character: 13)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "public struct A: B, C",
                "@ViewBuilder private func f(_ a: String) -> String",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (8, 1)),
            focusedRange: .init(startPair: (4, 0), endPair: (4, 13)),
            focusedCode: """
                    let c = 3

            """,
            imports: []
        ))
    }

    func test_selecting_a_function_inside_a_struct_the_scope_should_be_the_struct() {
        let code = """
        @MainActor
        public struct A: B, C {
            func f() {
                let a = 1
                let b = 2
                let c = 3
                let d = 4
                let e = 5
            }
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 7, character: 5)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "@MainActor public struct A: B, C",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (9, 1)),
            focusedRange: .init(startPair: (2, 0), endPair: (7, 5)),
            focusedCode: """
                func f() {
                    let a = 1
                    let b = 2
                    let c = 3
                    let d = 4
                    let e = 5

            """,
            imports: []
        ))
    }

    func test_selecting_a_variable_inside_a_class_the_scope_should_be_the_class() {
        let code = """
        @MainActor final public class A: P<B, C, D>, K {
            var a = 1
            var b = 2
            var c = 3
            var d = 4
            var e = 5
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 9)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "@MainActor final public class A: P<B, C, D>, K",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (6, 1)),
            focusedRange: .init(startPair: (1, 0), endPair: (1, 9)),
            focusedCode: """
                var a = 1

            """,
            imports: []
        ))
    }

    func test_selecting_a_function_inside_a_protocol_the_scope_should_be_the_protocol() {
        let code = """
        public protocol A: Hashable {
            func f()
            func g()
            func h()
            func i()
            func j()
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 9)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "public protocol A: Hashable",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (6, 1)),
            focusedRange: .init(startPair: (1, 0), endPair: (1, 9)),
            focusedCode: """
                func f()

            """,
            imports: []
        ))
    }

    func test_selecting_a_variable_inside_an_extension_the_scope_should_be_the_extension() {
        let code = """
        private extension A: Equatable {
            var a = 1
            var b = 2
            var c = 3
            var d = 4
            var e = 5
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 1, character: 0),
            end: CursorPosition(line: 1, character: 9)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "private extension A: Equatable",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (6, 1)),
            focusedRange: .init(startPair: (1, 0), endPair: (1, 9)),
            focusedCode: """
                var a = 1

            """,
            imports: []
        ))
    }

    func test_selecting_a_static_function_from_an_actor_the_scope_should_be_the_actor() {
        let code = """
        @gloablActor
        public actor A {
            static func f() {}
            static func g() {}
            static func h() {}
            static func i() {}
            static func j() {}
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 2, character: 9)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "@gloablActor public actor A",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (7, 1)),
            focusedRange: .init(startPair: (2, 0), endPair: (2, 9)),
            focusedCode: """
                static func f() {}

            """,
            imports: []
        ))
    }

    func test_selecting_a_case_inside_an_enum_the_scope_should_be_the_enum() {
        let code = """
        @MainActor
        public
        indirect enum A {
            case a
            case b
            case c
            case d
            case e
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 3, character: 0),
            end: CursorPosition(line: 3, character: 9)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "@MainActor public indirect enum A",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (8, 1)),
            focusedRange: .init(startPair: (3, 0), endPair: (3, 9)),
            focusedCode: """
                case a

            """,
            imports: []
        ))
    }

    func test_selecting_a_line_inside_computed_variable_the_scope_should_be_the_variable() {
        let code = """
        struct A {
            @SomeWrapper public private(set) var a: Int {
                let a = 1
                let b = 2
                let c = 3
                let d = 4
                let e = 5
            }
        }
        """
        let range = CursorRange(
            start: CursorPosition(line: 2, character: 0),
            end: CursorPosition(line: 2, character: 9)
        )
        let context = SwiftFocusedCodeFinder().findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .scope(signature: [
                "struct A",
                "@SomeWrapper public private(set) var a: Int",
            ]),
            contextRange: .init(startPair: (0, 0), endPair: (8, 1)),
            focusedRange: .init(startPair: (2, 0), endPair: (2, 9)),
            focusedCode: """
                    let a = 1

            """,
            imports: []
        ))
    }

    func test_selecting_a_line_in_freestanding_macro_the_scope_should_be_the_macro() {
        // TODO:
    }
}

final class SwiftFocusedCodeFinder_FocusedCode_Tests: XCTestCase {
    func context(code: String) -> ActiveDocumentContext {
        .init(
            filePath: "",
            relativePath: "",
            language: .builtIn(.swift),
            fileContent: code,
            lines: code.components(separatedBy: "\n").map { "\($0)\n" },
            selectedCode: "", selectionRange: .zero,
            lineAnnotations: [],
            imports: []
        )
    }
    
    func test_get_focused_code_on_top_level_should_fallback_to_unknown_language() {
        let code = """
        @MainActor
        public
        indirect enum A {
            case a
            case b
            case c
            case d
            case e
        }
        
        func hello() {
            print("hello")
            print("hello")
        }
        """
        let range = CursorRange(startPair: (0, 0), endPair: (0, 0))
        let context = SwiftFocusedCodeFinder(maxFocusedCodeLineCount: 1000).findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .top,
            contextRange: .init(startPair: (0, 0), endPair: (13, 2)),
            focusedRange: .init(startPair: (0, 0), endPair: (10, 15)),
            focusedCode: """
            @MainActor
            public
            indirect enum A {
                case a
                case b
                case c
                case d
                case e
            }
            
            func hello() {
            
            """,
            imports: []
        ))
    }
    
    func test_get_focused_code_inside_enum_the_whole_enum_will_be_the_focused_code() {
        let code = """
        @MainActor
        public
        indirect enum A {
            case a
            case b
            case c
            case d
            case e
        }
        """
        let range = CursorRange(startPair: (3, 0), endPair: (3, 0))
        let context = SwiftFocusedCodeFinder(maxFocusedCodeLineCount: 1000).findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .file,
            contextRange: .init(startPair: (0, 0), endPair: (0, 0)),
            focusedRange: .init(startPair: (0, 0), endPair: (8, 1)),
            focusedCode: """
            @MainActor
            public
            indirect enum A {
                case a
                case b
                case c
                case d
                case e
            }
            
            """,
            imports: []
        ))
    }
    
    func test_get_focused_code_inside_enum_with_limited_max_line_count() {
        let code = """
        @MainActor
        public
        indirect enum A {
            case a
            case b
            case c
            case d
            case e
        }
        """
        let range = CursorRange(startPair: (3, 0), endPair: (3, 0))
        let context = SwiftFocusedCodeFinder(maxFocusedCodeLineCount: 3).findFocusedCode(
            containingRange: range,
            activeDocumentContext: context(code: code)
        )
        XCTAssertEqual(context, .init(
            scope: .file,
            contextRange: .init(startPair: (0, 0), endPair: (0, 0)),
            focusedRange: .init(startPair: (2, 0), endPair: (4, 11)),
            focusedCode: """
            indirect enum A {
                case a
                case b
            
            """,
            imports: []
        ))
    }
}
