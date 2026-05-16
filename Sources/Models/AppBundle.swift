import Foundation

@Observable
class AppBundle: Identifiable, @unchecked Sendable {
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let url: URL
    let size: Int64
    let leftoverFiles: [URL]
    var isSelected: Bool = false
    
    // Intelligence properties (populated by AppIntelligenceEngine)
    var category: String = "Other"
    var daysSinceUsed: Double?
    var hasBackgroundAgents: Bool = false
    var is32Bit: Bool = false
    var isAppStore: Bool = false
    
    var totalSize: Int64 {
        let leftoverSize = leftoverFiles.reduce(Int64(0)) { sum, url in
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return sum + fileSize
        }
        return size + leftoverSize
    }
    
    var lastActiveText: String {
        guard let days = daysSinceUsed else { return "Unknown" }
        if days < 1 { return "Today" }
        if days < 7 { return "\(Int(days))d ago" }
        if days < 30 { return "\(Int(days / 7))w ago" }
        if days < 365 { return "\(Int(days / 30))mo ago" }
        return "\(Int(days / 365))y ago"
    }
    
    var isUnused: Bool {
        guard let days = daysSinceUsed else { return false }
        return days > 90
    }
    
    init(name: String, bundleID: String, version: String, url: URL, size: Int64, leftoverFiles: [URL], isSelected: Bool = false,
         category: String = "Other", daysSinceUsed: Double? = nil, hasBackgroundAgents: Bool = false, is32Bit: Bool = false, isAppStore: Bool = false) {
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.url = url
        self.size = size
        self.leftoverFiles = leftoverFiles
        self.isSelected = isSelected
        self.category = category
        self.daysSinceUsed = daysSinceUsed
        self.hasBackgroundAgents = hasBackgroundAgents
        self.is32Bit = is32Bit
        self.isAppStore = isAppStore
    }
}
