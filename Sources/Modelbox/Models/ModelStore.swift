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

    private var scanners: [any ModelScanner] = []
    private var watchers: [DirectoryWatcher] = []
    private var didStart = false

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

    /// Configures the default scanners, starts watching their roots, and runs the first scan. Idempotent.
    func start() {
        guard !didStart else { return }
        didStart = true
        scanners = DefaultScanners.all()
        startWatching()
        rescan()
    }

    func rescan() {
        let scanners = self.scanners
        isScanning = true
        Task.detached(priority: .utility) {
            let found = ModelStore.aggregate(scanners)
            await MainActor.run { [weak self] in
                self?.models = found
                self?.lastScan = Date()
                self?.isScanning = false
            }
        }
    }

    /// Runs every scanner, dedupes by id, and sorts largest-first. Pure, off-main-thread safe.
    nonisolated static func aggregate(_ scanners: [any ModelScanner]) -> [LocalModel] {
        var seen = Set<String>()
        var out: [LocalModel] = []
        for scanner in scanners {
            for model in scanner.scan() where seen.insert(model.id).inserted {
                out.append(model)
            }
        }
        return out.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func remove(_ model: LocalModel) {
        models.removeAll { $0.id == model.id }
    }

    private func startWatching() {
        let roots = scanners
            .compactMap { $0 as? FlatFileModelScanner }
            .flatMap(\.roots)
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        watchers = roots.compactMap { url in
            DirectoryWatcher(url: url) { [weak self] in
                Task { @MainActor in self?.rescan() }
            }
        }
    }

    func _seedForTesting(_ models: [LocalModel]) {
        self.models = models
    }
}
