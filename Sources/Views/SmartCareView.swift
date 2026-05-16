import SwiftUI

enum SmartCareState {
    case idle
    case scanning
    case reviewing
    case cleaning
    case complete
}

enum SmartCareDetail: Hashable {
    case junk
    case unusedApps
    case largeFiles
    case duplicates
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
    
    var largeFiles: [LargeFile] = []
    var duplicateGroups: [DuplicateGroup] = []
    
    var totalSize: Int64 { totalJunkSize + totalAppSize + largeFileSize + duplicateWaste }
    var totalItems: Int { junkFiles.count + apps.count + largeFiles.count }
    
    var largeFileSize: Int64 { largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.allocatedSize } }
    var duplicateWaste: Int64 { duplicateGroups.filter { $0.isSelected }.reduce(0) { $0 + $1.totalWastedSpace } }
    
    var detailMode: SmartCareDetail? = nil
    
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
        
        let scannedJunk = await FileScanner.smartScanJunk()
        let scannedApps = await AppIntelligenceEngine.scanAll()
        
        junkFiles = scannedJunk
        apps = scannedApps
        totalJunkSize = junkFiles.reduce(0) { $0 + $1.size }
        totalAppSize = apps.reduce(0) { $0 + $1.totalSize }
        
        await updateScan(stage: "Scan complete — \(totalItems) items found", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(600))
        
        if !shouldStop { state = .reviewing }
        
        // Background scan for large files and duplicates
        Task { await runBackgroundScans() }
    }
    
    private func updateScan(stage: String, progress: Double) async {
        await MainActor.run {
            scanStage = stage
            scanProgress = progress
            scanLogs.append("[\(Int(progress * 100))%] \(stage)")
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
        let selectedJunk = junkFiles.filter { $0.isSelected }
        let selectedApps = apps.filter { $0.isSelected }
        let totalToClean = selectedJunk.count + selectedApps.count
        var processed = 0
        
        // Clean junk files
        var remainingJunk: [JunkFile] = []
        for file in junkFiles {
            if file.isSelected {
                if shouldStop { break }
                await updateClean(stage: "Removing \(file.name)...", progress: Double(processed) / Double(max(totalToClean, 1)))
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                    spaceReclaimed += file.size
                    itemsCleaned += 1
                } catch {
                    print("[CleanMac] Failed to trash junk \(file.path): \(error)")
                    remainingJunk.append(file)
                }
                processed += 1
                try? await Task.sleep(for: .milliseconds(60))
            } else {
                remainingJunk.append(file)
            }
        }
        await MainActor.run { junkFiles = remainingJunk }
        totalJunkSize = junkFiles.reduce(0) { $0 + $1.size }
        
        // Clean apps (bundle + all leftovers)
        var remainingApps: [AppBundle] = []
        for app in apps {
            if app.isSelected {
                if shouldStop { break }
                await updateClean(stage: "Uninstalling \(app.name)...", progress: Double(processed) / Double(max(totalToClean, 1)))
                do {
                    try FileManager.default.trashItem(at: app.url, resultingItemURL: nil)
                    for leftover in app.leftoverFiles {
                        do { try FileManager.default.trashItem(at: leftover, resultingItemURL: nil) }
                        catch { print("[CleanMac] Failed to trash leftover \(leftover.path): \(error)") }
                    }
                    spaceReclaimed += app.totalSize
                    itemsCleaned += 1
                } catch {
                    print("[CleanMac] Failed to trash app \(app.url.path): \(error)")
                    remainingApps.append(app)
                }
                processed += 1
                try? await Task.sleep(for: .milliseconds(80))
            } else {
                remainingApps.append(app)
            }
        }
        await MainActor.run { apps = remainingApps }
        totalAppSize = apps.reduce(0) { $0 + $1.totalSize }
        
        await updateClean(stage: "Cleanup complete — \(itemsCleaned) items removed", progress: 1.0)
        try? await Task.sleep(for: .milliseconds(800))
        if !shouldStop { state = .complete }
    }
    
    private func updateClean(stage: String, progress: Double) async {
        await MainActor.run { cleanStage = stage; cleanProgress = progress }
    }
    
    func showDetail(_ detail: SmartCareDetail) {
        detailMode = detail
    }
    
    func closeDetail() {
        detailMode = nil
    }
    
    private func runBackgroundScans() async {
        // Large files
        let scannedLarge = await LargeFileScanner.scan()
        await MainActor.run { largeFiles = scannedLarge }
        
        // Duplicates (can be slow, so run after large files)
        let scannedDups = await DuplicateScanner.scan()
        await MainActor.run { duplicateGroups = scannedDups }
    }
    
    func reset() {
        shouldStop = true
        state = .idle
        detailMode = nil
        junkFiles.removeAll(); apps.removeAll()
        largeFiles.removeAll(); duplicateGroups.removeAll()
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

struct SmartCareBackgroundView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Large curved shape top-right
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    path.move(to: CGPoint(x: w * 0.5, y: 0))
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.45),
                        control1: CGPoint(x: w * 0.85, y: h * 0.05),
                        control2: CGPoint(x: w * 1.05, y: h * 0.25)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.6, y: h * 0.7),
                        control1: CGPoint(x: w * 0.95, y: h * 0.6),
                        control2: CGPoint(x: w * 0.75, y: h * 0.8)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.35, y: h * 0.35),
                        control1: CGPoint(x: w * 0.45, y: h * 0.6),
                        control2: CGPoint(x: w * 0.25, y: h * 0.5)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.5, y: 0),
                        control1: CGPoint(x: w * 0.45, y: h * 0.2),
                        control2: CGPoint(x: w * 0.55, y: h * 0.05)
                    )
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.2)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                
                // Secondary curved shape bottom-right
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    path.move(to: CGPoint(x: w * 0.4, y: h))
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.65),
                        control1: CGPoint(x: w * 0.7, y: h * 0.95),
                        control2: CGPoint(x: w * 0.95, y: h * 0.8)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.75, y: h * 0.4),
                        control1: CGPoint(x: w * 0.95, y: h * 0.5),
                        control2: CGPoint(x: w * 0.85, y: h * 0.35)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.55, y: h * 0.55),
                        control1: CGPoint(x: w * 0.65, y: h * 0.45),
                        control2: CGPoint(x: w * 0.5, y: h * 0.5)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.4, y: h),
                        control1: CGPoint(x: w * 0.6, y: h * 0.75),
                        control2: CGPoint(x: w * 0.45, y: h * 0.9)
                    )
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct SmartCareView: View {
    @State private var viewModel = SmartCareViewModel()
    
    var body: some View {
        ZStack {
            SmartCareBackgroundView()
            
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
                if let detail = viewModel.detailMode {
                    SmartCareDetailView(viewModel: viewModel, detail: detail)
                } else {
                    SmartCareReviewView(viewModel: viewModel)
                }
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
            VStack(spacing: 16) {
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
                            .font(.system(size: 28, weight: .black))
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
                
                // Top stat cards — clickable
                // Top stat cards — 4 columns
                HStack(spacing: 12) {
                    ClickableStatCard(
                        icon: "trash",
                        iconColor: Color(hex: "3B82F6"),
                        label: "System Junk",
                        value: ByteFormatter.string(from: viewModel.totalJunkSize)
                    ) {
                        viewModel.showDetail(.junk)
                    }
                    
                    let unusedCount = viewModel.apps.filter { $0.isUnused }.count
                    ClickableStatCard(
                        icon: "app",
                        iconColor: Color(hex: "F472B6"),
                        label: "Unused Apps",
                        value: "\(unusedCount) Apps"
                    ) {
                        viewModel.showDetail(.unusedApps)
                    }
                    
                    let largeSize = viewModel.largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.allocatedSize }
                    ClickableStatCard(
                        icon: "archivebox",
                        iconColor: Color(hex: "F59E0B"),
                        label: "Large Files",
                        value: ByteFormatter.string(from: largeSize)
                    ) {
                        viewModel.showDetail(.largeFiles)
                    }
                    
                    let dupWaste = viewModel.duplicateGroups.filter { $0.isSelected }.reduce(0) { $0 + $1.totalWastedSpace }
                    ClickableStatCard(
                        icon: "doc.on.doc",
                        iconColor: Color(hex: "22C55E"),
                        label: "Duplicates",
                        value: ByteFormatter.string(from: dupWaste)
                    ) {
                        viewModel.showDetail(.duplicates)
                    }
                }
                
                // Main action area
                HStack(alignment: .top, spacing: 16) {
                    // Left: Total savings
                    VStack(alignment: .leading, spacing: 20) {
                        Text("TOTAL SAVINGS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "A855F7"))
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", Double(viewModel.totalSize) / 1_073_741_824.0))
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "111827"))
                            Text("GB")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "D1D5DB"))
                                .padding(.bottom, 8)
                        }
                        
                        Text("Optimizing your system will significantly improve boot times and overall responsiveness.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "6B7280"))
                            .frame(maxWidth: 300)
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
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    
                    // Right: Side cards
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ESTIMATED SPEED BOOST")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "9CA3AF"))
                            Text("+15%")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "22C55E"))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.03), lineWidth: 1)
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SECURITY HEALTH")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "9CA3AF"))
                            Text("Optimal")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "3B82F6"))
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.black.opacity(0.03), lineWidth: 1)
                        )
                    }
                    .frame(width: 200)
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

// MARK: - Clickable Stat Card

struct ClickableStatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "D1D5DB"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "9CA3AF"))
                    
                    Text(value)
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHovered ? iconColor.opacity(0.4) : Color.black.opacity(0.03), lineWidth: isHovered ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Detail Views

struct SmartCareDetailView: View {
    @Bindable var viewModel: SmartCareViewModel
    let detail: SmartCareDetail
    
    var title: String {
        switch detail {
        case .junk: return "System Junk"
        case .unusedApps: return "Unused Apps"
        case .largeFiles: return "Large Files"
        case .duplicates: return "Duplicates"
        }
    }
    
    var icon: String {
        switch detail {
        case .junk: return "trash"
        case .unusedApps: return "app"
        case .largeFiles: return "archivebox"
        case .duplicates: return "doc.on.doc"
        }
    }
    
    var accentColor: Color {
        switch detail {
        case .junk: return Color(hex: "3B82F6")
        case .unusedApps: return Color(hex: "F472B6")
        case .largeFiles: return Color(hex: "F59E0B")
        case .duplicates: return Color(hex: "22C55E")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { viewModel.closeDetail() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Back")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "6B7280"))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accentColor)
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(accentColor)
                }
                
                Spacer()
                
                Button(action: { viewModel.startCleanup() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("CLEAN")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(accentColor)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Content
            switch detail {
            case .junk:
                JunkDetailList(files: viewModel.junkFiles)
            case .unusedApps:
                AppDetailList(apps: viewModel.apps.filter { $0.isUnused })
            case .largeFiles:
                LargeFileDetailView(files: viewModel.largeFiles)
            case .duplicates:
                DuplicateDetailView(groups: viewModel.duplicateGroups)
            }
        }
    }
}

struct JunkDetailList: View {
    let files: [JunkFile]
    
    var body: some View {
        List(files) { file in
            JunkFileRow(file: file)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct JunkFileRow: View {
    let file: JunkFile
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(file.isSelected ? Color(hex: "3B82F6") : Color(hex: "D1D5DB"))
                .contentTransition(.symbolEffect(.replace))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "374151"))
                Text(file.path)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(ByteFormatter.string(from: file.size))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "9CA3AF"))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isHovered ? Color(hex: "F3F4F6") : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
        .onTapGesture {
            file.isSelected.toggle()
        }
    }
}

struct AppDetailList: View {
    let apps: [AppBundle]
    
    var body: some View {
        List(apps) { app in
            AppBundleRow(app: app)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct AppBundleRow: View {
    let app: AppBundle
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: app.isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(app.isSelected ? Color(hex: "3B82F6") : Color(hex: "D1D5DB"))
                .contentTransition(.symbolEffect(.replace))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "374151"))
                Text(app.bundleID)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormatter.string(from: app.totalSize))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "9CA3AF"))
                if let days = app.daysSinceUsed {
                    Text("\(Int(days))d unused")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "D1D5DB"))
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isHovered ? Color(hex: "F3F4F6") : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
        .onTapGesture {
            app.isSelected.toggle()
        }
    }
}


// MARK: - Large File Detail View

struct LargeFileDetailView: View {
    let files: [LargeFile]
    
    var body: some View {
        VStack(spacing: 16) {
            if !files.isEmpty {
                AccessTimeHeatmapView(buckets: LargeFileScanner.accessTimeBuckets(files))
                    .padding(.horizontal, 28)
            }
            
            List(files) { file in
                LargeFileRow(file: file)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct LargeFileRow: View {
    let file: LargeFile
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(file.isSelected ? Color(hex: "3B82F6") : Color(hex: "D1D5DB"))
                .contentTransition(.symbolEffect(.replace))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "374151"))
                Text(file.path)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormatter.string(from: file.allocatedSize))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "9CA3AF"))
                Text(file.accessBucket)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: file.accessBucketColor))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isHovered ? Color(hex: "F3F4F6") : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
        .onTapGesture {
            file.isSelected.toggle()
        }
    }
}

// MARK: - Duplicate Detail View

struct DuplicateDetailView: View {
    let groups: [DuplicateGroup]
    
    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: 12) {
                ForEach(groups) { group in
                    DuplicateGroupCard(group: group)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
        }
    }
}

struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: group.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(group.isSelected ? Color(hex: "22C55E") : Color(hex: "D1D5DB"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.files.count) copies · \(ByteFormatter.string(from: group.size)) each")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "374151"))
                    Text("Wasted: \(ByteFormatter.string(from: group.totalWastedSpace))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "22C55E"))
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                group.isSelected.toggle()
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(group.files) { file in
                        HStack(spacing: 8) {
                            Image(systemName: file.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 10))
                                .foregroundColor(file.isSelected ? Color(hex: "22C55E") : Color(hex: "D1D5DB"))
                            
                            Text(file.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "6B7280"))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(file.path)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(hex: "9CA3AF"))
                                .lineLimit(1)
                                .frame(maxWidth: 200, alignment: .trailing)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            file.isSelected.toggle()
                        }
                    }
                }
                .padding(.leading, 26)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}
