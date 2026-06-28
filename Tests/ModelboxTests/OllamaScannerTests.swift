import XCTest
@testable import Modelbox

final class OllamaScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "modelbox-ollama-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appending(path: "blobs"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func writeBlob(_ digest: String, bytes: Int) throws {
        let name = digest.replacingOccurrences(of: ":", with: "-")
        try Data(count: bytes).write(to: root.appending(path: "blobs/\(name)"))
    }

    private func writeManifest(path: String, json: String) throws {
        let url = root.appending(path: "manifests/\(path)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.data(using: .utf8)!.write(to: url)
    }

    func testReadsManifestAndSumsBlobSizes() throws {
        try writeBlob("sha256:config", bytes: 100)
        try writeBlob("sha256:weights", bytes: 5000)
        try writeManifest(path: "registry.ollama.ai/library/llama3/8b", json: """
        {
          "config": {"digest": "sha256:config", "mediaType": "application/vnd.ollama.image.config"},
          "layers": [
            {"digest": "sha256:weights", "mediaType": "application/vnd.ollama.image.model"}
          ]
        }
        """)

        let models = OllamaScanner(root: root).scan()
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].name, "llama3:8b")
        XCTAssertEqual(models[0].source, .ollama)
        XCTAssertEqual(models[0].sizeBytes, 5100)
        XCTAssertEqual(models[0].digest, "sha256:weights")
        XCTAssertEqual(models[0].format, .ollamaBlob)
    }

    func testNonLibraryNamespaceKeepsNamespaceInName() throws {
        try writeBlob("sha256:w", bytes: 10)
        try writeManifest(path: "hf.co/user/mymodel/q4", json: """
        {"layers": [{"digest": "sha256:w", "mediaType": "application/vnd.ollama.image.model"}]}
        """)

        let models = OllamaScanner(root: root).scan()
        XCTAssertEqual(models.map(\.name), ["user/mymodel:q4"])
    }

    func testMissingStoreYieldsNothing() {
        let models = OllamaScanner(root: root.appending(path: "nope")).scan()
        XCTAssertTrue(models.isEmpty)
    }
}
