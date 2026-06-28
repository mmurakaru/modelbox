import Foundation
import Observation

/// In-memory inventory of local models. Scanners populate it; the views read it.
@MainActor
@Observable
final class ModelStore {
    private(set) var models: [LocalModel] = []
    private(set) var lastScan: Date?
    private(set) var isScanning = false
    private(set) var duplicateGroups: [DuplicateGroup] = []
    private(set) var isDetectingDuplicates = false

    var searchQuery: String = ""

    private var scanners: [any ModelScanner] = []
    private var watchers: [DirectoryWatcher] = []
    private let dedup = DedupDetector()
    private var didStart = false

    /// Total space freeable by removing all-but-one of each duplicate group.
    var reclaimableBytes: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes }
    }

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

    /// Configures scanners from the given settings, starts watching, and runs the first scan. Idempotent.
    func start(configuration: ScanConfiguration) {
        guard !didStart else { return }
        didStart = true
        apply(configuration)
    }

    /// Rebuilds scanners when the scan settings change, then re-scans.
    func reconfigure(_ configuration: ScanConfiguration) {
        guard didStart else { return }
        apply(configuration)
    }

    private func apply(_ configuration: ScanConfiguration) {
        scanners = DefaultScanners.scanners(for: configuration)
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
                self?.duplicateGroups = []  // stale once the inventory changes
            }
        }
    }

    /// Detects byte-identical models off the main thread. Not run on routine refreshes.
    func findDuplicates() {
        guard !isDetectingDuplicates else { return }
        isDetectingDuplicates = true
        let snapshot = models
        Task {
            let groups = await dedup.findDuplicates(in: snapshot)
            duplicateGroups = groups
            isDetectingDuplicates = false
        }
    }

    /// How many copies the given model has (1 = unique / not yet detected).
    func copyCount(for model: LocalModel) -> Int {
        duplicateGroups.first { group in
            group.models.contains { $0.id == model.id }
        }?.models.count ?? 1
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
            .flatMap(\.watchRoots)
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
