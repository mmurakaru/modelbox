import Foundation
import Observation

/// Drives the Explorer tab: runs Hugging Face searches, caches the last results to disk,
/// and degrades gracefully offline by keeping the cached results visible.
@MainActor
@Observable
final class ExplorerModel {
    private(set) var results: [HFModel] = []
    private(set) var lastSynced: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var query: String = ""

    private let client: any HuggingFaceSearching
    private let cacheURL: URL

    init(
        client: any HuggingFaceSearching = HuggingFaceClient(),
        cacheURL: URL = ExplorerModel.defaultCacheURL()
    ) {
        self.client = client
        self.cacheURL = cacheURL
        loadCache()
    }

    func search(token: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await client.search(query: query, token: token)
            lastSynced = Date()
            saveCache()
        } catch {
            // Keep whatever is cached; just tell the user we couldn't refresh.
            errorMessage = "Couldn't reach Hugging Face. Showing the last synced results."
        }
    }

    // MARK: - Cache

    private struct CachePayload: Codable {
        var models: [HFModel]
        var lastSynced: Date
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data)
        else { return }
        results = payload.models
        lastSynced = payload.lastSynced
    }

    private func saveCache() {
        let payload = CachePayload(models: results, lastSynced: lastSynced ?? Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func defaultCacheURL() -> URL {
        let fm = FileManager.default
        let base = (fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory)
            .appending(path: "Modelbox")
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "explorer-cache.json")
    }
}
