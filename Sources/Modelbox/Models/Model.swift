import Foundation

/// Where a local model was found. Each case maps to one scanner.
enum ModelSource: String, Codable, Sendable, CaseIterable {
    case ollama
    case huggingFaceCache
    case lmStudio
    case openWhispr
    case appSupport
    case custom

    var displayName: String {
        switch self {
        case .ollama: "Ollama"
        case .huggingFaceCache: "Hugging Face"
        case .lmStudio: "LM Studio"
        case .openWhispr: "OpenWhispr"
        case .appSupport: "App Support"
        case .custom: "Custom"
        }
    }
}

enum ModelFormat: String, Codable, Sendable {
    case gguf
    case safetensors
    case ollamaBlob
    case unknown
}

/// One model on disk. `digest` is a content hash (or content-addressed blob digest)
/// used for cross-source dedup; nil until computed.
struct LocalModel: Identifiable, Sendable, Hashable {
    let id: String
    var name: String
    var source: ModelSource
    var path: URL
    var format: ModelFormat
    var sizeBytes: Int64
    var estimatedRAMBytes: Int64?
    var digest: String?
    var modifiedAt: Date?
    var quantization: String?
    var parameters: String?

    init(
        id: String,
        name: String,
        source: ModelSource,
        path: URL,
        format: ModelFormat,
        sizeBytes: Int64,
        estimatedRAMBytes: Int64? = nil,
        digest: String? = nil,
        modifiedAt: Date? = nil,
        quantization: String? = nil,
        parameters: String? = nil
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.path = path
        self.format = format
        self.sizeBytes = sizeBytes
        self.estimatedRAMBytes = estimatedRAMBytes
        self.digest = digest
        self.modifiedAt = modifiedAt
        self.quantization = quantization
        self.parameters = parameters
    }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
