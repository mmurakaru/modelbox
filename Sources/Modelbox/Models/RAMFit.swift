import SwiftUI

/// Estimated RAM to load a model: disk size scaled by a tunable factor.
enum RAMEstimate {
    static func bytes(forModelSize size: Int64, factor: Double) -> Int64 {
        Int64((Double(size) * factor).rounded())
    }
}

/// Whether a model's estimated RAM fits the machine's physical memory.
enum RAMFit {
    case fits   // comfortably under available RAM
    case tight  // close to the limit
    case tooBig // exceeds physical RAM

    /// fits ≤ 70% of RAM, tight ≤ 100%, else too big.
    static func evaluate(estimatedRAM: Int64, machineRAM: Int64) -> RAMFit {
        guard machineRAM > 0 else { return .tooBig }
        if estimatedRAM <= machineRAM * 7 / 10 { return .fits }
        if estimatedRAM <= machineRAM { return .tight }
        return .tooBig
    }

    var label: String {
        switch self {
        case .fits: "Fits"
        case .tight: "Tight"
        case .tooBig: "Too big"
        }
    }

    var systemImage: String {
        switch self {
        case .fits: "checkmark.circle.fill"
        case .tight: "exclamationmark.triangle.fill"
        case .tooBig: "xmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .fits: .green
        case .tight: .orange
        case .tooBig: .red
        }
    }
}
