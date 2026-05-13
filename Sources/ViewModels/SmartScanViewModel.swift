import Foundation
import SwiftUI

@MainActor
@Observable
final class SmartScanViewModel {
    var isScanning = false
    var scanProgress: Double = 0
    var healthScore: Int = 100
    var totalJunkSize: Int64 = 0
    var threatCount: Int = 0
    var privacyItemCount: Int = 0
    var largeFileCount: Int = 0
    var scanComplete = false
    var errorMessage: String?
    
    func startSmartScan() {
        guard !isScanning else { return }
        isScanning = true
        scanComplete = false
        scanProgress = 0
        errorMessage = nil
        
        Task { @MainActor in
            await runScanPhases()
        }
    }
    
    private func runScanPhases() async {
        // Phase 1: System Junk
        let junk = await FileScanner.scanSystemJunk()
        totalJunkSize = junk.reduce(0) { $0 + $1.size }
        scanProgress = 0.25
        
        // Phase 2: Malware
        let threats = await FileScanner.scanMalware()
        threatCount = threats.count
        scanProgress = 0.5
        
        // Phase 3: Privacy
        let privacy = await FileScanner.scanPrivacyTraces()
        privacyItemCount = privacy.count
        scanProgress = 0.75
        
        // Phase 4: Large files
        let largeFiles = await FileScanner.scanLargeFiles(minSize: 50 * 1024 * 1024, maxAgeDays: 180)
        largeFileCount = largeFiles.count
        scanProgress = 1.0
        
        // Calculate health score
        var score = 100
        if totalJunkSize > 1_000_000_000 { score -= 20 }
        else if totalJunkSize > 500_000_000 { score -= 10 }
        else if totalJunkSize > 100_000_000 { score -= 5 }
        
        score -= threatCount * 15
        score -= privacyItemCount * 2
        score = max(0, min(100, score))
        
        healthScore = score
        isScanning = false
        scanComplete = true
    }
}
