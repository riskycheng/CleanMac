import Foundation

struct AppBundle: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleURL: URL
    let bundleIdentifier: String?
    let version: String?
    let size: Int64
    let lastUsed: Date?
    var isSelected: Bool = false
    var leftovers: [LeftoverFile] = []
    
    struct LeftoverFile: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let size: Int64
        var isSelected: Bool = true
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: LeftoverFile, rhs: LeftoverFile) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var totalSize: Int64 {
        size + leftovers.reduce(0) { $0 + $1.size }
    }
    
    var formattedSize: String {
        ByteFormatter.string(from: totalSize)
    }
    
    var formattedLastUsed: String {
        guard let date = lastUsed else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppBundle, rhs: AppBundle) -> Bool {
        lhs.id == rhs.id
    }
}
