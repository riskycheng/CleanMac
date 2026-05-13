import Foundation

struct PrivacyItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL?
    let type: PrivacyType
    let size: Int64
    var isSelected: Bool = true
    
    enum PrivacyType: String, CaseIterable {
        case browserHistory = "Browser History"
        case downloadHistory = "Download History"
        case cookies = "Cookies"
        case recentItems = "Recent Items"
        case clipboard = "Clipboard"
        
        var icon: String {
            switch self {
            case .browserHistory: return "safari"
            case .downloadHistory: return "arrow.down.circle"
            case .cookies: return "cookie"
            case .recentItems: return "clock"
            case .clipboard: return "doc.on.clipboard"
            }
        }
    }
    
    var formattedSize: String {
        ByteFormatter.string(from: size)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PrivacyItem, rhs: PrivacyItem) -> Bool {
        lhs.id == rhs.id
    }
}
