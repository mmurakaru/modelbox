import XCTest
@testable import Modelbox

@MainActor
final class ModelDeletionTests: XCTestCase {
    private func model(format: ModelFormat) -> LocalModel {
        LocalModel(id: "x", name: "x", source: .custom,
                   path: URL(fileURLWithPath: "/tmp/x"), format: format, sizeBytes: 1)
    }

    func testFlatFilesAreTrashable() {
        XCTAssertTrue(ModelDeletion.canTrash(model(format: .gguf)))
        XCTAssertTrue(ModelDeletion.canTrash(model(format: .safetensors)))
    }

    func testOllamaBlobsAreNotDirectlyTrashable() {
        XCTAssertFalse(ModelDeletion.canTrash(model(format: .ollamaBlob)))
    }

    func testRemoveDropsModelFromStore() {
        let store = ModelStore()
        let a = model(format: .gguf)
        store._seedForTesting([a])
        store.remove(a)
        XCTAssertTrue(store.models.isEmpty)
    }
}
