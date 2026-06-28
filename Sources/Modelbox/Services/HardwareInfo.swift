import Foundation

/// Static facts about the host machine, read once.
enum HardwareInfo {
    /// Physical RAM in bytes (`hw.memsize`).
    static let physicalMemoryBytes = Int64(ProcessInfo.processInfo.physicalMemory)
}
