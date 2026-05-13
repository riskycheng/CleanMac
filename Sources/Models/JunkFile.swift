import Foundation

struct JunkFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let type: JunkType
    var isSelected: Bool = true
    
    enum JunkType: String, CaseIterable {
        case cache = "Cache"
        case log = "Log"
        case temp = "Temp"
        case download = "Download"
        case trash = "Trash"
        case systemCache = "System Cache"
        
        var icon: String {
            switch self {
            case .cache, .systemCache: return "archivebox"
            case .log: return "doc.text"
            case .temp: return "clock.arrow.circlepath"
            case .download: return "arrow.down.circle"
            case .trash: return "trash"
            }
        }
        
        var color: String {
            switch self {
            case .cache, .systemCache: return "cyan"
            case .log: return "yellow"
            case .temp: return "orange"
            case .download: return "blue"
            case .trash: return "red"
            }
        }
    }
    
    var formattedSize: String {
        ByteFormatter.string(from: size)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: JunkFile, rhs: JunkFile) -> Bool {
        lhs.id == rhs.id
    }
}
