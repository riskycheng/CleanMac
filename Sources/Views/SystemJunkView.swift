import SwiftUI

enum SystemJunkState {
    case idle
    case scanning
    case reviewing
    case cleaning
    case complete
}

@MainActor
@Observable
final class SystemJunkViewModel {
    var state: SystemJunkState = .idle
    var scanProgress: Double = 0
    var scanStage: String = ""
    var junkFiles: [JunkFile] = []
    var totalSize: Int64 = 0
    var cleanProgress: Double = 0
    var cleanStage: String = ""
    var itemsCleaned: Int = 0
    var spaceReclaimed: Int64 = 0
    
    func startScan() {
        state = .scanning
        scanProgress = 0
        Task { await runScan() }
    }
    
    private func runScan() async {
        let stages = [
            ("Identifying corrupted caches...", 0.15),
            ("Analyzing storage blocks...", 0.30),
            ("Scanning temporary files...", 0.50),
            ("Checking download remnants...", 0.70),
            ("Verifying log archives...", 0.85),
        ]
        for (stage, progress) in stages {
            await MainActor.run { scanStage = stage; scanProgress = progress }
            try? await Task.sleep(for: .milliseconds(400))
        }
        let files = await FileScanner.smartScanJunk()
        await MainActor.run {
            junkFiles = files
            totalSize = files.reduce(0) { $0 + $1.size }
            state = .reviewing
        }
    }
    
    func cleanSelected() {
        let selected = junkFiles.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        state = .cleaning
        cleanProgress = 0
        itemsCleaned = 0
        spaceReclaimed = 0
        Task { await runClean(selected: selected) }
    }
    
    private func runClean(selected: [JunkFile]) async {
        for (index, file) in selected.enumerated() {
            await MainActor.run {
                cleanStage = "Removing \(file.name)..."
                cleanProgress = Double(index) / Double(selected.count)
            }
            do { try FileManager.default.trashItem(at: file.url, resultingItemURL: nil); spaceReclaimed += file.size; itemsCleaned += 1 } catch { }
            try? await Task.sleep(for: .milliseconds(60))
        }
        await MainActor.run {
            cleanStage = "Cleanup complete"
            cleanProgress = 1.0
            state = .complete
        }
    }
    
    func reset() {
        state = .idle
        junkFiles.removeAll()
        totalSize = 0
        itemsCleaned = 0
        spaceReclaimed = 0
    }
    
    func categorySize(_ category: JunkCategory) -> Int64 {
        junkFiles.filter { $0.category == category }.reduce(0) { $0 + $1.size }
    }
    
    func filesInCategory(_ category: JunkCategory) -> [JunkFile] {
        junkFiles.filter { $0.category == category }
    }
}

struct SystemJunkView: View {
    @State private var viewModel = SystemJunkViewModel()
    @State private var selectedCategory: JunkCategory? = nil
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                ModuleIdleView(
                    icon: "trash",
                    iconColor: Color(hex: "EF4444"),
                    title: "System Junk",
                    subtitle: "Scour every corner of your storage to find forgotten cache files and hidden temporary data.",
                    buttonText: "Scan Storage",
                    action: { viewModel.startScan() }
                )
            case .scanning:
                ModernProgressView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    subStage: "Identifying Corrupted Caches...",
                    accentColor: Color(hex: "EF4444")
                )
            case .reviewing:
                JunkReviewView(viewModel: viewModel, selectedCategory: $selectedCategory)
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

struct JunkReviewView: View {
    @Bindable var viewModel: SystemJunkViewModel
    @Binding var selectedCategory: JunkCategory?
    
    var activeCategories: [JunkCategory] {
        JunkCategory.allCases.filter { viewModel.categorySize($0) > 0 }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "EF4444"))
                            Text("STORAGE ENGINE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "EF4444"))
                        }
                        Text("Scan Results")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(Color(hex: "111827"))
                        Text("\(ByteFormatter.string(from: viewModel.totalSize)) found across your system components.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "6B7280"))
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.cleanSelected() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .bold))
                            Text("CLEAN ALL")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "EF4444"))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Category cards
                HStack(spacing: 12) {
                    let topCategories = Array(activeCategories.prefix(4))
                    ForEach(Array(topCategories.enumerated()), id: \.offset) { _, category in
                        let size = viewModel.categorySize(category)
                        CategoryResultCard(
                            icon: category.icon,
                            iconColor: category.chartColor,
                            label: category.displayName,
                            value: ByteFormatter.string(from: size),
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        }
                    }
                }
                
                // Detail or Action card
                if let cat = selectedCategory {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(cat.displayName)
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(Color(hex: "111827"))
                            Spacer()
                            Text("\(viewModel.filesInCategory(cat).count) items")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                        
                        Divider().background(Color.black.opacity(0.06))
                        
                        ScrollView(showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.filesInCategory(cat).enumerated()), id: \.element.id) { index, file in
                                    @Bindable var bf = file
                                    HStack(spacing: 12) {
                                        Toggle("", isOn: $bf.isSelected)
                                            .toggleStyle(.checkbox)
                                            .controlSize(.small)
                                        Text(file.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(hex: "374151"))
                                        Spacer()
                                        Text(ByteFormatter.string(from: file.size))
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(Color(hex: "9CA3AF"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(index % 2 == 0 ? Color(hex: "F9FAFB") : Color.clear)
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.black.opacity(0.03), lineWidth: 1)
                    )
                } else {
                    ActionCard(
                        icon: "trash",
                        iconColor: Color(hex: "EF4444"),
                        title: "Ready to Reclaim Space",
                        subtitle: "Cleaning these files will result in immediate system speed improvements and more available workspace.",
                        buttonText: "Confirm Cleanup",
                        buttonAction: { viewModel.cleanSelected() }
                    )
                }
            }
            .padding(28)
        }
    }
}
