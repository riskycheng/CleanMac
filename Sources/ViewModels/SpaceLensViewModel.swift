import Foundation
import SwiftUI

@MainActor
@Observable
final class SpaceLensViewModel {
    var rootItem: DiskItem?
    var isScanning = false
    var scanComplete = false
    var errorMessage: String?
    var selectedItem: DiskItem?
    var navigationStack: [DiskItem] = []
    
    var currentItem: DiskItem? {
        navigationStack.last ?? rootItem
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        rootItem = nil
        navigationStack = []
        
        Task { @MainActor in
            let item = await FileScanner.buildDiskTree(for: PathConstants.home, maxDepth: 3)
            self.rootItem = item
            self.isScanning = false
            self.scanComplete = true
        }
    }
    
    func drillInto(_ item: DiskItem) {
        guard item.isDirectory else { return }
        navigationStack.append(item)
    }
    
    func goBack() {
        _ = navigationStack.popLast()
    }
    
    func goToRoot() {
        navigationStack.removeAll()
    }
}
