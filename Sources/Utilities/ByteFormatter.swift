import Foundation

enum ByteFormatter {
    static func string(from byteCount: Int64) -> String {
        let formatter = Foundation.ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: byteCount)
    }
    
    static func string(from byteCount: UInt64) -> String {
        string(from: Int64(byteCount))
    }
}
