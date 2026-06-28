import XCTest
@testable import Modelbox

final class RuntimeDecisionTests: XCTestCase {
    func testOllamaLoadedIsWarmAndStoppable() {
        let info = RuntimeDecision.evaluate(
            source: .ollama, modelName: "llama3:8b",
            ollamaLoaded: ["llama3:8b"], holder: nil
        )
        XCTAssertEqual(info?.stopTarget, .ollama(model: "llama3:8b"))
    }

    func testOllamaNotLoadedIsNil() {
        let info = RuntimeDecision.evaluate(
            source: .ollama, modelName: "llama3:8b",
            ollamaLoaded: ["qwen3:8b"], holder: nil
        )
        XCTAssertNil(info)
    }

    func testLlamaServerHeldFileIsStoppable() {
        let info = RuntimeDecision.evaluate(
            source: .custom, modelName: "gpt-oss-20b",
            ollamaLoaded: [], holder: (pid: 4242, name: "llama-server")
        )
        XCTAssertEqual(info?.stopTarget, .process(pid: 4242, name: "llama-server"))
    }

    func testInProcessAppHeldFileIsWarmButNotStoppable() {
        // Held by a host app (OpenWhispr) -> warm (info present) but no clean stop.
        let info = RuntimeDecision.evaluate(
            source: .openWhispr, modelName: "Qwen", ollamaLoaded: [],
            holder: (pid: 99, name: "OpenWhispr")
        )
        XCTAssertNotNil(info, "should be warm")
        XCTAssertNil(info?.stopTarget, "host app must not be stoppable from here")
    }

    func testNoHolderIsIdle() {
        let info = RuntimeDecision.evaluate(
            source: .openWhispr, modelName: "Qwen", ollamaLoaded: [], holder: nil
        )
        XCTAssertNil(info)
    }
}
