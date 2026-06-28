import Foundation

/// Client-side parameter-size filter for Explorer results (the list API has no reliable size field,
/// so we bucket on the parsed parameter hint).
enum SizeBucket: String, CaseIterable, Identifiable, Sendable {
    case any
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any: "Any size"
        case .small: "≤ 4B"
        case .medium: "4-13B"
        case .large: "13-34B"
        case .extraLarge: "> 34B"
        }
    }

    func matches(_ parameterHint: String?) -> Bool {
        guard self != .any else { return true }
        guard let billions = SizeBucket.billions(from: parameterHint) else { return false }
        switch self {
        case .any: return true
        case .small: return billions <= 4
        case .medium: return billions > 4 && billions <= 13
        case .large: return billions > 13 && billions <= 34
        case .extraLarge: return billions > 34
        }
    }

    /// Parses "8B", "70B", "1.5B", or "8x7B" (→ 56) into a billions value.
    static func billions(from parameterHint: String?) -> Double? {
        guard let hint = parameterHint?.lowercased().replacingOccurrences(of: "b", with: ""),
              !hint.isEmpty else { return nil }
        let factors = hint.split(separator: "x").compactMap { Double($0) }
        guard !factors.isEmpty else { return nil }
        return factors.reduce(1, *)
    }
}
