import SwiftUI

struct JunkCleanerView: View {
    @State private var viewModel = SystemJunkViewModel()
    @State private var selectedCategory: JunkCategory? = nil
    
    var filteredFiles: [JunkFile] {
        if let category = selectedCategory {
            return viewModel.junkFiles.filter { $0.category == category }
        }
        return viewModel.junkFiles
    }
    
    var body: some View {
        ZStack {
            DataStreamView()
                .opacity(viewModel.isScanning || viewModel.isCleaning ? 0.12 : 0.04)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Junk Cleaner")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            Text("Remove system junk and reclaim disk space")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        
                        if viewModel.scanComplete {
                            Button(viewModel.allSelected ? "Deselect All" : "Select All") {
                                viewModel.toggleAll()
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if viewModel.isScanning {
                        ScanningPanel(
                            title: "Scanning for Junk",
                            stage: viewModel.scanStage,
                            progress: viewModel.scanProgress,
                            color: .green
                        )
                    } else if viewModel.isCleaning {
                        ScanningPanel(
                            title: "Cleaning Junk",
                            stage: viewModel.cleanStage,
                            progress: viewModel.cleanProgress,
                            color: .green
                        )
                    } else if viewModel.scanComplete {
                        // Summary
                        GlassCard(accent: .green) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(viewModel.junkFiles.count) items found")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(ByteFormatter.string(from: viewModel.totalSize) + " reclaimable")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                }
                                Spacer()
                                if viewModel.selectedCount > 0 {
                                    GlowButton(
                                        title: "Clean \(viewModel.selectedCount) Items",
                                        icon: "trash.fill",
                                        color: .green
                                    ) {
                                        viewModel.cleanSelected()
                                    }
                                }
                            }
                        }
                        
                        // Category filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryFilterButton(
                                    label: "All",
                                    count: viewModel.junkFiles.count,
                                    isSelected: selectedCategory == nil,
                                    color: .green
                                ) {
                                    selectedCategory = nil
                                }
                                
                                ForEach(JunkCategory.allCases, id: \.self) { category in
                                    let count = viewModel.junkFiles.filter { $0.category == category }.count
                                    if count > 0 {
                                        CategoryFilterButton(
                                            label: category.displayName,
                                            count: count,
                                            isSelected: selectedCategory == category,
                                            color: .green
                                        ) {
                                            selectedCategory = category
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // File list
                        LazyVStack(spacing: 4) {
                            ForEach(filteredFiles) { file in
                                JunkFileRow(file: file)
                            }
                        }
                    } else {
                        // Idle state
                        VStack(spacing: 32) {
                            Spacer().frame(height: 60)
                            
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [.green.opacity(0.15), .clear],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 100
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.green.opacity(0.8))
                                    .shadow(color: .green.opacity(0.3), radius: 15)
                            }
                            .frame(height: 200)
                            
                            VStack(spacing: 12) {
                                Text("Junk Cleaner")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Scan and remove caches, logs, temporary files,\nbrowser data, Xcode artifacts, and more.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            }
                            
                            GlowButton(
                                title: "Start Scan",
                                icon: "magnifyingglass",
                                color: .green
                            ) {
                                viewModel.startScan()
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 400)
                    }
                }
                .padding(24)
            }
        }
    }
}

struct CategoryFilterButton: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.06))
                    )
            }
            .foregroundColor(isSelected ? color : .white.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? color.opacity(0.25) : Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct JunkFileRow: View {
    @Bindable var file: JunkFile
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $file.isSelected)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            
            Image(systemName: file.category.icon)
                .font(.system(size: 12))
                .foregroundColor(.green.opacity(0.6))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                Text(file.path)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.category.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.green.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.06))
                )
            
            Text(ByteFormatter.string(from: file.size))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(file.isSelected ? Color.green.opacity(0.04) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
        )
    }
}

struct ScanningPanel: View {
    let title: String
    let stage: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            
            ScanningRing()
                .frame(height: 160)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(stage)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            
            ProgressPulseBar(progress: progress, color: color)
                .frame(width: 300)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}
