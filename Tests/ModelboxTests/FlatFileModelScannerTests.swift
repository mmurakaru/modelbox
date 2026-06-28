import XCTest
@testable import Modelbox

final class FlatFileModelScannerTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appending(path: "modelbox-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ name: String, bytes: Int) throws {
        let url = tmp.appending(path: name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    func testFindsModelFilesWithSizesAndFormats() throws {
        try write("qwen3.5-9b-q4_k_m.gguf", bytes: 1234)
        try write("nested/llama-3-8b.safetensors", bytes: 50)
        try write("notes.txt", bytes: 10)

        let models = FlatFileModelScanner(source: .custom, roots: [tmp])
            .scan()
            .sorted { $0.sizeBytes > $1.sizeBytes }

        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "qwen3.5-9b-q4_k_m")
        XCTAssertEqual(models[0].sizeBytes, 1234)
        XCTAssertEqual(models[0].format, .gguf)
        XCTAssertEqual(models[1].format, .safetensors)
        XCTAssertEqual(models[1].sizeBytes, 50)
        XCTAssertTrue(models.allSatisfy { $0.source == .custom })
    }

    func testMissingRootYieldsNothing() {
        let scanner = FlatFileModelScanner(source: .custom, roots: [tmp.appending(path: "nope")])
        XCTAssertTrue(scanner.scan().isEmpty)
    }

    func testAggregateDedupesByIDAndSortsLargestFirst() throws {
        try write("small.gguf", bytes: 100)
        try write("big.gguf", bytes: 9000)

        let s1 = FlatFileModelScanner(source: .custom, roots: [tmp])
        let s2 = FlatFileModelScanner(source: .custom, roots: [tmp])
        let models = ModelStore.aggregate([s1, s2])

        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models.map(\.name), ["big", "small"])
    }
}
