import SwiftUI

@MainActor
@Observable
final class UninstallerViewModel {
    var isScanning = false
    var isUninstalling = false
    var scanComplete = false
    var apps: [AppBundle] = []
    var scanProgress: Double = 0
    var scanStage: String = ""
    var uninstallProgress: Double = 0
    var uninstallStage: String = ""
    
    var totalSize: Int64 {
        apps.reduce(0) { $0 + $1.totalSize }
    }
    
    var selectedCount: Int {
        apps.filter { $0.isSelected }.count
    }
    
    var allSelected: Bool {
        apps.allSatisfy { $0.isSelected }
    }
    
    func startScan() {
        isScanning = true
        scanComplete = false
        scanProgress = 0
        scanStage = "Initializing..."
        apps.removeAll()
        
        Task {
            await runScanWithAnimation()
        }
    }
    
    private func runScanWithAnimation() async {
        let stages = [
            ("Scanning /Applications...", 0.20),
            ("Scanning ~/Applications...", 0.40),
            ("Reading app metadata...", 0.60),
            ("Searching leftover files...", 0.80),
            ("Finalizing scan...", 0.95)
        ]
        
        for (stage, progress) in stages {
            await MainActor.run {
                scanStage = stage
                scanProgress = progress
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        
        let scannedApps = await FileScanner.scanApplications()
        
        await MainActor.run {
            apps = scannedApps
            scanProgress = 1.0
            scanStage = "Scan complete"
            isScanning = false
            scanComplete = true
        }
    }
    
    func toggleAll() {
        let allSelected = apps.allSatisfy { $0.isSelected }
        for app in apps {
            app.isSelected = !allSelected
        }
    }
    
    func uninstallSelected() {
        let selected = apps.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        
        isUninstalling = true
        uninstallProgress = 0
        uninstallStage = "Starting uninstall..."
        
        Task {
            let total = selected.count
            for (index, app) in selected.enumerated() {
                await MainActor.run {
                    uninstallStage = "Uninstalling \(app.name)..."
                    uninstallProgress = Double(index) / Double(total)
                }
                
                // Move app bundle to trash
                do {
                    try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
                } catch {
                    print("Failed to trash app: \(error)")
                }
                
                // Move leftovers to trash
                for leftover in app.leftoverFiles {
                    do {
                        try FileManager.default.trashItem(at: leftover, resultingItemURL: nil)
                    } catch {
                        print("Failed to trash leftover: \(error)")
                    }
                }
                
                try? await Task.sleep(for: .milliseconds(100))
            }
            
            await MainActor.run {
                apps.removeAll { $0.isSelected }
                uninstallProgress = 1.0
                uninstallStage = "Uninstall complete"
                isUninstalling = false
            }
        }
    }
}
