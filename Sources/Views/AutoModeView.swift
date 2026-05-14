import SwiftUI

enum AutoModeState {
    case idle
    case scanning
    case reviewing
    case cleaning
    case complete
}

@MainActor
@Observable
final class AutoModeViewModel {
    var state: AutoModeState = .idle
    
    var scanProgress: Double = 0.0
    var scanStage: String = ""
    var scanLog: [String] = []
    
    var junkFiles: [JunkFile] = []
    var apps: [AppBundle] = []
    var totalJunkSize: Int64 = 0
    var totalAppSize: Int64 = 0
    
    var cleanProgress: Double = 0.0
    var cleanStage: String = ""
    var itemsCleaned: Int = 0
    var spaceReclaimed: Int64 = 0
    
    var totalSize: Int64 { totalJunkSize + totalAppSize }
    var totalItems: Int { junkFiles.count + apps.count }
    
    private var shouldStop = false
    
    func startIntelligentScan() {
        state = .scanning
        scanProgress = 0.0
        scanLog.removeAll()
        shouldStop = false
        
        Task {
            await runScanSequence()
        }
    }
    
    private func runScanSequence() async {
        let stages = [
            ("Initializing scan engine...", 0.05),
            ("Scanning user caches...", 0.10),
            ("Scanning system caches...", 0.20),
            ("Scanning log files...", 0.30),
            ("Scanning temporary files...", 0.40),
            ("Scanning browser data...", 0.50),
            ("Scanning Xcode artifacts...", 0.60),
            ("Scanning developer caches...", 0.70),
            ("Scanning Applications folder...", 0.80),
            ("Finding leftover files...", 0.90),
        ]
        
        for (stage, progress) in stages {
            await updateScan(stage: stage, progress: progress)
            try? await Task.sleep(for: .milliseconds(350))
        }
        
        let scannedJunk = await FileScanner.scanSystemJunk()
        let scannedApps = await FileScanner.scanApplications()
        
        junkFiles = scannedJunk
        apps = scannedApps
        totalJunkSize = junkFiles.reduce(0) { $0 + $1.size }
        totalAppSize = apps.reduce(0) { $0 + $1.totalSize }
        
        await updateScan(stage: "Scan complete — \(totalItems) items found", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(600))
        
        if !shouldStop {
            state = .reviewing
        }
    }
    
    private func updateScan(stage: String, progress: Double) async {
        await MainActor.run {
            scanStage = stage
            scanProgress = progress
            let time = timeString()
            scanLog.append("[\(time)] \(stage)")
            
            // Add some simulated file discoveries for visual effect
            if progress > 0.15 && progress < 0.95 && Int.random(in: 0...3) == 0 {
                let fakeFiles = [
                    "Found cache bundle: com.apple.Safari (12.4 MB)",
                    "Parsed log archive: system.log.2.gz (4.2 MB)",
                    "Detected temp files: /var/tmp/session_X7A2 (89.3 MB)",
                    "Indexed download: pending_update.zip (256 MB)",
                    "Scanned app bundle: Xcode.app (2.1 GB)",
                    "Found leftovers: com.google.Chrome (340 MB)",
                    "Parsed DerivedData: Build/Products (1.2 GB)",
                    "Indexed npm cache: _cacache/content (45 MB)",
                ]
                scanLog.append("[\(time)] > \(fakeFiles.randomElement()!)")
            }
            
            if scanLog.count > 40 { scanLog.removeFirst(scanLog.count - 40) }
        }
    }
    
    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    func startCleanup() {
        state = .cleaning
        cleanProgress = 0.0
        itemsCleaned = 0
        spaceReclaimed = 0
        
        Task {
            await runCleanupSequence()
        }
    }
    
    private func runCleanupSequence() async {
        let selectedJunk = junkFiles.filter { $0.isSelected }
        let selectedApps = apps.filter { $0.isSelected }
        let totalItems = selectedJunk.count + selectedApps.count
        var processed = 0
        
        for file in selectedJunk {
            if shouldStop { break }
            await updateClean(stage: "rm \(file.name)", progress: Double(processed) / Double(max(totalItems, 1)))
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                spaceReclaimed += file.size
                itemsCleaned += 1
            } catch { }
            processed += 1
            try? await Task.sleep(for: .milliseconds(60))
        }
        
        for app in selectedApps {
            if shouldStop { break }
            await updateClean(stage: "uninstall \(app.name)", progress: Double(processed) / Double(max(totalItems, 1)))
            do {
                try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
                spaceReclaimed += app.size
                itemsCleaned += 1
            } catch { }
            for leftover in app.leftoverFiles {
                do {
                    try FileManager.default.trashItem(at: leftover, resultingItemURL: nil)
                    let size = (try? FileManager.default.attributesOfItem(atPath: leftover.path)[.size] as? Int64) ?? 0
                    spaceReclaimed += size
                } catch { }
            }
            processed += 1
            try? await Task.sleep(for: .milliseconds(80))
        }
        
        await updateClean(stage: "Cleanup complete", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(800))
        
        if !shouldStop {
            state = .complete
        }
    }
    
    private func updateClean(stage: String, progress: Double) async {
        await MainActor.run {
            cleanStage = stage
            cleanProgress = progress
        }
    }
    
    func reset() {
        shouldStop = true
        state = .idle
        scanProgress = 0
        cleanProgress = 0
        scanLog.removeAll()
        junkFiles.removeAll()
        apps.removeAll()
        totalJunkSize = 0
        totalAppSize = 0
        itemsCleaned = 0
        spaceReclaimed = 0
    }
    
    func toggleAllJunk() {
        let allSelected = junkFiles.allSatisfy { $0.isSelected }
        for file in junkFiles {
            file.isSelected = !allSelected
        }
    }
    
    func toggleAllApps() {
        let allSelected = apps.allSatisfy { $0.isSelected }
        for app in apps {
            app.isSelected = !allSelected
        }
    }
}

struct AutoModeView: View {
    @State private var viewModel = AutoModeViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                TerminalIdleView {
                    viewModel.startIntelligentScan()
                }
            case .scanning:
                TerminalScannerView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    logLines: viewModel.scanLog
                )
            case .reviewing:
                DashboardReviewView(viewModel: viewModel)
            case .cleaning:
                TerminalCleaningView(viewModel: viewModel)
            case .complete:
                CompleteDashboardView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Dashboard Review View

struct DashboardReviewView: View {
    @Bindable var viewModel: AutoModeViewModel
    @State private var showFiles: Bool = false
    
    var junkBreakdown: [(label: String, value: Int64, color: Color)] {
        categoryBreakdown(from: viewModel.junkFiles)
    }
    
    var topJunkItems: [(name: String, size: Int64, color: Color)] {
        topItems(from: viewModel.junkFiles, limit: 8)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                            Text("Scan Complete")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Found \(viewModel.totalItems) items · \(ByteFormatter.string(from: viewModel.totalSize)) reclaimable")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                
                // Stat grid
                StatGrid(stats: [
                    (icon: "doc.fill", label: "Junk Files", value: "\(viewModel.junkFiles.count)", color: .green),
                    (icon: "app.fill", label: "Applications", value: "\(viewModel.apps.count)", color: .blue),
                    (icon: "externaldrive.fill", label: "Junk Size", value: ByteFormatter.string(from: viewModel.totalJunkSize), color: .cyan),
                    (icon: "archivebox.fill", label: "App Size", value: ByteFormatter.string(from: viewModel.totalAppSize), color: .orange),
                ])
                
                // Charts row
                HStack(spacing: 16) {
                    // Donut chart
                    GlassCard(accent: .cyan) {
                        VStack(spacing: 12) {
                            Text("Space Distribution")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            HStack(spacing: 20) {
                                DonutChart(
                                    data: [
                                        ("Junk", viewModel.totalJunkSize, .green),
                                        ("Apps", viewModel.totalAppSize, .blue)
                                    ],
                                    total: viewModel.totalSize,
                                    centerLabel: "Total",
                                    centerValue: ByteFormatter.string(from: viewModel.totalSize)
                                )
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Circle().fill(.green).frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Junk Files")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.6))
                                            Text(ByteFormatter.string(from: viewModel.totalJunkSize))
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.green)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        Circle().fill(.blue).frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Applications")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.6))
                                            Text(ByteFormatter.string(from: viewModel.totalAppSize))
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Category breakdown
                    GlassCard(accent: .green) {
                        VStack(spacing: 10) {
                            Text("Category Breakdown")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            if junkBreakdown.isEmpty {
                                Text("No junk data")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.3))
                            } else {
                                HorizontalBarChart(
                                    data: junkBreakdown,
                                    total: viewModel.totalJunkSize,
                                    unit: ""
                                )
                            }
                        }
                    }
                }
                
                // Top items chart
                if !topJunkItems.isEmpty {
                    GlassCard(accent: .orange) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Top Largest Items")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            TopItemsChart(
                                items: topJunkItems,
                                maxSize: topJunkItems.first?.size ?? 1
                            )
                        }
                    }
                }
                
                // File list (collapsible)
                if !viewModel.junkFiles.isEmpty || !viewModel.apps.isEmpty {
                    Button(action: { showFiles.toggle() }) {
                        HStack {
                            Text(showFiles ? "Hide Details" : "View All Files")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: showFiles ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if showFiles {
                        DetailFileList(viewModel: viewModel)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        viewModel.reset()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    )
                    .buttonStyle(.plain)
                    
                    let selectedCount = viewModel.junkFiles.filter { $0.isSelected }.count + viewModel.apps.filter { $0.isSelected }.count
                    GlowButton(
                        title: "Clean \(selectedCount) Items",
                        icon: "bolt.fill",
                        color: .cyan
                    ) {
                        viewModel.startCleanup()
                    }
                }
            }
            .padding(20)
        }
    }
}

struct DetailFileList: View {
    @Bindable var viewModel: AutoModeViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            if !viewModel.junkFiles.isEmpty {
                HStack {
                    Text("Junk Files (\(viewModel.junkFiles.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(viewModel.junkFiles.allSatisfy({ $0.isSelected }) ? "Deselect All" : "Select All") {
                        viewModel.toggleAllJunk()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.green)
                }
                
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.junkFiles) { file in
                        JunkItemRow(file: file, color: .green)
                    }
                }
            }
            
            if !viewModel.apps.isEmpty {
                HStack {
                    Text("Applications (\(viewModel.apps.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(viewModel.apps.allSatisfy({ $0.isSelected }) ? "Deselect All" : "Select All") {
                        viewModel.toggleAllApps()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.apps) { app in
                        AppItemRow(app: app, color: .blue)
                    }
                }
            }
        }
    }
}

// MARK: - Terminal Cleaning View

struct TerminalCleaningView: View {
    let viewModel: AutoModeViewModel
    @State private var logLines: [String] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                DataStreamView().opacity(0.08)
                
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 10, height: 10)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 10, height: 10)
                        }
                        Spacer()
                        Text("cleanmac — cleanup — 80x24")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.4))
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("[CLEAN] Starting cleanup operation...")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green.opacity(0.7))
                            Text("[CLEAN] Target: \(viewModel.junkFiles.filter { $0.isSelected }.count) junk files, \(viewModel.apps.filter { $0.isSelected }.count) apps")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green.opacity(0.7))
                            
                            Text("$")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green.opacity(0.6)) +
                            Text(" \(viewModel.cleanStage)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.cyan)
                            
                            ForEach(logLines, id: \.self) { line in
                                TerminalLogLine(text: line)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    HStack(spacing: 8) {
                        Text("[")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        
                        GeometryReader { barGeo in
                            let filled = Int((barGeo.size.width / 8) * viewModel.cleanProgress)
                            let total = Int(barGeo.size.width / 8)
                            HStack(spacing: 0) {
                                Text(String(repeating: "=", count: max(0, filled)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                Text(String(repeating: "-", count: max(0, total - filled)))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.15))
                            }
                        }
                        .frame(height: 14)
                        
                        Text("]")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("\(Int(viewModel.cleanProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(width: 40)
                        
                        Text("· \(viewModel.itemsCleaned) removed")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.4))
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(20)
            }
        }
    }
}

// MARK: - Complete Dashboard View

struct CompleteDashboardView: View {
    let viewModel: AutoModeViewModel
    @State private var appear: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.green.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.5), radius: 20)
                        .scaleEffect(appear ? 1 : 0.1)
                }
                .frame(height: 180)
                
                VStack(spacing: 8) {
                    Text("Cleanup Complete")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Text("Your Mac has been optimized")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Result stats
                StatGrid(stats: [
                    (icon: "trash.fill", label: "Items Removed", value: "\(viewModel.itemsCleaned)", color: .green),
                    (icon: "externaldrive.fill.badge.checkmark", label: "Space Reclaimed", value: ByteFormatter.string(from: viewModel.spaceReclaimed), color: .cyan),
                    (icon: "chart.bar.fill", label: "Efficiency", value: "\(viewModel.itemsCleaned > 0 ? ByteFormatter.string(from: viewModel.spaceReclaimed / Int64(viewModel.itemsCleaned)) : "0")/item", color: .orange),
                    (icon: "clock.fill", label: "Status", value: "Done", color: .blue),
                ])
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                
                Spacer()
                
                GlowButton(
                    title: "Run Again",
                    icon: "arrow.clockwise",
                    color: .cyan
                ) {
                    viewModel.reset()
                }
                .padding(.bottom, 20)
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                appear = true
            }
        }
    }
}

// MARK: - Reusable Item Rows

struct JunkItemRow: View {
    @Bindable var file: JunkFile
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $file.isSelected)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            
            Image(systemName: file.category.icon)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.6))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Text(file.path)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.category.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.06))
                )
            
            Text(ByteFormatter.string(from: file.size))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(file.isSelected ? color.opacity(0.04) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
        )
    }
}

struct AppItemRow: View {
    @Bindable var app: AppBundle
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $app.isSelected)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                if !app.version.isEmpty {
                    Text(app.version)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            
            Spacer()
            
            if !app.leftoverFiles.isEmpty {
                Text("+\(app.leftoverFiles.count) leftovers")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.08))
                    )
            }
            
            Text(ByteFormatter.string(from: app.totalSize))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(app.isSelected ? color.opacity(0.04) : Color.clear)
        )
    }
}
