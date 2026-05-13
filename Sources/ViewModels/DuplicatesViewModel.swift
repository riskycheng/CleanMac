import Foundation
import SwiftUI

@MainActor
@Observable
final class DuplicatesViewModel {
    var groups: [DuplicateGroup] = []
    var isScanning = false
    var scanProgress: Double = 0
    var scanComplete = false
    var isCleaning = false
    var cleanedSize: Int64 = 0
    var errorMessage: String?
    var scanPath: URL = PathConstants.downloads
    
    var totalWastedSpace: Int64 {
        groups.reduce(0) { $0 + $1.wastedSpace }
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        scanProgress = 0
        groups = []
        
        Task { @MainActor in
            let results = await FileScanner.findDuplicates(in: scanPath, minSize: 1024 * 1024)
            self.groups = results
            self.scanProgress = 1.0
            self.isScanning = false
            self.scanComplete = true
        }
    }
    
    func removeSelected() {
        var urlsToRemove: [URL] = []
        var totalRemoved: Int64 = 0
        
        for groupIndex in groups.indices {
            let selectedFiles = groups[groupIndex].files.filter(\.isSelected)
            let allFiles = groups[groupIndex].files
            let keepOne = allFiles.first { !$0.isSelected } ?? allFiles.first
            
            for file in selectedFiles {
                if file.id != keepOne?.id {
                    urlsToRemove.append(file.url)
                    totalRemoved += file.size
                }
            }
        }
        
        guard !urlsToRemove.isEmpty else { return }
        isCleaning = true
        
        Task { @MainActor in
            _ = try? await TrashManager.moveToTrash(urls: urlsToRemove)
            
            self.groups.removeAll { group in
                let remaining = group.files.filter { !$0.isSelected }
                return remaining.count <= 1
            }
            self.cleanedSize += totalRemoved
            self.isCleaning = false
        }
    }
    
    func selectAllButOne(in group: DuplicateGroup) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == group.id }) else { return }
        let files = groups[groupIndex].files
        guard !files.isEmpty else { return }
        
        for fileIndex in groups[groupIndex].files.indices {
            groups[groupIndex].files[fileIndex].isSelected = fileIndex != 0
        }
    }
    
    func deselectAll(in group: DuplicateGroup) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == group.id }) else { return }
        for fileIndex in groups[groupIndex].files.indices {
            groups[groupIndex].files[fileIndex].isSelected = false
        }
    }
}
