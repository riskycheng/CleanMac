import Foundation

struct JunkFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let type: JunkType
    var isSelected: Bool = true
    
    enum JunkType: String, CaseIterable, Identifiable {
        case cache = "Cache"
        case systemCache = "System Cache"
        case log = "Log"
        case systemLog = "System Log"
        case temp = "Temp"
        case download = "Broken Download"
        case trash = "Trash"
        case browserCache = "Browser Cache"
        case xcode = "Xcode"
        case developerCache = "Dev Cache"
        case orphanedSupport = "Orphaned Support"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .cache, .systemCache: return "archivebox"
            case .log, .systemLog: return "doc.text"
            case .temp: return "clock.arrow.circlepath"
            case .download: return "arrow.down.circle"
            case .trash: return "trash"
            case .browserCache: return "safari"
            case .xcode: return "hammer"
            case .developerCache: return "terminal"
            case .orphanedSupport: return "folder.badge.questionmark"
            }
        }
        
        var color: String {
            switch self {
            case .cache, .systemCache: return "cyan"
            case .log, .systemLog: return "yellow"
            case .temp: return "orange"
            case .download: return "blue"
            case .trash: return "red"
            case .browserCache: return "purple"
            case .xcode: return "indigo"
            case .developerCache: return "teal"
            case .orphanedSupport: return "gray"
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
