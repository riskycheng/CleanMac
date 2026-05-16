import Foundation

/// A grouped collection of junk files belonging to the same app or source.
@Observable
class JunkGroup: Identifiable, @unchecked Sendable {
    let id = UUID()
    let appName: String
    let category: JunkCategory
    let files: [JunkFile]
    var isSelected: Bool
    
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        files.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    init(appName: String, category: JunkCategory, files: [JunkFile], isSelected: Bool = true) {
        self.appName = appName
        self.category = category
        self.files = files
        self.isSelected = isSelected
    }
}
