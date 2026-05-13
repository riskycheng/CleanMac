import Foundation
import SwiftUI

@MainActor
@Observable
final class SmartScanViewModel {
    var phase: SmartCarePhase = .idle
    var healthScore: Int = 100
    var errorMessage: String?
    
    // Raw scan data
    var junkFiles: [JunkFile] = []
    var threats: [MalwareThreat] = []
    var privacyItems: [PrivacyItem] = []
    var largeFiles: [LargeFile] = []
    var apps: [AppBundle] = []
    
    func startSmartScan() {
        guard case .idle = phase else { return }
        phase = .scanning(moduleIndex: 0, currentPath: "")
        errorMessage = nil
        
        Task { @MainActor in
            await runScanPhases()
        }
    }
    
    func stop() {
        // In a real app we'd cancel the task; here we just reset
        phase = .idle
    }
    
    func startOver() {
        phase = .idle
        junkFiles = []
        threats = []
        privacyItems = []
        largeFiles = []
        apps = []
    }
    
    func runSelectedTasks() {
        guard case .results(let results) = phase else { return }
        let selectedTypes = results.filter(\.isSelected).map(\.type)
        guard !selectedTypes.isEmpty else { return }
        
        phase = .processing(moduleIndex: 0, itemIndex: 0)
        
        Task { @MainActor in
            await runProcessing(selectedTypes: selectedTypes)
        }
    }
    
    private func runScanPhases() async {
        // Phase 0: Cleanup
        phase = .scanning(moduleIndex: 0, currentPath: "Looking for junk...")
        junkFiles = await FileScanner.scanSystemJunk()
        try? await Task.sleep(nanoseconds: 600_000_000)
        
        // Phase 1: Protection
        phase = .scanning(moduleIndex: 1, currentPath: "Scanning for threats...")
        threats = await FileScanner.scanMalware()
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Phase 2: Performance
        phase = .scanning(moduleIndex: 2, currentPath: "Checking performance...")
        privacyItems = await FileScanner.scanPrivacyTraces()
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Phase 3: Applications
        phase = .scanning(moduleIndex: 3, currentPath: "Analyzing applications...")
        apps = await FileScanner.scanApplications()
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Phase 4: My Clutter
        phase = .scanning(moduleIndex: 4, currentPath: "Analyzing your storage...")
        largeFiles = await FileScanner.scanLargeFiles(minSize: 50 * 1024 * 1024, maxAgeDays: 180)
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Build results
        let results = buildResults()
        
        // Calculate health score
        var score = 100
        let totalJunk = junkFiles.reduce(0) { $0 + $1.size }
        if totalJunk > 1_000_000_000 { score -= 20 }
        else if totalJunk > 500_000_000 { score -= 10 }
        else if totalJunk > 100_000_000 { score -= 5 }
        score -= threats.count * 15
        score -= privacyItems.count * 2
        score = max(0, min(100, score))
        
        healthScore = score
        phase = .results(results)
    }
    
    private func buildResults() -> [ScanModuleResult] {
        let totalJunk = junkFiles.reduce(0) { $0 + $1.size }
        let junkDetail = junkFiles.map { ScanDetailItem(name: $0.url.lastPathComponent, size: $0.size, status: .pending) }
        
        let threatDetail = threats.map { ScanDetailItem(name: $0.name, size: 0, status: .pending) }
        
        let privacyDetail = privacyItems.map { ScanDetailItem(name: $0.name, size: $0.size, status: .pending) }
        
        let appUpdateDetail = apps.prefix(3).map { ScanDetailItem(name: $0.name, size: $0.totalSize, status: .pending) }
        
        let clutterDetail = largeFiles.prefix(5).map { ScanDetailItem(name: $0.url.lastPathComponent, size: $0.size, status: .pending) }
        
        return [
            ScanModuleResult(
                type: .cleanup,
                isSelected: totalJunk > 0,
                hasIssues: totalJunk > 0,
                primaryText: totalJunk > 0 ? ByteFormatter.string(from: totalJunk) + " of junk" : "No junk found",
                secondaryText: "to clean",
                detailItems: junkDetail
            ),
            ScanModuleResult(
                type: .protection,
                isSelected: threats.count > 0,
                hasIssues: threats.count > 0,
                primaryText: threats.count > 0 ? "\(threats.count) threat\(threats.count == 1 ? "" : "s")" : "No threats",
                secondaryText: "to remove",
                detailItems: threatDetail
            ),
            ScanModuleResult(
                type: .performance,
                isSelected: privacyItems.count > 0,
                hasIssues: privacyItems.count > 0,
                primaryText: privacyItems.count > 0 ? "\(privacyItems.count) task\(privacyItems.count == 1 ? "" : "s")" : "No tasks",
                secondaryText: "to run",
                detailItems: privacyDetail
            ),
            ScanModuleResult(
                type: .applications,
                isSelected: apps.count > 0,
                hasIssues: apps.count > 0,
                primaryText: apps.count > 0 ? "\(min(apps.count, 5)) vital update\(min(apps.count, 5) == 1 ? "" : "s")" : "No updates",
                secondaryText: "to install",
                detailItems: appUpdateDetail
            ),
            ScanModuleResult(
                type: .myClutter,
                isSelected: largeFiles.count > 0,
                hasIssues: largeFiles.count > 0,
                primaryText: largeFiles.count > 0 ? "\(largeFiles.count) item\(largeFiles.count == 1 ? "" : "s")" : "No duplicates",
                secondaryText: "to remove",
                detailItems: clutterDetail
            )
        ]
    }
    
    private func runProcessing(selectedTypes: [ScanModuleType]) async {
        let allModules = ScanModuleType.allCases
        
        for (moduleIdx, moduleType) in allModules.enumerated() {
            guard selectedTypes.contains(moduleType) else { continue }
            
            // Update detail items status
            updateDetailItems(for: moduleType) { $0.status = .processing }
            phase = .processing(moduleIndex: moduleIdx, itemIndex: 0)
            
            // Simulate processing each item
            let itemCount = detailItemCount(for: moduleType)
            for itemIdx in 0..<itemCount {
                phase = .processing(moduleIndex: moduleIdx, itemIndex: itemIdx)
                updateDetailItem(at: moduleIdx, index: itemIdx, status: .processing)
                try? await Task.sleep(nanoseconds: 300_000_000)
                updateDetailItem(at: moduleIdx, index: itemIdx, status: .done)
            }
            
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        
        phase = .complete
    }
    
    private func detailItemCount(for type: ScanModuleType) -> Int {
        switch type {
        case .cleanup: return min(junkFiles.count, 4)
        case .protection: return min(threats.count, 3)
        case .performance: return min(privacyItems.count, 3)
        case .applications: return min(apps.count, 3)
        case .myClutter: return min(largeFiles.count, 4)
        }
    }
    
    private func updateDetailItems(for type: ScanModuleType, transform: (inout ScanDetailItem) -> Void) {
        guard case .results(var results) = phase else { return }
        if let idx = results.firstIndex(where: { $0.type == type }) {
            for i in results[idx].detailItems.indices {
                transform(&results[idx].detailItems[i])
            }
        }
        phase = .results(results)
    }
    
    private func updateDetailItem(at moduleIdx: Int, index: Int, status: ProcessingStatus) {
        guard case .results(var results) = phase,
              moduleIdx < results.count,
              index < results[moduleIdx].detailItems.count else { return }
        results[moduleIdx].detailItems[index].status = status
        phase = .results(results)
    }
    
    func toggleModuleSelection(_ type: ScanModuleType) {
        guard case .results(var results) = phase,
              let idx = results.firstIndex(where: { $0.type == type }) else { return }
        results[idx].isSelected.toggle()
        phase = .results(results)
    }
}
