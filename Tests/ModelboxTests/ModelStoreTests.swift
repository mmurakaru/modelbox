import XCTest
@testable import Modelbox

@MainActor
final class ModelStoreTests: XCTestCase {
    private func sample() -> [LocalModel] {
        [
            LocalModel(id: "1", name: "qwen3.5-9b-q4_k_m", source: .openWhispr,
                       path: URL(fileURLWithPath: "/a.gguf"), format: .gguf, sizeBytes: 6_000_000_000),
            LocalModel(id: "2", name: "llama-3-8b", source: .ollama,
                       path: URL(fileURLWithPath: "/b"), format: .ollamaBlob, sizeBytes: 4_000_000_000),
        ]
    }

    func testFilterMatchesName() {
        let store = ModelStore()
        store._seedForTesting(sample())
        store.searchQuery = "qwen"
        XCTAssertEqual(store.filteredModels.map(\.id), ["1"])
    }

    func testFilterMatchesSourceName() {
        let store = ModelStore()
        store._seedForTesting(sample())
        store.searchQuery = "ollama"
        XCTAssertEqual(store.filteredModels.map(\.id), ["2"])
    }

    func testTotalBytesSumsAllModels() {
        let store = ModelStore()
        store._seedForTesting(sample())
        XCTAssertEqual(store.totalBytes, 10_000_000_000)
    }

    func testEmptyQueryReturnsAll() {
        let store = ModelStore()
        store._seedForTesting(sample())
        store.searchQuery = "   "
        XCTAssertEqual(store.filteredModels.count, 2)
    }
}
