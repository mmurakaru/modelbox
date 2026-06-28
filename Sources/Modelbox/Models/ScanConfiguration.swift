import Foundation

/// Which sources to scan and any user-added custom paths. Mirrors the Settings controls.
struct ScanConfiguration: Equatable, Sendable {
    var ollama = true
    var huggingFace = true
    var lmStudio = true
    var openWhispr = true
    var appSupport = true
    var customPaths: [URL] = []

    /// Parses the comma-separated custom-paths field, expanding `~` and dropping blanks.
    static func parseCustomPaths(_ raw: String) -> [URL] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }
}
