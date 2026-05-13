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
    var errorMessage: String?
    
    var selectedApps: [AppBundle] {
        apps.filter(\.isSelected)
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        apps = []
        
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
            for app in toUninstall {
                var urls: [URL] = [app.bundleURL]
                urls += app.leftovers.filter(\.isSelected).map(\.url)
                
                do {
                    try await NSWorkspace.shared.recycle(urls)
                    count += 1
                } catch {
                    print("Failed to uninstall \(app.name): \(error)")
                }
            }
            
            self.apps.removeAll { $0.isSelected }
            self.uninstalledCount += count
            self.isUninstalling = false
        }
    }
    
    func toggleAppSelection(_ app: AppBundle) {
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isSelected.toggle()
        }
    }
}
