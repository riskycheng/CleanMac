import Foundation

struct DuplicateGroup: Identifiable, Hashable {
    let id = UUID()
    let hash: String
    var files: [DuplicateFile]
    let totalSize: Int64
    
    struct DuplicateFile: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let size: Int64
        var isSelected: Bool = false
        
        var formattedSize: String {
            ByteFormatter.string(from: size)
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: DuplicateFile, rhs: DuplicateFile) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var wastedSpace: Int64 {
        totalSize - (files.first?.size ?? 0)
    }
    
    var formattedWastedSpace: String {
        ByteFormatter.string(from: wastedSpace)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
}
