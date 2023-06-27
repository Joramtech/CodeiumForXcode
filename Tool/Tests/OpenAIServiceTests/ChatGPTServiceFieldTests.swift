import XCTest
@testable import OpenAIService

final class ChatGPTServiceFieldTests: XCTestCase {
    let skip = true
    func test_calling_the_api() async throws {
        let service = ChatGPTService()
        
        if skip { return }
        
        do {
            let stream = try await service.send(content: "Hello")
            for try await text in stream {
                print(text)
            }
        } catch {
            print("🔴", error.localizedDescription)
        }
        
        XCTFail("🔴 Please reset the key to `Key` after the field tests.")
    }
}
