import Foundation

/// A model listed on the Hugging Face Hub. Lab/name are derived from the `org/name` id.
struct HFModel: Sendable, Codable, Identifiable {
    let id: String
    let downloads: Int?
    let likes: Int?
    let pipelineTag: String?
    let libraryName: String?

    enum CodingKeys: String, CodingKey {
        case id, downloads, likes
        case pipelineTag = "pipeline_tag"
        case libraryName = "library_name"
    }

    var lab: String {
        guard let slash = id.firstIndex(of: "/") else { return "" }
        return String(id[..<slash])
    }

    var name: String {
        guard let slash = id.firstIndex(of: "/") else { return id }
        return String(id[id.index(after: slash)...])
    }

    /// Best-effort parameter count parsed from the name, e.g. "8B", "8x7B", "70B". A hint, not exact.
    var parameterHint: String? {
        guard let match = name.firstMatch(of: /(\d+(?:\.\d+)?(?:x\d+)?)[bB](?:[-_. ]|$)/) else { return nil }
        return String(match.1).uppercased() + "B"
    }
}

enum HuggingFaceError: Error {
    case badStatus(Int)
}

protocol HuggingFaceSearching: Sendable {
    func search(query: String, token: String?) async throws -> [HFModel]
}

/// Queries the free Hugging Face Hub models API. No auth required; a token raises the rate limit.
struct HuggingFaceClient: HuggingFaceSearching {
    var session: URLSession = .shared

    func makeRequest(query: String, token: String?) -> URLRequest {
        var components = URLComponents(string: "https://huggingface.co/api/models")!
        var items = [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
        ]
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "search", value: trimmed))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func search(query: String, token: String?) async throws -> [HFModel] {
        let (data, response) = try await session.data(for: makeRequest(query: query, token: token))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HuggingFaceError.badStatus(http.statusCode)
        }
        return try JSONDecoder().decode([HFModel].self, from: data)
    }
}
