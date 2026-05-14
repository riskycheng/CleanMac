import SwiftUI

struct JunkCleanerView: View {
    @State private var viewModel = SystemJunkViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                ModuleIdleView(
                    icon: "trash",
                    title: "Junk Cleaner",
                    subtitle: "Scan and remove system junk, caches, logs,\nand temporary files to reclaim disk space.",
                    buttonText: "Start Scan",
                    action: { viewModel.startScan() }
                )
            case .scanning:
                TerminalScannerView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    logLines: viewModel.scanLog
                )
            case .reviewing:
                JunkReviewView(viewModel: viewModel)
            case .cleaning:
                ModuleCleaningView(
                    progress: viewModel.cleanProgress,
                    stage: viewModel.cleanStage,
                    itemsProcessed: viewModel.itemsCleaned,
                    spaceReclaimed: viewModel.spaceReclaimed
                )
            case .complete:
                ModuleCompleteView(
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
    
    var activeCategories: [JunkCategory] {
        JunkCategory.allCases.filter { viewModel.categorySize($0) > 0 }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("\(ByteFormatter.string(from: viewModel.totalSize)) reclaimable")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Found \(viewModel.junkFiles.count) junk files")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.top, 8)
                
                let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(activeCategories, id: \.self) { category in
                        CategoryCard(
                            category: category,
                            size: viewModel.categorySize(category),
                            count: viewModel.filesInCategory(category).count,
                            isSelected: viewModel.filesInCategory(category).allSatisfy { $0.isSelected }
                        ) {
                            let files = viewModel.filesInCategory(category)
                            let allSelected = files.allSatisfy { $0.isSelected }
                            for file in files {
                                file.isSelected = !allSelected
                            }
                        }
                    }
                }
                
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
                    
                    let selected = viewModel.junkFiles.filter { $0.isSelected }
                    Button(action: { viewModel.cleanSelected() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                            Text("Clean \(ByteFormatter.string(from: selected.reduce(0) { $0 + $1.size }))")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected.isEmpty ? Color.white.opacity(0.06) : Color.green.opacity(0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selected.isEmpty ? Color.white.opacity(0.08) : Color.green.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selected.isEmpty)
                    .opacity(selected.isEmpty ? 0.5 : 1.0)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .padding(20)
        }
    }
}

struct ModuleIdleView: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonText: String
    let action: () -> Void
    @State private var pulse: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.08 : 0.95)
                    .opacity(pulse ? 0.6 : 1)
                
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.green.opacity(0.6))
            }
            .frame(height: 180)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                    Text(buttonText)
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

struct ModuleCleaningView: View {
    let progress: Double
    let stage: String
    let itemsProcessed: Int
    let spaceReclaimed: Int64
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.12), lineWidth: 3)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Cleaning...")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(height: 160)
            
            VStack(spacing: 10) {
                Text(stage)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 20) {
                    Label("\(itemsProcessed) items", systemImage: "doc")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    Label(ByteFormatter.string(from: spaceReclaimed), systemImage: "externaldrive")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModuleCompleteView: View {
    let itemsRemoved: Int
    let spaceReclaimed: Int64
    let onReset: () -> Void
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
                    Text("\(itemsRemoved)")
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
                    Text(ByteFormatter.string(from: spaceReclaimed))
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
            
            Button(action: onReset) {
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
