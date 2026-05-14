import SwiftUI

struct AppUninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    
    var body: some View {
        ZStack {
            switch viewModel.state {
            case .idle:
                ModuleIdleView(
                    icon: "app",
                    title: "App Uninstaller",
                    subtitle: "Find installed applications and remove them\ncompletely including all leftover files.",
                    buttonText: "Scan Applications",
                    action: { viewModel.startScan() }
                )
            case .scanning:
                TerminalScannerView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    logLines: viewModel.scanLog
                )
            case .reviewing:
                AppReviewView(viewModel: viewModel)
            case .uninstalling:
                ModuleCleaningView(
                    progress: viewModel.uninstallProgress,
                    stage: viewModel.uninstallStage,
                    itemsProcessed: viewModel.itemsRemoved,
                    spaceReclaimed: viewModel.spaceReclaimed
                )
            case .complete:
                ModuleCompleteView(
                    itemsRemoved: viewModel.itemsRemoved,
                    spaceReclaimed: viewModel.spaceReclaimed,
                    onReset: { viewModel.reset() }
                )
            }
        }
    }
}

struct AppReviewView: View {
    @Bindable var viewModel: UninstallerViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("\(ByteFormatter.string(from: viewModel.totalSize)) total")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Found \(viewModel.apps.count) applications")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.top, 8)
                
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.apps) { app in
                        AppCard(app: app)
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
                    
                    let selected = viewModel.apps.filter { $0.isSelected }
                    Button(action: { viewModel.uninstallSelected() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                            Text("Uninstall \(ByteFormatter.string(from: selected.reduce(0) { $0 + $1.totalSize }))")
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

struct AppCard: View {
    @Bindable var app: AppBundle
    @State private var hover: Bool = false
    @State private var showLeftovers: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("", isOn: $app.isSelected)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    if !app.version.isEmpty {
                        Text(app.version)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                
                Spacer()
                
                if !app.leftoverFiles.isEmpty {
                    Button(action: { showLeftovers.toggle() }) {
                        HStack(spacing: 4) {
                            Text("+\(app.leftoverFiles.count) leftovers")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: showLeftovers ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Text(ByteFormatter.string(from: app.totalSize))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(app.isSelected ? Color.green.opacity(0.04) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(app.isSelected ? Color.green.opacity(0.12) : Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            
            if showLeftovers && !app.leftoverFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(app.leftoverFiles, id: \.self) { url in
                        HStack {
                            Text(url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2))
                )
                .padding(.top, 4)
            }
        }
        .onHover { isHover in
            withAnimation(.easeInOut(duration: 0.15)) {
                hover = isHover
            }
        }
    }
}
