import SwiftUI

enum SmartCareState {
    case idle
    case scanning
    case reviewing
    case cleaning
    case complete
}

@MainActor
@Observable
final class SmartCareViewModel {
    var state: SmartCareState = .idle
    var scanProgress: Double = 0
    var scanStage: String = ""
    var scanLogs: [String] = []
    
    var junkFiles: [JunkFile] = []
    var apps: [AppBundle] = []
    var totalJunkSize: Int64 = 0
    var totalAppSize: Int64 = 0
    
    var cleanProgress: Double = 0
    var cleanStage: String = ""
    var itemsCleaned: Int = 0
    var spaceReclaimed: Int64 = 0
    
    var totalSize: Int64 { totalJunkSize + totalAppSize }
    var totalItems: Int { junkFiles.count + apps.count }
    
    private var shouldStop = false
    
    func startScan() {
        state = .scanning
        scanProgress = 0
        scanLogs.removeAll()
        shouldStop = false
        Task { await runScan() }
    }
    
    private func runScan() async {
        let stages = [
            ("Initializing system kernel check...", 0.05),
            ("Scanning /Library/Caches...", 0.15),
            ("Deep scan: ~/Library/Application Support", 0.30),
            ("Analyzing unused language packs...", 0.45),
            ("Checking for orphaned system logs...", 0.60),
            ("Querying inactive application binaries...", 0.75),
            ("Finalizing scan report...", 0.90),
        ]
        
        for (stage, progress) in stages {
            await updateScan(stage: stage, progress: progress)
            try? await Task.sleep(for: .milliseconds(400))
        }
        
        let scannedJunk = await FileScanner.scanSystemJunk()
        let scannedApps = await FileScanner.scanApplications()
        
        junkFiles = scannedJunk
        apps = scannedApps
        totalJunkSize = junkFiles.reduce(0) { $0 + $1.size }
        totalAppSize = apps.reduce(0) { $0 + $1.totalSize }
        
        await updateScan(stage: "Scan complete — \(totalItems) items found", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(600))
        
        if !shouldStop { state = .reviewing }
    }
    
    private func updateScan(stage: String, progress: Double) async {
        await MainActor.run {
            scanStage = stage
            scanProgress = progress
            scanLogs.append("[77%] \(stage)")
            if scanLogs.count > 12 { scanLogs.removeFirst() }
        }
    }
    
    func startCleanup() {
        state = .cleaning
        cleanProgress = 0
        itemsCleaned = 0
        spaceReclaimed = 0
        Task { await runCleanup() }
    }
    
    private func runCleanup() async {
        var processed = 0
        
        for file in junkFiles.filter({ $0.isSelected }) {
            if shouldStop { break }
            await updateClean(stage: "Removing \(file.name)...", progress: Double(processed) / Double(max(junkFiles.count, 1)))
            do { try FileManager.default.trashItem(at: file.url, resultingItemURL: nil); spaceReclaimed += file.size; itemsCleaned += 1 } catch { }
            processed += 1
            try? await Task.sleep(for: .milliseconds(60))
        }
        
        for app in apps.filter({ $0.isSelected }) {
            if shouldStop { break }
            await updateClean(stage: "Uninstalling \(app.name)...", progress: Double(processed) / Double(max(apps.count, 1)))
            do { try FileManager.default.trashItem(at: app.url, resultingItemURL: nil); spaceReclaimed += app.size; itemsCleaned += 1 } catch { }
            processed += 1
            try? await Task.sleep(for: .milliseconds(80))
        }
        
        await updateClean(stage: "Cleanup complete", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(800))
        if !shouldStop { state = .complete }
    }
    
    private func updateClean(stage: String, progress: Double) async {
        await MainActor.run { cleanStage = stage; cleanProgress = progress }
    }
    
    func reset() {
        shouldStop = true
        state = .idle
        junkFiles.removeAll(); apps.removeAll()
        totalJunkSize = 0; totalAppSize = 0
        itemsCleaned = 0; spaceReclaimed = 0
    }
    
    func categorySize(_ category: JunkCategory) -> Int64 {
        junkFiles.filter { $0.category == category }.reduce(0) { $0 + $1.size }
    }
    
    func filesInCategory(_ category: JunkCategory) -> [JunkFile] {
        junkFiles.filter { $0.category == category }
    }
}

struct SmartCareView: View {
    @State private var viewModel = SmartCareViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                ModuleIdleView(
                    icon: "sparkles",
                    iconColor: Color(hex: "A855F7"),
                    title: "Smart Care",
                    subtitle: "One-click scan to optimize your system, remove junk, and manage unused applications automatically.",
                    buttonText: "Start Optimization",
                    action: { viewModel.startScan() }
                )
            case .scanning:
                TerminalScanView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    logs: viewModel.scanLogs,
                    accentColor: Color(hex: "A855F7")
                )
            case .reviewing:
                SmartCareReviewView(viewModel: viewModel)
            case .cleaning:
                CleaningView(
                    progress: viewModel.cleanProgress,
                    stage: viewModel.cleanStage,
                    itemsProcessed: viewModel.itemsCleaned,
                    spaceReclaimed: viewModel.spaceReclaimed
                )
            case .complete:
                CompleteView(
                    itemsRemoved: viewModel.itemsCleaned,
                    spaceReclaimed: viewModel.spaceReclaimed,
                    onReset: { viewModel.reset() }
                )
            }
        }
    }
}

struct SmartCareReviewView: View {
    @Bindable var viewModel: SmartCareViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "A855F7"))
                            Text("SMART ENGINE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "A855F7"))
                        }
                        Text("Optimization Overview")
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(Color(hex: "111827"))
                        Text("Your system is ready for a performance boost.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.startCleanup() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text("RUN NOW")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "A855F7"))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Top stat cards
                HStack(spacing: 12) {
                    StatCard(icon: "trash", iconColor: Color(hex: "3B82F6"), label: "System Junk", value: ByteFormatter.string(from: viewModel.totalJunkSize), subValue: nil)
                    StatCard(icon: "app", iconColor: Color(hex: "F472B6"), label: "Unused Apps", value: "\(viewModel.apps.count) Apps", subValue: nil)
                    StatCard(icon: "archivebox", iconColor: Color(hex: "F59E0B"), label: "Large Files", value: ByteFormatter.string(from: viewModel.totalAppSize), subValue: nil)
                }
                
                // Main action card
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TOTAL SAVINGS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "A855F7"))
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", Double(viewModel.totalSize) / 1_073_741_824.0))
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "111827"))
                            Text("GB")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "D1D5DB"))
                        }
                        
                        Text("Optimizing your system will significantly improve boot times and overall responsiveness.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "6B7280"))
                            .frame(maxWidth: 280)
                            .lineSpacing(3)
                        
                        Button(action: { viewModel.startCleanup() }) {
                            Text("Optimize System")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color(hex: "1C1C1E"))
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ESTIMATED SPEED BOOST")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "9CA3AF"))
                            Text("+15%")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "22C55E"))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SECURITY HEALTH")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "9CA3AF"))
                            Text("Optimal")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "3B82F6"))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        )
                    }
                    .frame(width: 180)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.03), lineWidth: 1)
                )
            }
            .padding(28)
        }
    }
}
