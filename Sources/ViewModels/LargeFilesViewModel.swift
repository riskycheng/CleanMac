import Foundation
import SwiftUI

@MainActor
@Observable
final class LargeFilesViewModel {
    var files: [LargeFile] = []
    var isScanning = false
    var scanComplete = false
    var isCleaning = false
    var cleanedSize: Int64 = 0
    var errorMessage: String?
    var sortBy: SortOption = .size
    
    enum SortOption: String, CaseIterable {
        case size = "Size"
        case date = "Date"
        case name = "Name"
    }
    
    var sortedFiles: [LargeFile] {
        switch sortBy {
        case .size:
            return files.sorted { $0.size > $1.size }
        case .date:
            return files.sorted { $0.modificationDate < $1.modificationDate }
        case .name:
            return files.sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
        }
    }
    
    var selectedSize: Int64 {
        files.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        files = []
        
        Task { @MainActor in
            let results = await FileScanner.scanLargeFiles(minSize: 50 * 1024 * 1024, maxAgeDays: 365)
            self.files = results
            self.isScanning = false
            self.scanComplete = true
        }
    }
    
    func removeSelected() {
        let toRemove = files.filter(\.isSelected)
        guard !toRemove.isEmpty else { return }
        isCleaning = true
        
        Task { @MainActor in
            let urls = toRemove.map(\.url)
            _ = try? await TrashManager.moveToTrash(urls: urls)
            let cleaned = toRemove.reduce(0) { $0 + $1.size }
            
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
}
