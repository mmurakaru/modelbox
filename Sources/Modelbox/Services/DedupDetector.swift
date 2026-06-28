import Foundation
import CryptoKit

/// A set of byte-identical models. Keeping one and removing the rest reclaims `reclaimableBytes`.
struct DuplicateGroup: Identifiable, Sendable {
    let id: String
    let models: [LocalModel]

    var reclaimableBytes: Int64 {
        guard let size = models.first?.sizeBytes, models.count > 1 else { return 0 }
        return Int64(models.count - 1) * size
    }
}

/// Finds byte-identical models. Content hashes are computed only for size-collision groups
/// (identical files share a size), off the main thread, and cached so repeat runs are cheap.
actor DedupDetector {
    private var hashCache: [String: String] = [:]

    func findDuplicates(in models: [LocalModel]) -> [DuplicateGroup] {
        var keyed: [String: [LocalModel]] = [:]
        var needHash: [LocalModel] = []

        // Models that already carry a content digest (e.g. Ollama/HF) group for free.
        for model in models {
            if let digest = model.digest {
                keyed["digest:\(digest)", default: []].append(model)
            } else {
                needHash.append(model)
            }
        }

        // A unique file size can't have a byte-identical twin, so only hash collisions.
        for (_, sameSize) in Dictionary(grouping: needHash, by: \.sizeBytes) where sameSize.count > 1 {
            for model in sameSize {
                guard let hash = contentHash(for: model) else { continue }
                keyed["hash:\(hash)", default: []].append(model)
            }
        }

        return keyed
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(id: $0.key, models: $0.value.sorted { $0.path.path < $1.path.path }) }
            .sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    private func contentHash(for model: LocalModel) -> String? {
        let mtime = model.modifiedAt?.timeIntervalSince1970 ?? 0
        let key = "\(model.path.path)|\(model.sizeBytes)|\(mtime)"
        if let cached = hashCache[key] { return cached }

        guard let handle = try? FileHandle(forReadingFrom: model.path) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        hashCache[key] = digest
        return digest
    }
}
