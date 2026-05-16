import Foundation

/// A file that is part of a duplicate group.
@Observable
class DuplicateFile: Identifiable, @unchecked Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let path: String
    let size: Int64
    var isSelected: Bool = false
    
    init(url: URL, size: Int64) {
        self.url = url
        self.name = url.lastPathComponent
        self.path = url.path
        self.size = size
    }
}

/// A group of files that are byte-for-byte duplicates.
@Observable
class DuplicateGroup: Identifiable, @unchecked Sendable {
    let id = UUID()
    let hash: String
    let size: Int64
    let files: [DuplicateFile]
    var isSelected: Bool = false
    
    var totalWastedSpace: Int64 {
        // All but one copy is waste
        max(0, size * Int64(files.count - 1))
    }
    
    init(hash: String, size: Int64, files: [DuplicateFile]) {
        self.hash = hash
        self.size = size
        self.files = files
    }
}
