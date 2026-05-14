import Foundation

enum JunkCategory: String, CaseIterable {
    case caches
    case systemCaches
    case logs
    case tempFiles
    case brokenDownloads
    case trash
    case orphanedSupport
    case browserCache
    case xcodeJunk
    case developerCache
    case systemLogs
    case userLogs
    
    var displayName: String {
        switch self {
        case .caches: return "User Caches"
        case .systemCaches: return "System Caches"
        case .logs: return "Log Files"
        case .tempFiles: return "Temporary Files"
        case .brokenDownloads: return "Broken Downloads"
        case .trash: return "Trash"
        case .orphanedSupport: return "Orphaned Support"
        case .browserCache: return "Browser Cache"
        case .xcodeJunk: return "Xcode Artifacts"
        case .developerCache: return "Developer Caches"
        case .systemLogs: return "System Logs"
        case .userLogs: return "User Logs"
        }
    }
    
    var icon: String {
        switch self {
        case .caches: return "archivebox"
        case .systemCaches: return "archivebox.fill"
        case .logs: return "doc.text"
        case .tempFiles: return "clock"
        case .brokenDownloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .orphanedSupport: return "questionmark.folder"
        case .browserCache: return "globe"
        case .xcodeJunk: return "hammer"
        case .developerCache: return "terminal"
        case .systemLogs: return "doc.text.fill"
        case .userLogs: return "doc.text"
        }
    }
}

@Observable
class JunkFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let url: URL
    let size: Int64
    let category: JunkCategory
    var isSelected: Bool = true
    
    init(name: String, path: String, url: URL, size: Int64, category: JunkCategory, isSelected: Bool = true) {
        self.name = name
        self.path = path
        self.url = url
        self.size = size
        self.category = category
        self.isSelected = isSelected
    }
}
