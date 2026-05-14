import Foundation
import SwiftUI

@MainActor
@Observable
final class UninstallerViewModel {
    var apps: [AppBundle] = []
    var isScanning = false
    var scanComplete = false
    var isUninstalling = false
    var uninstalledCount = 0
    var freedSpace: Int64 = 0
    var errorMessage: String?
    
    var selectedApps: [AppBundle] {
        apps.filter(\.isSelected)
    }
    
    var selectedTotalSize: Int64 {
        selectedApps.reduce(0) { $0 + $1.totalSize }
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        apps = []
        uninstalledCount = 0
        freedSpace = 0
        
        Task { @MainActor in
            let results = await FileScanner.scanApplications()
            self.apps = results
            self.isScanning = false
            self.scanComplete = true
        }
    }
    
    func uninstallSelected() {
        let toUninstall = apps.filter(\.isSelected)
        guard !toUninstall.isEmpty else { return }
        isUninstalling = true
        
        Task { @MainActor in
            var count = 0
            var freed: Int64 = 0
            
            for app in toUninstall {
                var urls: [URL] = [app.bundleURL]
                urls += app.leftovers.filter(\.isSelected).map(\.url)
                
                for url in urls {
                    do {
                        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                        freed += app.totalSize
                    } catch {
                        print("Failed to uninstall \(app.name): \(error)")
                    }
                }
                count += 1
            }
            
            self.apps.removeAll { $0.isSelected }
            self.uninstalledCount += count
            self.freedSpace += freed
            self.isUninstalling = false
        }
    }
    
    func toggleAppSelection(_ app: AppBundle) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        for index in apps.indices {
            apps[index].isSelected = true
        }
    }
    
    func deselectAll() {
        for index in apps.indices {
            apps[index].isSelected = false
        }
    }
}
