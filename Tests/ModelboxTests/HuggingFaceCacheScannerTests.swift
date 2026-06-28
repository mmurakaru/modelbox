import XCTest
@testable import Modelbox

final class HuggingFaceCacheScannerTests: XCTestCase {
    private var hub: URL!

    override func setUpWithError() throws {
        hub = FileManager.default.temporaryDirectory.appending(path: "modelbox-hf-\(UUID().uuidString)/hub")
        try FileManager.default.createDirectory(at: hub, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: hub.deletingLastPathComponent())
    }

    private func makeRepo(_ folder: String, blobs: [(String, Int)], snapshotFile: String?) throws {
        let repo = hub.appending(path: folder)
        let blobsDir = repo.appending(path: "blobs")
        try FileManager.default.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        for (name, bytes) in blobs {
            try Data(count: bytes).write(to: blobsDir.appending(path: name))
        }
        if let snapshotFile {
            let snap = repo.appending(path: "snapshots/abc123")
            try FileManager.default.createDirectory(at: snap, withIntermediateDirectories: true)
            try Data(count: 1).write(to: snap.appending(path: snapshotFile))
        }
    }

    func testReadsRepoIDSizeAndFormat() throws {
        try makeRepo("models--Qwen--Qwen3-8B",
                     blobs: [("aaa", 1000), ("bbb", 4000)],
                     snapshotFile: "model.safetensors")

        let models = HuggingFaceCacheScanner(root: hub).scan()
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].name, "Qwen/Qwen3-8B")
        XCTAssertEqual(models[0].source, .huggingFaceCache)
        XCTAssertEqual(models[0].sizeBytes, 5000)
        XCTAssertEqual(models[0].digest, "bbb") // largest blob
        XCTAssertEqual(models[0].format, .safetensors)
    }

    func testGGUFFormatDetected() throws {
        try makeRepo("models--TheBloke--Foo-GGUF", blobs: [("x", 10)], snapshotFile: "foo.Q4_K_M.gguf")
        let models = HuggingFaceCacheScanner(root: hub).scan()
        XCTAssertEqual(models.first?.format, .gguf)
    }

    func testIgnoresNonRepoDirsAndEmptyRepos() throws {
        try makeRepo("models--Empty--Repo", blobs: [], snapshotFile: nil)
        try FileManager.default.createDirectory(at: hub.appending(path: "version.txt-dir"), withIntermediateDirectories: true)
        let models = HuggingFaceCacheScanner(root: hub).scan()
        XCTAssertTrue(models.isEmpty)
    }

    func testDefaultRootHonorsEnvOverrides() {
        let home = URL(fileURLWithPath: "/Users/test")
        XCTAssertEqual(
            HuggingFaceCacheScanner.defaultRoot(environment: [:], home: home).path,
            "/Users/test/.cache/huggingface/hub"
        )
        XCTAssertEqual(
            HuggingFaceCacheScanner.defaultRoot(environment: ["HF_HOME": "/data/hf"], home: home).path,
            "/data/hf/hub"
        )
        XCTAssertEqual(
            HuggingFaceCacheScanner.defaultRoot(environment: ["HF_HUB_CACHE": "/data/hub"], home: home).path,
            "/data/hub"
        )
    }
}
