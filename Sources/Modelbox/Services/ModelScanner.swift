import Foundation

/// One scanner per source. Best-effort: a missing directory yields no models, never an error.
protocol ModelScanner: Sendable {
    var source: ModelSource { get }
    /// Directories to watch for live refresh.
    var watchRoots: [URL] { get }
    func scan() -> [LocalModel]
}

/// Walks flat folders for model weight files (`.gguf`, `.safetensors`).
/// Used for OpenWhispr, LM Studio, the Application Support sweep, and custom paths.
struct FlatFileModelScanner: ModelScanner {
    let source: ModelSource
    let roots: [URL]

    var watchRoots: [URL] { roots }

    private static let extensions: Set<String> = ["gguf", "safetensors"]

    func scan() -> [LocalModel] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        var results: [LocalModel] = []

        for root in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                guard Self.extensions.contains(ext) else { continue }
                let values = try? url.resourceValues(forKeys: Set(keys))
                if values?.isRegularFile == false { continue }
                results.append(LocalModel(
                    id: "\(source.rawValue):\(url.path)",
                    name: url.deletingPathExtension().lastPathComponent,
                    source: source,
                    path: url,
                    format: ext == "safetensors" ? .safetensors : .gguf,
                    sizeBytes: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate
                ))
            }
        }
        return results
    }
}

/// Builds the scanner set enabled by a `ScanConfiguration`.
enum DefaultScanners {
    static func scanners(
        for configuration: ScanConfiguration,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [any ModelScanner] {
        var scanners: [any ModelScanner] = []
        if configuration.ollama {
            scanners.append(OllamaScanner(root: home.appending(path: ".ollama/models")))
        }
        if configuration.huggingFace {
            scanners.append(HuggingFaceCacheScanner(root: HuggingFaceCacheScanner.defaultRoot(home: home)))
        }
        if configuration.openWhispr {
            scanners.append(FlatFileModelScanner(source: .openWhispr, roots: [
                home.appending(path: ".cache/openwhispr/models"),
            ]))
        }
        if configuration.lmStudio {
            scanners.append(FlatFileModelScanner(source: .lmStudio, roots: [
                home.appending(path: ".lmstudio/models"),
                home.appending(path: ".cache/lm-studio"),
            ]))
        }
        if configuration.appSupport {
            scanners.append(FlatFileModelScanner(source: .appSupport, roots: appSupportModelRoots()))
        }
        if !configuration.customPaths.isEmpty {
            scanners.append(FlatFileModelScanner(source: .custom, roots: configuration.customPaths))
        }
        return scanners
    }

    /// `~/Library/Application Support/<app>/models` directories that exist.
    static func appSupportModelRoots() -> [URL] {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let entries = try? fm.contentsOfDirectory(
                  at: base,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              )
        else { return [] }

        return entries
            .map { $0.appending(path: "models") }
            .filter { url in
                var isDir: ObjCBool = false
                return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
            }
    }
}
