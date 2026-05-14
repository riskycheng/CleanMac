import SwiftUI

enum JunkCleanerState {
    case idle
    case scanning
    case reviewing
    case cleaning
    case complete
}

@MainActor
@Observable
final class SystemJunkViewModel {
    var state: JunkCleanerState = .idle
    var junkFiles: [JunkFile] = []
    var totalSize: Int64 = 0
    var scanProgress: Double = 0
    var scanStage: String = ""
    var scanLog: [String] = []
    var cleanProgress: Double = 0
    var cleanStage: String = ""
    var itemsCleaned: Int = 0
    var spaceReclaimed: Int64 = 0
    
    var selectedCount: Int {
        junkFiles.filter { $0.isSelected }.count
    }
    
    var allSelected: Bool {
        junkFiles.allSatisfy { $0.isSelected }
    }
    
    func categorySize(_ category: JunkCategory) -> Int64 {
        junkFiles.filter { $0.category == category }.reduce(0) { $0 + $1.size }
    }
    
    func filesInCategory(_ category: JunkCategory) -> [JunkFile] {
        junkFiles.filter { $0.category == category }
    }
    
    func startScan() {
        state = .scanning
        scanProgress = 0
        scanStage = "Initializing..."
        scanLog.removeAll()
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
                scanLog.append("[\(timeString())] \(stage)")
                if scanLog.count > 30 { scanLog.removeFirst() }
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        
        let files = await FileScanner.scanSystemJunk()
        
        await MainActor.run {
            junkFiles = files
            totalSize = junkFiles.reduce(0) { $0 + $1.size }
            scanProgress = 1.0
            scanStage = "Scan complete"
            scanLog.append("[\(timeString())] Scan complete — \(junkFiles.count) items found")
            state = .reviewing
        }
    }
    
    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
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
        
        state = .cleaning
        cleanProgress = 0
        cleanStage = "Starting cleanup..."
        itemsCleaned = 0
        spaceReclaimed = 0
        
        Task {
            let total = selected.count
            for (index, file) in selected.enumerated() {
                await MainActor.run {
                    cleanStage = "Removing \(file.name)..."
                    cleanProgress = Double(index) / Double(total)
                }
                
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                    itemsCleaned += 1
                    spaceReclaimed += file.size
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
                state = .complete
            }
        }
    }
    
    func reset() {
        state = .idle
        scanProgress = 0
        cleanProgress = 0
        scanLog.removeAll()
        junkFiles.removeAll()
        totalSize = 0
        itemsCleaned = 0
    }
}
