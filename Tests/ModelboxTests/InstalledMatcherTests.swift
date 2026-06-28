import XCTest
@testable import Modelbox

final class InstalledMatcherTests: XCTestCase {
    private func hf(_ id: String) -> HFModel {
        HFModel(id: id, downloads: nil, likes: nil, pipelineTag: nil, libraryName: nil)
    }

    func testMatchesRealOpenWhisprFile() {
        // Local flat file from OpenWhispr vs the Hub repo name.
        let installed = InstalledMatcher.isInstalled(
            hf("Qwen/Qwen3.5-9B"),
            localNames: ["Qwen_Qwen3.5-9B-Q4_K_M"]
        )
        XCTAssertTrue(installed)
    }

    func testNotInstalledWhenNoOverlap() {
        XCTAssertFalse(InstalledMatcher.isInstalled(hf("meta/Llama-3-70B"), localNames: ["Qwen3-8B"]))
    }

    func testEmptyInventoryIsNeverInstalled() {
        XCTAssertFalse(InstalledMatcher.isInstalled(hf("meta/Llama-3-8B"), localNames: []))
    }

    func testPullCommandUsesHfCoPrefix() {
        XCTAssertEqual(
            InstalledMatcher.pullCommand(for: hf("Qwen/Qwen3-8B")),
            "ollama pull hf.co/Qwen/Qwen3-8B"
        )
    }

    func testModelPageURL() {
        XCTAssertEqual(
            InstalledMatcher.modelPageURL(for: hf("Qwen/Qwen3-8B"))?.absoluteString,
            "https://huggingface.co/Qwen/Qwen3-8B"
        )
    }
}
