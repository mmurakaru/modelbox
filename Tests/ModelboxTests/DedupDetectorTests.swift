import XCTest
@testable import Modelbox

final class DedupDetectorTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appending(path: "modelbox-dedup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func writeModel(_ name: String, contents: Data, source: ModelSource = .custom) throws -> LocalModel {
        let url = tmp.appending(path: name)
        try contents.write(to: url)
        return LocalModel(
            id: "\(source.rawValue):\(url.path)",
            name: url.deletingPathExtension().lastPathComponent,
            source: source,
            path: url,
            format: .gguf,
            sizeBytes: Int64(contents.count)
        )
    }

    func testIdenticalFlatFilesAreGroupedAndReclaimableComputed() async throws {
        let shared = Data(repeating: 7, count: 4096)
        let a = try writeModel("copy-a.gguf", contents: shared)
        let b = try writeModel("copy-b.gguf", contents: shared)
        let other = try writeModel("other.gguf", contents: Data(repeating: 9, count: 4096))

        let groups = await DedupDetector().findDuplicates(in: [a, b, other])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].models.map(\.id)), [a.id, b.id])
        XCTAssertEqual(groups[0].reclaimableBytes, 4096)
    }

    func testUniqueSizesAreNeverGrouped() async throws {
        let a = try writeModel("a.gguf", contents: Data(repeating: 1, count: 100))
        let b = try writeModel("b.gguf", contents: Data(repeating: 1, count: 200))

        let groups = await DedupDetector().findDuplicates(in: [a, b])
        XCTAssertTrue(groups.isEmpty)
    }

    func testSameSizeDifferentContentNotGrouped() async throws {
        let a = try writeModel("a.gguf", contents: Data(repeating: 1, count: 512))
        let b = try writeModel("b.gguf", contents: Data(repeating: 2, count: 512))

        let groups = await DedupDetector().findDuplicates(in: [a, b])
        XCTAssertTrue(groups.isEmpty)
    }

    func testExplicitDigestGroupsWithoutHashing() async throws {
        let a = LocalModel(id: "ollama:a", name: "a", source: .ollama,
                           path: URL(fileURLWithPath: "/no/such/a"), format: .ollamaBlob,
                           sizeBytes: 10, digest: "sha256:abc")
        let b = LocalModel(id: "ollama:b", name: "b", source: .ollama,
                           path: URL(fileURLWithPath: "/no/such/b"), format: .ollamaBlob,
                           sizeBytes: 10, digest: "sha256:abc")

        let groups = await DedupDetector().findDuplicates(in: [a, b])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].reclaimableBytes, 10)
    }
}
