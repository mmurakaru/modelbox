import Foundation

/// Scans Ollama's content-addressed store (`~/.ollama/models`): JSON manifests under
/// `manifests/` reference blob digests under `blobs/`. True size is the sum of the
/// referenced blobs on disk.
struct OllamaScanner: ModelScanner {
    let source: ModelSource = .ollama
    let root: URL

    var watchRoots: [URL] { [root] }

    private struct Manifest: Decodable {
        struct Layer: Decodable {
            let digest: String
            let mediaType: String?
        }
        let config: Layer?
        let layers: [Layer]?
    }

    func scan() -> [LocalModel] {
        let fm = FileManager.default
        let manifestsDir = root.appending(path: "manifests")
        let blobsDir = root.appending(path: "blobs")

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: manifestsDir.path, isDirectory: &isDir), isDir.boolValue else { return [] }
        guard let enumerator = fm.enumerator(
            at: manifestsDir,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [LocalModel] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
            guard values?.isRegularFile == true else { continue }
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { continue }

            let layers = manifest.layers ?? []
            let digests = ([manifest.config?.digest] + layers.map(\.digest)).compactMap { $0 }
            let size = digests.reduce(into: Int64(0)) { total, digest in
                total += blobSize(for: digest, in: blobsDir, fm: fm)
            }
            // The model-weights layer makes the best dedup key.
            let modelDigest = layers.first { $0.mediaType?.contains("model") == true }?.digest

            results.append(LocalModel(
                id: "\(source.rawValue):\(url.path)",
                name: modelName(forManifestAt: url, relativeTo: manifestsDir),
                source: source,
                path: url,
                format: .ollamaBlob,
                sizeBytes: size,
                digest: modelDigest,
                modifiedAt: values?.contentModificationDate
            ))
        }
        return results
    }

    /// `manifests/<registry>/<namespace>/<model>/<tag>` → `model:tag` (or `namespace/model:tag`).
    private func modelName(forManifestAt url: URL, relativeTo manifestsDir: URL) -> String {
        let comps = url.pathComponents.dropFirst(manifestsDir.pathComponents.count)
        guard comps.count >= 2 else { return url.lastPathComponent }
        let tag = comps.last!
        let model = comps[comps.index(comps.endIndex, offsetBy: -2)]
        let namespace = comps.count >= 3 ? comps[comps.index(comps.endIndex, offsetBy: -3)] : nil
        if let namespace, namespace != "library" {
            return "\(namespace)/\(model):\(tag)"
        }
        return "\(model):\(tag)"
    }

    private func blobSize(for digest: String, in blobsDir: URL, fm: FileManager) -> Int64 {
        let fileName = digest.replacingOccurrences(of: ":", with: "-")
        let blobURL = blobsDir.appending(path: fileName)
        let values = try? blobURL.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
