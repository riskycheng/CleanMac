import Foundation

struct LargeFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let modificationDate: Date
    var isSelected: Bool = false
    
    var formattedSize: String {
        ByteFormatter.string(from: size)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: modificationDate)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LargeFile, rhs: LargeFile) -> Bool {
        lhs.id == rhs.id
    }
}
