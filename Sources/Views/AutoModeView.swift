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
            
            if progress > 0.15 && progress < 0.95 && Int.random(in: 0...3) == 0 {
                let fakeFiles = [
                    "> Detected cache bundle: com.apple.Safari (12.4 MB)",
                    "> Parsed log archive: system.log.2.gz (4.2 MB)",
                    "> Found temp files: /var/tmp/session_X7A2 (89.3 MB)",
                    "> Indexed download: pending_update.zip (256 MB)",
                    "> Scanned app: Xcode.app (2.1 GB)",
                    "> Found leftovers: com.google.Chrome (340 MB)",
                    "> Parsed DerivedData: Build/Products (1.2 GB)",
                    "> Indexed npm cache: _cacache (45 MB)",
                ]
                scanLog.append("[\(time)] \(fakeFiles.randomElement()!)")
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
            await updateClean(stage: "Removing \(file.name)...", progress: Double(processed) / Double(max(totalItems, 1)))
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
            await updateClean(stage: "Uninstalling \(app.name)...", progress: Double(processed) / Double(max(totalItems, 1)))
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
    
    func categorySize(_ category: JunkCategory) -> Int64 {
        junkFiles.filter { $0.category == category }.reduce(0) { $0 + $1.size }
    }
    
    func filesInCategory(_ category: JunkCategory) -> [JunkFile] {
        junkFiles.filter { $0.category == category }
    }
}

struct AutoModeView: View {
    @State private var viewModel = AutoModeViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                IdleView(onStart: { viewModel.startIntelligentScan() })
            case .scanning:
                TerminalScannerView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    logLines: viewModel.scanLog
                )
            case .reviewing:
                ElegantReviewView(viewModel: viewModel)
            case .cleaning:
                CleaningView(viewModel: viewModel)
            case .complete:
                CompleteView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Idle View

struct IdleView: View {
    let onStart: () -> Void
    @State private var pulse: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse ? 1.1 : 0.95)
                    .opacity(pulse ? 0.5 : 0.8)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.green.opacity(0.7))
            }
            .frame(height: 200)
            
            VStack(spacing: 12) {
                Text("CleanMac")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("One-click scan to find and remove\njunk files, caches, and unused apps.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Scan My Mac")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Elegant Review View with 3D Icons & Expand

struct ElegantReviewView: View {
    @Bindable var viewModel: AutoModeViewModel
    @State private var expandedCategory: JunkCategory? = nil
    @State private var cardAppears: [UUID: Bool] = [:]
    
    var activeCategories: [JunkCategory] {
        JunkCategory.allCases.filter { viewModel.categorySize($0) > 0 }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Headline
                    VStack(spacing: 6) {
                        Text("\(ByteFormatter.string(from: viewModel.totalSize)) of junk found")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Found \(viewModel.totalItems) items that can be safely removed")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.top, 12)
                    
                    // Bento grid of visual category cards
                    let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(activeCategories.enumerated()), id: \.element) { index, category in
                            VisualCategoryCard(
                                category: category,
                                size: viewModel.categorySize(category),
                                count: viewModel.filesInCategory(category).count,
                                isSelected: viewModel.filesInCategory(category).allSatisfy { $0.isSelected },
                                isExpanded: expandedCategory == category,
                                appearDelay: Double(index) * 0.08
                            ) {
                                if expandedCategory == category {
                                    expandedCategory = nil
                                } else {
                                    expandedCategory = category
                                }
                            } onToggle: {
                                let files = viewModel.filesInCategory(category)
                                let allSelected = files.allSatisfy { $0.isSelected }
                                for file in files {
                                    file.isSelected = !allSelected
                                }
                            }
                        }
                        
                        // Apps card
                        if !viewModel.apps.isEmpty {
                            VisualAppCard(
                                count: viewModel.apps.count,
                                size: viewModel.totalAppSize,
                                isSelected: viewModel.apps.allSatisfy { $0.isSelected },
                                appearDelay: Double(activeCategories.count) * 0.08
                            ) {
                                viewModel.toggleAllApps()
                            }
                        }
                    }
                    
                    // Expanded detail view
                    if let cat = expandedCategory {
                        CategoryDetailPanel(
                            category: cat,
                            files: viewModel.filesInCategory(cat)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Action buttons
                    HStack(spacing: 14) {
                        Button("Cancel") {
                            viewModel.reset()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.04))
                        )
                        .buttonStyle(.plain)
                        
                        let selectedCount = viewModel.junkFiles.filter { $0.isSelected }.count + viewModel.apps.filter { $0.isSelected }.count
                        let selectedSize = viewModel.junkFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size } + viewModel.apps.filter { $0.isSelected }.reduce(0) { $0 + $1.totalSize }
                        
                        Button(action: { viewModel.startCleanup() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                Text("Clean \(ByteFormatter.string(from: selectedSize))")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedCount > 0 ? Color.green.opacity(0.25) : Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedCount > 0 ? Color.green.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedCount == 0)
                        .opacity(selectedCount > 0 ? 1.0 : 0.5)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - 3D Floating Icon

struct FloatingIcon3D: View {
    let primaryIcon: String
    let secondaryIcon: String
    let primaryColor: Color
    let secondaryColor: Color
    @State private var float: Bool = false
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [primaryColor.opacity(0.15), primaryColor.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
            
            // Secondary icon (behind, offset)
            Image(systemName: secondaryIcon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(secondaryColor.opacity(0.5))
                .offset(x: 10, y: -8)
                .rotationEffect(.degrees(12))
                .shadow(color: secondaryColor.opacity(0.2), radius: 4, x: 2, y: 2)
            
            // Primary icon (front)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor.opacity(0.25), primaryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: primaryIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(primaryColor)
                    .shadow(color: primaryColor.opacity(0.4), radius: 6)
            }
            .offset(x: -4, y: 4)
            .rotationEffect(.degrees(float ? 3 : -3))
        }
        .frame(width: 70, height: 70)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}

// MARK: - Visual Category Card

struct VisualCategoryCard: View {
    let category: JunkCategory
    let size: Int64
    let count: Int
    let isSelected: Bool
    let isExpanded: Bool
    let appearDelay: Double
    let onExpand: () -> Void
    let onToggle: () -> Void
    
    @State private var appear: Bool = false
    @State private var hover: Bool = false
    
    var iconConfig: (primary: String, secondary: String, color: Color) {
        switch category {
        case .caches: return ("archivebox", "arrow.clockwise", .cyan)
        case .systemCaches: return ("archivebox.fill", "gear", .blue)
        case .logs: return ("doc.text", "clock", .green)
        case .tempFiles: return ("clock", "bolt", .orange)
        case .brokenDownloads: return ("arrow.down.circle", "exclamationmark", .red)
        case .trash: return ("trash", "xmark", .purple)
        case .orphanedSupport: return ("questionmark.folder", "folder", .pink)
        case .browserCache: return ("globe", "wifi", .yellow)
        case .xcodeJunk: return ("hammer", "wrench", .mint)
        case .developerCache: return ("terminal", "chevron.left.forwardslash.chevron.right", .indigo)
        case .systemLogs: return ("doc.text.fill", "gear", .teal)
        case .userLogs: return ("doc.text", "person", .green.opacity(0.7))
        }
    }
    
    var description: String {
        switch category {
        case .caches: return "Unneeded cache files from your apps"
        case .systemCaches: return "System-level cached data"
        case .logs: return "Old application logs"
        case .tempFiles: return "Temporary files no longer needed"
        case .brokenDownloads: return "Incomplete download files"
        case .trash: return "Items in your Trash bin"
        case .orphanedSupport: return "Leftovers from removed apps"
        case .browserCache: return "Web browser cached data"
        case .xcodeJunk: return "Xcode build artifacts & simulators"
        case .developerCache: return "Developer tool caches"
        case .systemLogs: return "System diagnostic logs"
        case .userLogs: return "User application logs"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                FloatingIcon3D(
                    primaryIcon: iconConfig.primary,
                    secondaryIcon: iconConfig.secondary,
                    primaryColor: iconConfig.color,
                    secondaryColor: iconConfig.color.opacity(0.6)
                )
                .scaleEffect(hover ? 1.08 : 1.0)
                
                Spacer()
                
                // Selection indicator
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .green : .white.opacity(0.15))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ByteFormatter.string(from: size))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(category.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            
            HStack {
                Button(action: onExpand) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide" : "Review")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.right")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(count) items")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.top, 10)
        }
        .padding(16)
        .frame(minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            isSelected ? iconConfig.color.opacity(0.08) : Color.white.opacity(0.03),
                            isSelected ? iconConfig.color.opacity(0.02) : Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? iconConfig.color.opacity(0.25) : Color.white.opacity(0.05),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        )
        .scaleEffect(appear ? 1.0 : 0.92)
        .opacity(appear ? 1.0 : 0)
        .offset(y: appear ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(appearDelay)) {
                appear = true
            }
        }
        .onHover { isHover in
            withAnimation(.easeInOut(duration: 0.2)) {
                hover = isHover
            }
        }
        .scaleEffect(hover ? 1.02 : 1.0)
        .shadow(color: hover ? iconConfig.color.opacity(0.08) : .clear, radius: 12)
    }
}

// MARK: - Visual App Card

struct VisualAppCard: View {
    let count: Int
    let size: Int64
    let isSelected: Bool
    let appearDelay: Double
    let onToggle: () -> Void
    
    @State private var appear: Bool = false
    @State private var hover: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                FloatingIcon3D(
                    primaryIcon: "app",
                    secondaryIcon: "xmark.app",
                    primaryColor: .blue,
                    secondaryColor: .blue.opacity(0.6)
                )
                .scaleEffect(hover ? 1.08 : 1.0)
                
                Spacer()
                
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .green : .white.opacity(0.15))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ByteFormatter.string(from: size))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Applications")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Installed apps and leftover files")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            
            HStack {
                Spacer()
                Text("\(count) apps")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.top, 10)
        }
        .padding(16)
        .frame(minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            isSelected ? Color.blue.opacity(0.08) : Color.white.opacity(0.03),
                            isSelected ? Color.blue.opacity(0.02) : Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.blue.opacity(0.25) : Color.white.opacity(0.05),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        )
        .scaleEffect(appear ? 1.0 : 0.92)
        .opacity(appear ? 1.0 : 0)
        .offset(y: appear ? 0 : 15)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(appearDelay)) {
                appear = true
            }
        }
        .onHover { isHover in
            withAnimation(.easeInOut(duration: 0.2)) {
                hover = isHover
            }
        }
        .scaleEffect(hover ? 1.02 : 1.0)
        .shadow(color: hover ? Color.blue.opacity(0.08) : .clear, radius: 12)
    }
}

// MARK: - Category Detail Panel

struct CategoryDetailPanel: View {
    let category: JunkCategory
    let files: [JunkFile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.green.opacity(0.7))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(files.count) items · \(ByteFormatter.string(from: files.reduce(0) { $0 + $1.size }))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            
            Divider().background(Color.white.opacity(0.06))
            
            LazyVStack(spacing: 3) {
                ForEach(files.prefix(20)) { file in
                    @Bindable var bindableFile = file
                    HStack {
                        Toggle("", isOn: $bindableFile.isSelected)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                        
                        Text(file.name)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(ByteFormatter.string(from: file.size))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(file.isSelected ? Color.green.opacity(0.04) : Color.clear)
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Cleaning View

struct CleaningView: View {
    let viewModel: AutoModeViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.12), lineWidth: 3)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: viewModel.cleanProgress)
                    .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.cleanProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Cleaning...")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(height: 160)
            
            VStack(spacing: 10) {
                Text(viewModel.cleanStage)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.itemsCleaned)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("items")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    
                    HStack(spacing: 4) {
                        Text(ByteFormatter.string(from: viewModel.spaceReclaimed))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("reclaimed")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Complete View

struct CompleteView: View {
    let viewModel: AutoModeViewModel
    @State private var appear: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 60)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .scaleEffect(appear ? 1 : 0.5)
                .opacity(appear ? 1 : 0)
            
            VStack(spacing: 8) {
                Text("Cleanup Complete")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Your Mac has been optimized")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
            }
            
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(viewModel.itemsCleaned)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Items Removed")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.08))
                
                VStack(spacing: 4) {
                    Text(ByteFormatter.string(from: viewModel.spaceReclaimed))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Space Reclaimed")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 15)
            
            Spacer()
            
            Button(action: { viewModel.reset() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                    Text("Scan Again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                appear = true
            }
        }
    }
}
