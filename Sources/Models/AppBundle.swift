import Foundation

@Observable
class AppBundle: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let version: String
    let url: URL
    let size: Int64
    let leftoverFiles: [URL]
    var isSelected: Bool = false
    
    var totalSize: Int64 {
        let leftoverSize = leftoverFiles.reduce(Int64(0)) { sum, url in
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return sum + fileSize
        }
        return size + leftoverSize
    }
    
    init(name: String, bundleID: String, version: String, url: URL, size: Int64, leftoverFiles: [URL], isSelected: Bool = false) {
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.url = url
        self.size = size
        self.leftoverFiles = leftoverFiles
        self.isSelected = isSelected
    }
}
