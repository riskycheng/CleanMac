import SwiftUI

@MainActor
@Observable
final class SystemJunkViewModel {
    var isScanning = false
    var isCleaning = false
    var scanComplete = false
    var junkFiles: [JunkFile] = []
    var totalSize: Int64 = 0
    var scanProgress: Double = 0
    var scanStage: String = ""
    var cleanProgress: Double = 0
    var cleanStage: String = ""
    
    var selectedCount: Int {
        junkFiles.filter { $0.isSelected }.count
    }
    
    var allSelected: Bool {
        junkFiles.allSatisfy { $0.isSelected }
    }
    
    func startScan() {
        isScanning = true
        scanComplete = false
        scanProgress = 0
        scanStage = "Initializing..."
        junkFiles.removeAll()
        
        Task {
            await runScanWithAnimation()
        }
    }
    
    private func runScanWithAnimation() async {
        let stages = [
            ("Scanning user caches...", 0.15),
            ("Scanning system caches...", 0.30),
            ("Scanning log files...", 0.45),
            ("Scanning temporary files...", 0.55),
            ("Scanning browser data...", 0.65),
            ("Scanning Xcode artifacts...", 0.75),
            ("Scanning developer caches...", 0.85),
            ("Finalizing scan...", 0.95)
        ]
        
        for (stage, progress) in stages {
            await MainActor.run {
                scanStage = stage
                scanProgress = progress
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        
        let files = await FileScanner.scanSystemJunk()
        
        await MainActor.run {
            junkFiles = files
            totalSize = junkFiles.reduce(0) { $0 + $1.size }
            scanProgress = 1.0
            scanStage = "Scan complete"
            isScanning = false
            scanComplete = true
        }
    }
    
    func toggleAll() {
        let allSelected = junkFiles.allSatisfy { $0.isSelected }
        for file in junkFiles {
            file.isSelected = !allSelected
        }
    }
    
    func cleanSelected() {
        let selected = junkFiles.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        
        isCleaning = true
        cleanProgress = 0
        cleanStage = "Starting cleanup..."
        
        Task {
            let total = selected.count
            for (index, file) in selected.enumerated() {
                await MainActor.run {
                    cleanStage = "Removing \(file.name)..."
                    cleanProgress = Double(index) / Double(total)
                }
                
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                } catch {
                    print("Failed to trash: \(error)")
                }
                
                try? await Task.sleep(for: .milliseconds(60))
            }
            
            await MainActor.run {
                junkFiles.removeAll { $0.isSelected }
                totalSize = junkFiles.reduce(0) { $0 + $1.size }
                cleanProgress = 1.0
                cleanStage = "Cleanup complete"
                isCleaning = false
            }
        }
    }
}
