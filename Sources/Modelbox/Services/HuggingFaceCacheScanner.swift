import Foundation

/// Scans the Hugging Face Hub cache (`~/.cache/huggingface/hub`, or `HF_HOME`/`HF_HUB_CACHE`).
/// Each `models--org--name` repo stores content-addressed blobs; snapshots are symlinks into them,
/// so true size comes from summing the blob files (counted once).
struct HuggingFaceCacheScanner: ModelScanner {
    let source: ModelSource = .huggingFaceCache
    let root: URL

    var watchRoots: [URL] { [root] }

    static func defaultRoot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        func expand(_ path: String) -> URL { URL(fileURLWithPath: (path as NSString).expandingTildeInPath) }
        if let cache = environment["HF_HUB_CACHE"], !cache.isEmpty {
            return expand(cache)
        }
        if let hfHome = environment["HF_HOME"], !hfHome.isEmpty {
            return expand(hfHome).appending(path: "hub")
        }
        return home.appending(path: ".cache/huggingface/hub")
    }

    func scan() -> [LocalModel] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { return [] }
        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [LocalModel] = []
        for repoDir in entries where repoDir.lastPathComponent.hasPrefix("models--") {
            let repoID = repoDir.lastPathComponent
                .dropFirst("models--".count)
                .replacingOccurrences(of: "--", with: "/")

            let (size, largestBlob) = blobTotals(in: repoDir.appending(path: "blobs"), fm: fm)
            guard size > 0 else { continue }

            let modified = try? repoDir.resourceValues(forKeys: [.contentModificationDateKey])
            results.append(LocalModel(
                id: "\(source.rawValue):\(repoDir.path)",
                name: repoID,
                source: source,
                path: repoDir,
                format: detectFormat(in: repoDir.appending(path: "snapshots"), fm: fm),
                sizeBytes: size,
                digest: largestBlob,
                modifiedAt: modified?.contentModificationDate
            ))
        }
        return results
    }

    /// Sum of regular blob files, plus the name of the largest (a stable dedup key).
    private func blobTotals(in blobsDir: URL, fm: FileManager) -> (size: Int64, largest: String?) {
        guard let blobs = try? fm.contentsOfDirectory(
            at: blobsDir,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, nil) }

        var total: Int64 = 0
        var largestSize: Int64 = -1
        var largestName: String?
        for blob in blobs {
            let values = try? blob.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let size = Int64(values?.fileSize ?? 0)
            total += size
            if size > largestSize {
                largestSize = size
                largestName = blob.lastPathComponent
            }
        }
        return (total, largestName)
    }

    private func detectFormat(in snapshotsDir: URL, fm: FileManager) -> ModelFormat {
        guard let enumerator = fm.enumerator(at: snapshotsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return .unknown
        }
        var sawSafetensors = false
        for case let url as URL in enumerator {
            switch url.pathExtension.lowercased() {
            case "gguf": return .gguf
            case "safetensors": sawSafetensors = true
            default: break
            }
        }
        return sawSafetensors ? .safetensors : .unknown
    }
}
