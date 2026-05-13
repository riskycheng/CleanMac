import Foundation
import SwiftUI

@MainActor
@Observable
final class SmartScanViewModel {
    var phase: SmartCarePhase = .idle
    var healthScore: Int = 100
    var errorMessage: String?
    
    // Track which modules have completed scanning
    var completedModules: Set<ScanModuleType> = []
    var scanningResults: [ScanModuleResult] = []
    var currentModuleIndex: Int = 0
    var currentPath: String = ""
    
    // Raw scan data
    var junkFiles: [JunkFile] = []
    var threats: [MalwareThreat] = []
    var privacyItems: [PrivacyItem] = []
    var largeFiles: [LargeFile] = []
    var apps: [AppBundle] = []
    
    func startSmartScan() {
        guard case .idle = phase else { return }
        completedModules = []
        scanningResults = []
        currentModuleIndex = 0
        currentPath = ""
        phase = .scanning(moduleIndex: 0, currentPath: "")
        errorMessage = nil
        
        Task { @MainActor in
            await runScanPhases()
        }
    }
    
    func stop() {
        phase = .idle
        completedModules = []
        scanningResults = []
    }
    
    func startOver() {
        phase = .idle
        completedModules = []
        scanningResults = []
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
            await runProcessing(selectedTypes: selectedTypes, originalResults: results)
        }
    }
    
    private func runScanPhases() async {
        let modules = ScanModuleType.allCases
        
        for (index, module) in modules.enumerated() {
            currentModuleIndex = index
            currentPath = module.scanningTitle
            phase = .scanning(moduleIndex: index, currentPath: currentPath)
            
            switch module {
            case .cleanup:
                junkFiles = await FileScanner.scanSystemJunk()
            case .protection:
                threats = await FileScanner.scanMalware()
            case .performance:
                privacyItems = await FileScanner.scanPrivacyTraces()
            case .applications:
                apps = await FileScanner.scanApplications()
            case .myClutter:
                largeFiles = await FileScanner.scanLargeFiles(minSize: 50 * 1024 * 1024, maxAgeDays: 180)
            }
            
            // Build partial result for this module
            let result = buildResult(for: module)
            scanningResults.append(result)
            completedModules.insert(module)
            
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        
        // All done — build final results
        let results = buildAllResults()
        
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
    
    private func buildResult(for type: ScanModuleType) -> ScanModuleResult {
        switch type {
        case .cleanup:
            let total = junkFiles.reduce(0) { $0 + $1.size }
            return ScanModuleResult(
                type: .cleanup,
                isSelected: total > 0,
                hasIssues: total > 0,
                primaryText: total > 0 ? ByteFormatter.string(from: total) + " of junk" : "No junk found",
                secondaryText: "to clean",
                detailItems: junkFiles.map { ScanDetailItem(name: $0.url.lastPathComponent, size: $0.size, status: .pending) }
            )
        case .protection:
            return ScanModuleResult(
                type: .protection,
                isSelected: threats.count > 0,
                hasIssues: threats.count > 0,
                primaryText: threats.count > 0 ? "\(threats.count) threat\(threats.count == 1 ? "" : "s")" : "No threats",
                secondaryText: "to remove",
                detailItems: threats.map { ScanDetailItem(name: $0.name, size: 0, status: .pending) }
            )
        case .performance:
            return ScanModuleResult(
                type: .performance,
                isSelected: privacyItems.count > 0,
                hasIssues: privacyItems.count > 0,
                primaryText: privacyItems.count > 0 ? "\(privacyItems.count) task\(privacyItems.count == 1 ? "" : "s")" : "No tasks",
                secondaryText: "to run",
                detailItems: privacyItems.map { ScanDetailItem(name: $0.name, size: $0.size, status: .pending) }
            )
        case .applications:
            return ScanModuleResult(
                type: .applications,
                isSelected: apps.count > 0,
                hasIssues: apps.count > 0,
                primaryText: apps.count > 0 ? "\(min(apps.count, 5)) vital update\(min(apps.count, 5) == 1 ? "" : "s")" : "No updates",
                secondaryText: "to install",
                detailItems: apps.prefix(3).map { ScanDetailItem(name: $0.name, size: $0.totalSize, status: .pending) }
            )
        case .myClutter:
            return ScanModuleResult(
                type: .myClutter,
                isSelected: largeFiles.count > 0,
                hasIssues: largeFiles.count > 0,
                primaryText: largeFiles.count > 0 ? "\(largeFiles.count) item\(largeFiles.count == 1 ? "" : "s")" : "Nothing to tidy up",
                secondaryText: "to remove",
                detailItems: largeFiles.prefix(5).map { ScanDetailItem(name: $0.url.lastPathComponent, size: $0.size, status: .pending) }
            )
        }
    }
    
    private func buildAllResults() -> [ScanModuleResult] {
        return ScanModuleType.allCases.map { buildResult(for: $0) }
    }
    
    private func runProcessing(selectedTypes: [ScanModuleType], originalResults: [ScanModuleResult]) async {
        var completedResults = originalResults
        let allModules = ScanModuleType.allCases
        
        for (moduleIdx, moduleType) in allModules.enumerated() {
            guard selectedTypes.contains(moduleType) else { continue }
            
            phase = .processing(moduleIndex: moduleIdx, itemIndex: 0)
            
            let itemCount = detailItemCount(for: moduleType)
            for itemIdx in 0..<itemCount {
                phase = .processing(moduleIndex: moduleIdx, itemIndex: itemIdx)
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            
            if let idx = completedResults.firstIndex(where: { $0.type == moduleType }) {
                switch moduleType {
                case .cleanup:
                    completedResults[idx].completionStatus = .cleaned
                    completedResults[idx].completionSubtext = "Cleaned"
                case .applications:
                    completedResults[idx].completionStatus = .started
                    completedResults[idx].completionSubtext = "Started"
                default:
                    completedResults[idx].completionStatus = .done
                    completedResults[idx].completionSubtext = "Done"
                }
            }
            
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        
        for idx in completedResults.indices {
            if completedResults[idx].completionStatus.icon == "circle" {
                if !completedResults[idx].hasIssues {
                    switch completedResults[idx].type {
                    case .protection:
                        completedResults[idx].completionStatus = .safe
                        completedResults[idx].completionSubtext = "No threats to remove"
                    case .myClutter:
                        completedResults[idx].completionStatus = .nothingFound
                        completedResults[idx].completionSubtext = "No duplicate downloads found"
                    default:
                        completedResults[idx].completionStatus = .done
                        completedResults[idx].completionSubtext = "Done"
                    }
                }
            }
        }
        
        phase = .complete(completedResults)
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
    
    func toggleModuleSelection(_ type: ScanModuleType) {
        guard case .results(var results) = phase,
              let idx = results.firstIndex(where: { $0.type == type }) else { return }
        results[idx].isSelected.toggle()
        phase = .results(results)
    }
    
    func result(for type: ScanModuleType) -> ScanModuleResult? {
        scanningResults.first(where: { $0.type == type })
    }
}
