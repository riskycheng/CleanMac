import Foundation

/// Represents a large file discovered by the LargeFileScanner.
@Observable
class LargeFile: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let path: String
    let size: Int64
    let allocatedSize: Int64
    let accessDate: Date?
    let modificationDate: Date?
    var isSelected: Bool = true
    
    init(url: URL, size: Int64, allocatedSize: Int64, accessDate: Date?, modificationDate: Date?) {
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.size = size
        self.allocatedSize = allocatedSize
        self.accessDate = accessDate
        self.modificationDate = modificationDate
    }
    
    /// Days since last access. Falls back to modification date if access date unavailable.
    var daysSinceAccess: Double? {
        let referenceDate = accessDate ?? modificationDate
        guard let date = referenceDate else { return nil }
        return Date().timeIntervalSince(date) / 86400.0
    }
    
    /// Human-readable access time bucket label.
    var accessBucket: String {
        guard let days = daysSinceAccess else { return "Unknown" }
        switch days {
        case ..<7:   return "Hot"
        case 7..<30: return "Warm"
        case 30..<90: return "Cold"
        case 90..<365: return "Frozen"
        default:     return "Zombie"
        }
    }
    
    var accessBucketColor: String {
        switch accessBucket {
        case "Hot":    return "EF4444"   // red
        case "Warm":   return "F97316"   // orange
        case "Cold":   return "F59E0B"   // amber
        case "Frozen": return "3B82F6"   // blue
        case "Zombie": return "8B5CF6"   // purple
        default:       return "9CA3AF"   // gray
        }
    }
}
