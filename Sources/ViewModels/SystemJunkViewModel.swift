import Foundation
import SwiftUI

@MainActor
@Observable
final class SystemJunkViewModel {
    var files: [JunkFile] = []
    var isScanning = false
    var scanComplete = false
    var isCleaning = false
    var cleanedSize: Int64 = 0
    var errorMessage: String?
    
    var totalSize: Int64 {
        files.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }
    
    var selectedCount: Int {
        files.filter(\.isSelected).count
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        files = []
        cleanedSize = 0
        
        Task { @MainActor in
            let results = await FileScanner.scanSystemJunk()
            self.files = results
            self.isScanning = false
            self.scanComplete = true
        }
    }
    
    func cleanSelected() {
        let toClean = files.filter(\.isSelected)
        guard !toClean.isEmpty else { return }
        isCleaning = true
        
        Task { @MainActor in
            let urls = toClean.map(\.url)
            var count = 0
            for url in urls {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    count += 1
                } catch {
                    print("Failed to trash \(url.path): \(error)")
                }
            }
            let cleaned = toClean.reduce(0) { $0 + $1.size }
            
            self.files.removeAll { $0.isSelected }
            self.cleanedSize += cleaned
            self.isCleaning = false
        }
    }
    
    func toggleAll(_ select: Bool) {
        for index in files.indices {
            files[index].isSelected = select
        }
    }
    
    func groupedByType() -> [JunkFile.JunkType: [JunkFile]] {
        Dictionary(grouping: files, by: { $0.type })
    }
}
