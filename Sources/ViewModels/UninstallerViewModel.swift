import SwiftUI

enum UninstallerState {
    case idle
    case scanning
    case reviewing
    case uninstalling
    case complete
}

@MainActor
@Observable
final class UninstallerViewModel {
    var state: UninstallerState = .idle
    var apps: [AppBundle] = []
    var scanProgress: Double = 0
    var scanStage: String = ""
    var scanLog: [String] = []
    var uninstallProgress: Double = 0
    var uninstallStage: String = ""
    var itemsRemoved: Int = 0
    var spaceReclaimed: Int64 = 0
    
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
        state = .scanning
        scanProgress = 0
        scanStage = "Initializing..."
        scanLog.removeAll()
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
                scanLog.append("[\(timeString())] \(stage)")
                if scanLog.count > 30 { scanLog.removeFirst() }
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        
        let scannedApps = await FileScanner.scanApplications()
        
        await MainActor.run {
            apps = scannedApps
            scanProgress = 1.0
            scanStage = "Scan complete"
            scanLog.append("[\(timeString())] Scan complete — \(apps.count) apps found")
            state = .reviewing
        }
    }
    
    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
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
        
        state = .uninstalling
        uninstallProgress = 0
        uninstallStage = "Starting uninstall..."
        itemsRemoved = 0
        spaceReclaimed = 0
        
        Task {
            let total = selected.count
            for (index, app) in selected.enumerated() {
                await MainActor.run {
                    uninstallStage = "Uninstalling \(app.name)..."
                    uninstallProgress = Double(index) / Double(total)
                }
                
                do {
                    try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
                    spaceReclaimed += app.size
                    itemsRemoved += 1
                } catch {
                    print("Failed to trash app: \(error)")
                }
                
                for leftover in app.leftoverFiles {
                    do {
                        try FileManager.default.trashItem(at: leftover, resultingItemURL: nil)
                        let size = (try? FileManager.default.attributesOfItem(atPath: leftover.path)[.size] as? Int64) ?? 0
                        spaceReclaimed += size
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
                state = .complete
            }
        }
    }
    
    func reset() {
        state = .idle
        scanProgress = 0
        uninstallProgress = 0
        scanLog.removeAll()
        apps.removeAll()
        itemsRemoved = 0
        spaceReclaimed = 0
    }
}
