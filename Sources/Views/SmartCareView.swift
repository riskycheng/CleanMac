import SwiftUI

struct SmartCareView: View {
    @State private var viewModel = SmartScanViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .idle:
                idleView
            case .scanning(let moduleIndex, let currentPath):
                scanningView(moduleIndex: moduleIndex, currentPath: currentPath)
            case .results(let results):
                resultsView(results: results)
            case .processing(let moduleIndex, let itemIndex):
                processingView(moduleIndex: moduleIndex, itemIndex: itemIndex)
            case .complete:
                completeView
            }
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
    
    // MARK: - Scanning State
    func scanningView(moduleIndex: Int, currentPath: String) -> some View {
        VStack(spacing: 0) {
            // Title
            Text(ScanModuleType.allCases[moduleIndex].scanningTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            // Card Grid
            HStack(spacing: 16) {
                // Left column - active scanning card
                ActiveScanCard(
                    type: ScanModuleType.allCases[moduleIndex],
                    title: ScanModuleType.allCases[moduleIndex].scanningTitle,
                    subtitle: currentPath
                )
                .frame(width: 420)
                
                // Right column - other modules
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach([1, 2].filter { $0 < 5 }, id: \.self) { idx in
                            if moduleIndex != idx {
                                placeholderCard(type: ScanModuleType.allCases[idx])
                            } else {
                                Color.clear
                            }
                        }
                    }
                    .frame(height: 200)
                    
                    HStack(spacing: 16) {
                        ForEach([3, 4].filter { $0 < 5 }, id: \.self) { idx in
                            if moduleIndex != idx {
                                placeholderCard(type: ScanModuleType.allCases[idx])
                            } else {
                                Color.clear
                            }
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
    
    func placeholderCard(type: ScanModuleType) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: type.icon)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(type.accent.opacity(0.2))
                }
                Spacer()
            }
            .padding(16)
        }
    }
    
    // MARK: - Results State
    func resultsView(results: [ScanModuleResult]) -> some View {
        VStack(spacing: 0) {
            // Header
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
            
            // Card Grid
            HStack(spacing: 16) {
                // Left column
                VStack(spacing: 16) {
                    if let cleanup = results.first(where: { $0.type == .cleanup }) {
                        SmartCareCard(
                            result: cleanup,
                            isActive: false,
                            showCheckbox: true,
                            showReview: true,
                            onToggle: { viewModel.toggleModuleSelection(.cleanup) },
                            onReview: {}
                        )
                        .frame(height: 200)
                    }
                    
                    if let apps = results.first(where: { $0.type == .applications }) {
                        SmartCareCard(
                            result: apps,
                            isActive: false,
                            showCheckbox: true,
                            showReview: true,
                            onToggle: { viewModel.toggleModuleSelection(.applications) },
                            onReview: {}
                        )
                        .frame(height: 200)
                    }
                }
                .frame(width: 420)
                
                // Right column
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        if let protection = results.first(where: { $0.type == .protection }) {
                            SmartCareCard(
                                result: protection,
                                isActive: false,
                                showCheckbox: true,
                                showReview: false,
                                onToggle: { viewModel.toggleModuleSelection(.protection) },
                                onReview: nil
                            )
                        }
                        
                        if let performance = results.first(where: { $0.type == .performance }) {
                            SmartCareCard(
                                result: performance,
                                isActive: false,
                                showCheckbox: true,
                                showReview: true,
                                onToggle: { viewModel.toggleModuleSelection(.performance) },
                                onReview: {}
                            )
                        }
                    }
                    .frame(height: 200)
                    
                    if let clutter = results.first(where: { $0.type == .myClutter }) {
                        SmartCareCard(
                            result: clutter,
                            isActive: false,
                            showCheckbox: true,
                            showReview: false,
                            onToggle: { viewModel.toggleModuleSelection(.myClutter) },
                            onReview: nil
                        )
                        .frame(height: 200)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            
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
            // Title
            let allModules = ScanModuleType.allCases
            let currentType = allModules[moduleIndex]
            Text(currentType.processingTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 24)
                .padding(.bottom, 20)
            
            // Card Grid
            HStack(spacing: 16) {
                // Left - active processing card
                if case .results(let results) = viewModel.phase {
                    // Need to get results from viewModel somehow
                    // Since processing phase doesn't have results, we'll use stored data
                }
                
                // Build processing display using viewModel's stored data
                ProcessingDetailCard(
                    result: buildProcessingResult(moduleIndex: moduleIndex),
                    currentItemIndex: itemIndex
                )
                .frame(width: 420)
                
                // Right - waiting cards
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        ForEach([1, 2].filter { $0 < 5 && $0 != moduleIndex }, id: \.self) { idx in
                            WaitingCard(result: buildWaitingResult(index: idx))
                        }
                    }
                    .frame(height: 200)
                    
                    HStack(spacing: 16) {
                        ForEach([3, 4].filter { $0 < 5 && $0 != moduleIndex }, id: \.self) { idx in
                            WaitingCard(result: buildWaitingResult(index: idx))
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
    
    // MARK: - Complete State
    var completeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.5), radius: 20, x: 0, y: 0)
            
            Text("All Done!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your Mac has been cleaned and optimized.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            CircularActionButton(
                title: "Scan Again",
                accent: Color(hex: "E040FB"),
                action: { viewModel.startOver() }
            )
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                // Outer glow
                Circle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 92, height: 92)
                    .blur(radius: 15)
                
                // Button
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
