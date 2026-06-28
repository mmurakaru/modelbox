import XCTest
@testable import Modelbox

private struct StubSearcher: HuggingFaceSearching {
    let result: Result<[HFModel], Error>
    func search(_ query: HFQuery, token: String?) async throws -> [HFModel] {
        try result.get()
    }
}

private struct StubError: Error {}

private func makeModel(_ id: String) -> HFModel {
    HFModel(id: id, downloads: 1, likes: 1, pipelineTag: nil, libraryName: nil)
}

@MainActor
final class ExplorerModelTests: XCTestCase {
    private var cacheURL: URL!

    override func setUpWithError() throws {
        cacheURL = FileManager.default.temporaryDirectory
            .appending(path: "modelbox-explorer-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: cacheURL)
    }

    func testSearchSuccessPopulatesResultsAndTimestamp() async {
        let model = ExplorerModel(
            client: StubSearcher(result: .success([makeModel("Qwen/Qwen3-8B")])),
            cacheURL: cacheURL
        )
        await model.search(token: nil)

        XCTAssertEqual(model.results.map(\.id), ["Qwen/Qwen3-8B"])
        XCTAssertNotNil(model.lastSynced)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func testFailureKeepsCachedResultsAndSetsError() async {
        // First instance succeeds and writes the cache.
        let first = ExplorerModel(
            client: StubSearcher(result: .success([makeModel("Qwen/Qwen3-8B")])),
            cacheURL: cacheURL
        )
        await first.search(token: nil)

        // A fresh instance loads that cache, then a failing search preserves it.
        let second = ExplorerModel(
            client: StubSearcher(result: .failure(StubError())),
            cacheURL: cacheURL
        )
        XCTAssertEqual(second.results.count, 1, "cache should load on init")
        await second.search(token: nil)

        XCTAssertEqual(second.results.map(\.id), ["Qwen/Qwen3-8B"])
        XCTAssertNotNil(second.errorMessage)
    }

    func testSizeBucketFiltersDisplayedResults() async {
        let model = ExplorerModel(
            client: StubSearcher(result: .success([
                makeModel("Qwen/Qwen3-4B"),
                makeModel("meta/Llama-3-8B"),
                makeModel("meta/Llama-3-70B"),
            ])),
            cacheURL: cacheURL
        )
        await model.search(token: nil)

        model.sizeBucket = .any
        XCTAssertEqual(model.displayedResults.count, 3)

        model.sizeBucket = .small // <= 4B
        XCTAssertEqual(model.displayedResults.map(\.name), ["Qwen3-4B"])

        model.sizeBucket = .extraLarge // > 34B
        XCTAssertEqual(model.displayedResults.map(\.name), ["Llama-3-70B"])
    }
}
