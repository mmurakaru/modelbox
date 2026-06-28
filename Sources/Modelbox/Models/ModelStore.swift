import Foundation
import Observation

/// In-memory inventory of local models. Scanners populate it; the views read it.
@MainActor
@Observable
final class ModelStore {
    private(set) var models: [LocalModel] = []
    private(set) var lastScan: Date?
    private(set) var isScanning = false

    var searchQuery: String = ""

    var filteredModels: [LocalModel] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return models }
        return models.filter {
            $0.name.lowercased().contains(query)
                || $0.source.displayName.lowercased().contains(query)
        }
    }

    var totalBytes: Int64 {
        models.reduce(0) { $0 + $1.sizeBytes }
    }

    func rescan() {
        // Scanners land in a follow-up; for now this just records the attempt.
        lastScan = Date()
    }

    func remove(_ model: LocalModel) {
        models.removeAll { $0.id == model.id }
    }

    func _seedForTesting(_ models: [LocalModel]) {
        self.models = models
    }
}
