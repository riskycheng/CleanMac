import SwiftUI

struct SmartCareView: View {
    @State private var viewModel = SmartScanViewModel()
    @Binding var completedModules: Set<ScanModuleType>
    
    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .idle:
                idleView
            case .scanning(let moduleIndex, let currentPath):
                scanningView(moduleIndex: moduleIndex, currentPath: currentPath)
                    .onAppear {
                        completedModules = viewModel.completedModules
                    }
            case .results(let results):
                resultsView(results: results)
            case .processing(let moduleIndex, let itemIndex):
                processingView(moduleIndex: moduleIndex, itemIndex: itemIndex)
            case .complete(let results):
                completeView(results: results)
            }
        }
        .onChange(of: viewModel.completedModules) { _, newValue in
            completedModules = newValue
        }
    }
    
    // MARK: - Idle State
    var idleView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "E040FB").opacity(0.9), Color(hex: "E040FB").opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "E040FB").opacity(0.5), radius: 20, x: 0, y: 0)
            }
            .frame(height: 200)
            
            VStack(spacing: 12) {
                Text("Welcome back!")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Start with a quick and extensive scan of your Mac.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            Spacer()
            
            CircularActionButton(
                title: "Scan",
                accent: Color(hex: "E040FB"),
                action: { viewModel.startSmartScan() }
            )
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning State with Dynamic Grid
    func scanningView(moduleIndex: Int, currentPath: String) -> some View {
        VStack(spacing: 0) {
            Text(ScanModuleType.allCases[moduleIndex].scanningTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            DynamicScanningGrid(
                viewModel: viewModel,
                activeIndex: moduleIndex,
                currentPath: currentPath
            )
            .padding(.horizontal, 32)
            
            Spacer()
            
            CircularActionButton(
                title: "Stop",
                accent: Color(hex: "E040FB"),
                action: { viewModel.stop() }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Results State
    func resultsView(results: [ScanModuleResult]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.startOver() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Over")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Text("Your tasks are ready to run. Look what we found:")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            moduleCardsGrid(results: results, showCheckbox: true, showReview: true)
            
            Spacer()
            
            CircularActionButton(
                title: "Run",
                accent: Color(hex: "E040FB"),
                action: { viewModel.runSelectedTasks() }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Processing State
    func processingView(moduleIndex: Int, itemIndex: Int) -> some View {
        VStack(spacing: 0) {
            let currentType = ScanModuleType.allCases[moduleIndex]
            Text(currentType.processingTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            HStack(spacing: 16) {
                ProcessingDetailCard(
                    result: buildProcessingResult(moduleIndex: moduleIndex),
                    currentItemIndex: itemIndex
                )
                .frame(width: 420)
                
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach([1, 2].filter { $0 < 5 && $0 != moduleIndex }, id: \.self) { idx in
                            WaitingCard(type: ScanModuleType.allCases[idx])
                        }
                    }
                    .frame(height: 200)
                    
                    HStack(spacing: 16) {
                        ForEach([3, 4].filter { $0 < 5 && $0 != moduleIndex }, id: \.self) { idx in
                            WaitingCard(type: ScanModuleType.allCases[idx])
                        }
                    }
                    .frame(height: 200)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            CircularActionButton(
                title: "Stop",
                accent: Color(hex: "E040FB"),
                action: { viewModel.stop() }
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Complete State
    func completeView(results: [ScanModuleResult]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.startOver() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Over")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Text("Well done! Your Mac is in great shape!")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            moduleCardsGrid(results: results, showCheckbox: false, showReview: false)
            
            Spacer()
            
            HStack {
                Spacer()
                Button(action: {}) {
                    Text("View Log")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 32)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Shared Card Grid
    func moduleCardsGrid(results: [ScanModuleResult], showCheckbox: Bool, showReview: Bool) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 16) {
                if let cleanup = results.first(where: { $0.type == .cleanup }) {
                    Group {
                        if showCheckbox {
                            SmartCareCard(
                                result: cleanup,
                                isActive: false,
                                showCheckbox: showCheckbox,
                                showReview: showReview,
                                onToggle: { viewModel.toggleModuleSelection(.cleanup) },
                                onReview: {}
                            )
                        } else {
                            CompletedCard(result: cleanup)
                        }
                    }
                    .frame(height: 200)
                }
                
                if let apps = results.first(where: { $0.type == .applications }) {
                    Group {
                        if showCheckbox {
                            SmartCareCard(
                                result: apps,
                                isActive: false,
                                showCheckbox: showCheckbox,
                                showReview: showReview,
                                onToggle: { viewModel.toggleModuleSelection(.applications) },
                                onReview: {}
                            )
                        } else {
                            CompletedCard(result: apps)
                        }
                    }
                    .frame(height: 200)
                }
            }
            .frame(width: 420)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    if let protection = results.first(where: { $0.type == .protection }) {
                        Group {
                            if showCheckbox {
                                SmartCareCard(
                                    result: protection,
                                    isActive: false,
                                    showCheckbox: showCheckbox,
                                    showReview: false,
                                    onToggle: { viewModel.toggleModuleSelection(.protection) },
                                    onReview: nil
                                )
                            } else {
                                CompletedCard(result: protection)
                            }
                        }
                    }
                    
                    if let performance = results.first(where: { $0.type == .performance }) {
                        Group {
                            if showCheckbox {
                                SmartCareCard(
                                    result: performance,
                                    isActive: false,
                                    showCheckbox: showCheckbox,
                                    showReview: showReview,
                                    onToggle: { viewModel.toggleModuleSelection(.performance) },
                                    onReview: {}
                                )
                            } else {
                                CompletedCard(result: performance)
                            }
                        }
                    }
                }
                .frame(height: 200)
                
                if let clutter = results.first(where: { $0.type == .myClutter }) {
                    Group {
                        if showCheckbox {
                            SmartCareCard(
                                result: clutter,
                                isActive: false,
                                showCheckbox: showCheckbox,
                                showReview: false,
                                onToggle: { viewModel.toggleModuleSelection(.myClutter) },
                                onReview: nil
                            )
                        } else {
                            CompletedCard(result: clutter)
                        }
                    }
                    .frame(height: 200)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
    }
    
    func buildProcessingResult(moduleIndex: Int) -> ScanModuleResult {
        let type = ScanModuleType.allCases[moduleIndex]
        switch type {
        case .cleanup:
            let items = viewModel.junkFiles.prefix(4).map { ScanDetailItem(name: $0.url.lastPathComponent, size: $0.size, status: .pending) }
            return ScanModuleResult(type: .cleanup, isSelected: true, hasIssues: true, primaryText: "Cleaning junk...", secondaryText: "", detailItems: items)
        case .protection:
            let items = viewModel.threats.prefix(3).map { ScanDetailItem(name: $0.name, size: 0, status: .pending) }
            return ScanModuleResult(type: .protection, isSelected: true, hasIssues: true, primaryText: "Removing threats...", secondaryText: "", detailItems: items)
        case .performance:
            let items = viewModel.privacyItems.prefix(3).map { ScanDetailItem(name: $0.name, size: $0.size, status: .pending) }
            return ScanModuleResult(type: .performance, isSelected: true, hasIssues: true, primaryText: "Optimizing...", secondaryText: "", detailItems: items)
        case .applications:
            let items = viewModel.apps.prefix(3).map { ScanDetailItem(name: $0.name, size: $0.totalSize, status: .pending) }
            return ScanModuleResult(type: .applications, isSelected: true, hasIssues: true, primaryText: "Updating...", secondaryText: "", detailItems: items)
        case .myClutter:
            let items = viewModel.largeFiles.prefix(4).map { ScanDetailItem(name: $0.url.lastPathComponent, size: $0.size, status: .pending) }
            return ScanModuleResult(type: .myClutter, isSelected: true, hasIssues: true, primaryText: "Removing clutter...", secondaryText: "", detailItems: items)
        }
    }
    
    func buildWaitingResult(index: Int) -> ScanModuleResult {
        let type = ScanModuleType.allCases[index]
        switch type {
        case .cleanup:
            let total = viewModel.junkFiles.reduce(0) { $0 + $1.size }
            return ScanModuleResult(type: .cleanup, isSelected: false, hasIssues: total > 0, primaryText: total > 0 ? ByteFormatter.string(from: total) + " of junk" : "No junk", secondaryText: "waiting...", detailItems: [])
        case .protection:
            return ScanModuleResult(type: .protection, isSelected: false, hasIssues: viewModel.threats.count > 0, primaryText: viewModel.threats.count > 0 ? "\(viewModel.threats.count) threats" : "No threats", secondaryText: "waiting...", detailItems: [])
        case .performance:
            return ScanModuleResult(type: .performance, isSelected: false, hasIssues: viewModel.privacyItems.count > 0, primaryText: viewModel.privacyItems.count > 0 ? "\(viewModel.privacyItems.count) tasks" : "No tasks", secondaryText: "waiting...", detailItems: [])
        case .applications:
            return ScanModuleResult(type: .applications, isSelected: false, hasIssues: viewModel.apps.count > 0, primaryText: viewModel.apps.count > 0 ? "\(viewModel.apps.count) updates" : "No updates", secondaryText: "waiting...", detailItems: [])
        case .myClutter:
            return ScanModuleResult(type: .myClutter, isSelected: false, hasIssues: viewModel.largeFiles.count > 0, primaryText: viewModel.largeFiles.count > 0 ? "\(viewModel.largeFiles.count) items" : "No clutter", secondaryText: "waiting...", detailItems: [])
        }
    }
}

// MARK: - Dynamic Scanning Grid
struct DynamicScanningGrid: View {
    let viewModel: SmartScanViewModel
    let activeIndex: Int
    let currentPath: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Top row: Cleanup, Protection, Performance
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { index in
                    Group {
                        if index == activeIndex {
                            ActiveScanCard(
                                type: ScanModuleType.allCases[index],
                                title: ScanModuleType.allCases[index].scanningTitle,
                                subtitle: currentPath
                            )
                        } else if viewModel.completedModules.contains(ScanModuleType.allCases[index]) {
                            if let result = viewModel.result(for: ScanModuleType.allCases[index]) {
                                ScannedResultCard(result: result)
                            } else {
                                WaitingCard(type: ScanModuleType.allCases[index])
                            }
                        } else {
                            WaitingCard(type: ScanModuleType.allCases[index])
                        }
                    }
                    .frame(maxWidth: index == activeIndex ? .infinity : (activeIndex < 3 ? 220 : .infinity))
                }
            }
            .frame(height: 280)
            
            // Bottom row: Applications, My Clutter
            HStack(spacing: 16) {
                ForEach(3..<5, id: \.self) { index in
                    Group {
                        if index == activeIndex {
                            ActiveScanCard(
                                type: ScanModuleType.allCases[index],
                                title: ScanModuleType.allCases[index].scanningTitle,
                                subtitle: currentPath
                            )
                        } else if viewModel.completedModules.contains(ScanModuleType.allCases[index]) {
                            if let result = viewModel.result(for: ScanModuleType.allCases[index]) {
                                ScannedResultCard(result: result)
                            } else {
                                WaitingCard(type: ScanModuleType.allCases[index])
                            }
                        } else {
                            WaitingCard(type: ScanModuleType.allCases[index])
                        }
                    }
                    .frame(maxWidth: index == activeIndex ? .infinity : (activeIndex >= 3 ? 280 : .infinity))
                }
            }
            .frame(height: 220)
        }
    }
}

// MARK: - Scanned Result Card (compact, for completed modules during scan)
struct ScannedResultCard: View {
    let result: ScanModuleResult
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: result.type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(result.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    
                    Image(systemName: result.type.icon)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(result.type.accent.opacity(0.7))
                        .shadow(color: result.type.accent.opacity(0.3), radius: 8, x: 0, y: 0)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.primaryText)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Text(result.secondaryText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: - Waiting Card (dimmed, shows module identity)
struct WaitingCard: View {
    let type: ScanModuleType
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            
            VStack {
                HStack {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                
                Spacer()
                
                Image(systemName: type.icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(type.accent.opacity(0.15))
                
                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: - Circular Action Button
struct CircularActionButton: View {
    let title: String
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 92, height: 92)
                    .blur(radius: 15)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: accent.opacity(0.4), radius: 15, x: 0, y: 5)
                
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
