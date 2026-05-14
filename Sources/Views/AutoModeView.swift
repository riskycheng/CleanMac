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
    
    // Scan progress
    var scanProgress: Double = 0.0
    var scanStage: String = ""
    var scanLog: [String] = []
    
    // Results
    var junkFiles: [JunkFile] = []
    var apps: [AppBundle] = []
    var totalJunkSize: Int64 = 0
    var totalAppSize: Int64 = 0
    
    // Cleanup progress
    var cleanProgress: Double = 0.0
    var cleanStage: String = ""
    var itemsCleaned: Int = 0
    var spaceReclaimed: Int64 = 0
    
    // Derived
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
        // Phase 1: System junk scan
        await updateScan(stage: "Initializing scan engine...", progress: 0.05)
        try? await Task.sleep(for: .milliseconds(400))
        
        await updateScan(stage: "Scanning user caches...", progress: 0.10)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Scanning system caches...", progress: 0.20)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Scanning log files...", progress: 0.30)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Scanning temporary files...", progress: 0.40)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Scanning browser data...", progress: 0.50)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Scanning Xcode artifacts...", progress: 0.60)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Scanning developer caches...", progress: 0.70)
        try? await Task.sleep(for: .milliseconds(300))
        
        // Phase 2: App scan
        await updateScan(stage: "Scanning Applications folder...", progress: 0.80)
        try? await Task.sleep(for: .milliseconds(300))
        
        await updateScan(stage: "Finding leftover files...", progress: 0.90)
        try? await Task.sleep(for: .milliseconds(300))
        
        // Actually perform scans
        let scannedJunk = await FileScanner.scanSystemJunk()
        let scannedApps = await FileScanner.scanApplications()
        
        junkFiles = scannedJunk
        apps = scannedApps
        totalJunkSize = junkFiles.reduce(0) { $0 + $1.size }
        totalAppSize = apps.reduce(0) { $0 + $1.totalSize }
        
        await updateScan(stage: "Scan complete", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(500))
        
        if !shouldStop {
            state = .reviewing
        }
    }
    
    private func updateScan(stage: String, progress: Double) async {
        await MainActor.run {
            scanStage = stage
            scanProgress = progress
            scanLog.append("[\(timeString())] \(stage)")
            if scanLog.count > 30 { scanLog.removeFirst() }
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
        
        // Clean junk
        for file in selectedJunk {
            if shouldStop { break }
            
            await updateClean(stage: "Removing \(file.name)...", progress: Double(processed) / Double(max(totalItems, 1)))
            
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                spaceReclaimed += file.size
                itemsCleaned += 1
            } catch {
                print("Failed to trash \(file.path): \(error)")
            }
            processed += 1
            try? await Task.sleep(for: .milliseconds(80))
        }
        
        // Uninstall apps
        for app in selectedApps {
            if shouldStop { break }
            
            await updateClean(stage: "Uninstalling \(app.name)...", progress: Double(processed) / Double(max(totalItems, 1)))
            
            do {
                try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
                spaceReclaimed += app.size
                itemsCleaned += 1
            } catch {
                print("Failed to trash app \(app.name): \(error)")
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
            
            processed += 1
            try? await Task.sleep(for: .milliseconds(100))
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
        for i in junkFiles.indices {
            junkFiles[i].isSelected = !allSelected
        }
    }
    
    func toggleAllApps() {
        let allSelected = apps.allSatisfy { $0.isSelected }
        for i in apps.indices {
            apps[i].isSelected = !allSelected
        }
    }
}

struct AutoModeView: View {
    @State private var viewModel = AutoModeViewModel()
    
    var body: some View {
        ZStack {
            // Background effects
            DataStreamView()
                .opacity(viewModel.state == .scanning || viewModel.state == .cleaning ? 0.15 : 0.05)
            
            ScrollView {
                VStack(spacing: 24) {
                    switch viewModel.state {
                    case .idle:
                        IdleStateView(viewModel: viewModel)
                    case .scanning:
                        ScanningStateView(viewModel: viewModel)
                    case .reviewing:
                        ReviewingStateView(viewModel: viewModel)
                    case .cleaning:
                        CleaningStateView(viewModel: viewModel)
                    case .complete:
                        CompleteStateView(viewModel: viewModel)
                    }
                }
                .padding(28)
            }
        }
    }
}

// MARK: - Idle State

struct IdleStateView: View {
    let viewModel: AutoModeViewModel
    @State private var pulse: Bool = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer().frame(height: 40)
            
            // Central orb
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(pulse ? 1.15 : 0.95)
                    .opacity(pulse ? 0.4 : 0.7)
                
                ScanningRing()
                
                VStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("AUTO")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .frame(height: 240)
            
            VStack(spacing: 12) {
                Text("Intelligent Cleanup")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("One-click scan and clean. Detects junk files,\ncaches, logs, and unused applications automatically.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    FeaturePill(icon: "trash", label: "Junk Files", color: .green)
                    FeaturePill(icon: "app.badge.checkmark", label: "App Cleanup", color: .blue)
                }
                HStack(spacing: 20) {
                    FeaturePill(icon: "globe", label: "Browser Data", color: .orange)
                    FeaturePill(icon: "terminal", label: "Dev Caches", color: .purple)
                }
            }
            
            GlowButton(
                title: "Start Intelligent Scan",
                icon: "bolt.fill",
                color: .cyan
            ) {
                viewModel.startIntelligentScan()
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct FeaturePill: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Scanning State

struct ScanningStateView: View {
    let viewModel: AutoModeViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 20)
            
            ScanningRing()
                .frame(height: 180)
            
            VStack(spacing: 8) {
                Text("Scanning System")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.scanStage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.cyan)
                    .frame(height: 20)
            }
            
            ProgressPulseBar(progress: viewModel.scanProgress, color: .cyan)
                .frame(width: 320)
            
            Text("\(Int(viewModel.scanProgress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            // Terminal log
            GlassCard(accent: .cyan) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8)
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Spacer()
                        Text("scan.log")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Divider().background(Color.white.opacity(0.06))
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(viewModel.scanLog, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.7))
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }
            .frame(maxWidth: 480)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reviewing State

struct ReviewingStateView: View {
    @Bindable var viewModel: AutoModeViewModel
    @State private var showJunk = true
    @State private var showApps = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Complete")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Found \(viewModel.totalItems) items · \(ByteFormatter.string(from: viewModel.totalSize)) reclaimable")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
            }
            
            // Summary cards
            HStack(spacing: 16) {
                SummaryCard(
                    icon: "trash.fill",
                    label: "Junk Files",
                    count: viewModel.junkFiles.count,
                    size: viewModel.totalJunkSize,
                    color: .green
                )
                SummaryCard(
                    icon: "app.fill",
                    label: "Applications",
                    count: viewModel.apps.count,
                    size: viewModel.totalAppSize,
                    color: .blue
                )
            }
            
            // Junk files section
            if !viewModel.junkFiles.isEmpty {
                DisclosureGroup(isExpanded: $showJunk) {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.junkFiles) { file in
                            JunkItemRow(file: file, color: .green)
                        }
                    }
                } label: {
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
                }
                .disclosureGroupStyle(GlassDisclosureStyle())
            }
            
            // Apps section
            if !viewModel.apps.isEmpty {
                DisclosureGroup(isExpanded: $showApps) {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.apps) { app in
                            AppItemRow(app: app, color: .blue)
                        }
                    }
                } label: {
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
                }
                .disclosureGroupStyle(GlassDisclosureStyle())
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
                
                GlowButton(
                    title: "Clean \(viewModel.totalItems) Items",
                    icon: "bolt.fill",
                    color: .cyan
                ) {
                    viewModel.startCleanup()
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

struct SummaryCard: View {
    let icon: String
    let label: String
    let count: Int
    let size: Int64
    let color: Color
    
    var body: some View {
        GlassCard(accent: color) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(count) items")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(ByteFormatter.string(from: size))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                }
                
                Spacer()
            }
        }
    }
}

struct JunkItemRow: View {
    @Bindable var file: JunkFile
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $file.isSelected)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            
            Image(systemName: categoryIcon)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.7))
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
            
            Text(ByteFormatter.string(from: file.size))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(file.isSelected ? color.opacity(0.05) : Color.clear)
        )
    }
    
    var categoryIcon: String {
        switch file.category {
        case .caches: return "archivebox"
        case .systemCaches: return "archivebox.fill"
        case .logs: return "doc.text"
        case .tempFiles: return "clock"
        case .brokenDownloads: return "arrow.down.circle"
        case .trash: return "trash"
        case .orphanedSupport: return "questionmark.folder"
        case .browserCache: return "globe"
        case .xcodeJunk: return "hammer"
        case .developerCache: return "terminal"
        case .systemLogs: return "doc.text.fill"
        case .userLogs: return "doc.text"
        }
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
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
                            .fill(Color.orange.opacity(0.1))
                    )
            }
            
            Text(ByteFormatter.string(from: app.totalSize))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(app.isSelected ? color.opacity(0.05) : Color.clear)
        )
    }
}

struct GlassDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 0) {
            Button(action: { configuration.isExpanded.toggle() }) {
                HStack {
                    configuration.label
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            
            if configuration.isExpanded {
                configuration.content
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                    )
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Cleaning State

struct CleaningStateView: View {
    let viewModel: AutoModeViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)
            
            ScanningRing()
                .frame(height: 180)
            
            VStack(spacing: 8) {
                Text("Cleaning System")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.cleanStage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .frame(height: 20)
            }
            
            ProgressPulseBar(progress: viewModel.cleanProgress, color: .green)
                .frame(width: 320)
            
            HStack(spacing: 4) {
                Text("\(Int(viewModel.cleanProgress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Text("· \(viewModel.itemsCleaned) items processed")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Live stats
            HStack(spacing: 24) {
                StatPill(label: "Items", value: "\(viewModel.itemsCleaned)", color: .cyan)
                StatPill(label: "Reclaimed", value: ByteFormatter.string(from: viewModel.spaceReclaimed), color: .green)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Complete State

struct CompleteStateView: View {
    let viewModel: AutoModeViewModel
    @State private var showCheck: Bool = false
    @State private var showStats: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)
            
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
                    .frame(width: 200, height: 200)
                
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    .frame(width: 160, height: 160)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheck ? 1 : 0.1)
                    .shadow(color: .green.opacity(0.5), radius: 20)
            }
            .frame(height: 200)
            
            VStack(spacing: 12) {
                Text("Cleanup Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your Mac has been optimized")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Result cards
            HStack(spacing: 16) {
                ResultCard(
                    icon: "trash.fill",
                    value: "\(viewModel.itemsCleaned)",
                    label: "Items Removed",
                    color: .green
                )
                ResultCard(
                    icon: "externaldrive.fill.badge.checkmark",
                    value: ByteFormatter.string(from: viewModel.spaceReclaimed),
                    label: "Space Reclaimed",
                    color: .cyan
                )
            }
            .opacity(showStats ? 1 : 0)
            .offset(y: showStats ? 0 : 20)
            
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                showCheck = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                showStats = true
            }
        }
    }
}

struct ResultCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        GlassCard(accent: color) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(minWidth: 160)
            .padding(.vertical, 8)
        }
    }
}
