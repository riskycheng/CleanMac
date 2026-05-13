import Foundation
import SwiftUI

@MainActor
@Observable
final class PrivacyViewModel {
    var items: [PrivacyItem] = []
    var isScanning = false
    var scanComplete = false
    var isCleaning = false
    var cleanedCount = 0
    var errorMessage: String?
    
    var totalSize: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        items = []
        
        Task { @MainActor in
            let results = await FileScanner.scanPrivacyTraces()
            self.items = results
            self.isScanning = false
            self.scanComplete = true
        }
    }
    
    func cleanSelected() {
        let toClean = items.filter(\.isSelected)
        guard !toClean.isEmpty else { return }
        isCleaning = true
        
        Task { @MainActor in
            let urls = toClean.compactMap(\.url)
            _ = try? await TrashManager.moveToTrash(urls: urls)
            
            self.items.removeAll { $0.isSelected }
            self.cleanedCount += toClean.count
            self.isCleaning = false
        }
    }
    
    func toggleAll(_ select: Bool) {
        for index in items.indices {
            items[index].isSelected = select
        }
    }
}
