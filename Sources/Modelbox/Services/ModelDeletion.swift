import Foundation

/// Cleanup helpers for local models. Deletion always goes to the Trash (recoverable).
enum ModelDeletion {
    /// Flat weight files can be trashed directly. Content-addressed blobs (e.g. Ollama)
    /// share storage between models, so their safe removal lands with those scanners.
    static func canTrash(_ model: LocalModel) -> Bool {
        model.format != .ollamaBlob
    }
}
