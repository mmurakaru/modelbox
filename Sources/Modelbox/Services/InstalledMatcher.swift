import Foundation

/// Best-effort cross-reference between an Explorer result and the local inventory.
enum InstalledMatcher {
    /// True when a local model's name looks like the Hub model (substring either direction).
    static func isInstalled(_ model: HFModel, localNames: [String]) -> Bool {
        let candidate = model.name.lowercased()
        guard candidate.count >= 3 else { return false }
        return localNames.contains { local in
            let lowered = local.lowercased()
            return lowered.contains(candidate) || candidate.contains(lowered)
        }
    }

    /// The Ollama command that pulls this Hub model (Ollama supports `hf.co/<id>`).
    static func pullCommand(for model: HFModel) -> String {
        "ollama pull hf.co/\(model.id)"
    }

    static func modelPageURL(for model: HFModel) -> URL? {
        URL(string: "https://huggingface.co/\(model.id)")
    }
}
