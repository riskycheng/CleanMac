import Foundation

struct DiskItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let isDirectory: Bool
    var children: [DiskItem]?
    
    var formattedSize: String {
        ByteFormatter.string(from: size)
    }
    
    var depth: Int {
        url.pathComponents.count - FileManager.default.homeDirectoryForCurrentUser.pathComponents.count
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiskItem, rhs: DiskItem) -> Bool {
        lhs.id == rhs.id
    }
}
