import Foundation

/// Incremental progress event emitted during long-running scans.
/// Buffers are flushed periodically (e.g., every 100 files) to avoid
/// flooding the main thread with UI updates.
struct ScanProgress: Sendable {
    let deltaFiles: Int
    let deltaBytes: Int64
    let currentPath: String
    let category: String?
}
