import SwiftUI

struct AppUninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    
    var body: some View {
        ZStack {
            DataStreamView()
                .opacity(viewModel.isScanning || viewModel.isUninstalling ? 0.12 : 0.04)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Uninstaller")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            Text("Completely remove apps and their leftover files")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        
                        if viewModel.scanComplete {
                            Button(viewModel.allSelected ? "Deselect All" : "Select All") {
                                viewModel.toggleAll()
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if viewModel.isScanning {
                        ScanningPanel(
                            title: "Scanning Applications",
                            stage: viewModel.scanStage,
                            progress: viewModel.scanProgress,
                            color: .blue
                        )
                    } else if viewModel.isUninstalling {
                        ScanningPanel(
                            title: "Uninstalling Apps",
                            stage: viewModel.uninstallStage,
                            progress: viewModel.uninstallProgress,
                            color: .blue
                        )
                    } else if viewModel.scanComplete {
                        // Summary
                        GlassCard(accent: .blue) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(viewModel.apps.count) apps found")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(ByteFormatter.string(from: viewModel.totalSize) + " total")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                if viewModel.selectedCount > 0 {
                                    GlowButton(
                                        title: "Uninstall \(viewModel.selectedCount)",
                                        icon: "xmark.app.fill",
                                        color: .blue
                                    ) {
                                        viewModel.uninstallSelected()
                                    }
                                }
                            }
                        }
                        
                        // App list
                        LazyVStack(spacing: 6) {
                            ForEach(viewModel.apps) { app in
                                AppRow(app: app)
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
                                            colors: [.blue.opacity(0.15), .clear],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 100
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                
                                Image(systemName: "app.badge.checkmark")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.blue.opacity(0.8))
                                    .shadow(color: .blue.opacity(0.3), radius: 15)
                            }
                            .frame(height: 200)
                            
                            VStack(spacing: 12) {
                                Text("App Uninstaller")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Scan installed applications and remove them\ncompletely including all leftover files.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            }
                            
                            GlowButton(
                                title: "Scan Applications",
                                icon: "magnifyingglass",
                                color: .blue
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

struct AppRow: View {
    @Bindable var app: AppBundle
    @State private var expanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Toggle("", isOn: $app.isSelected)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue.opacity(0.7))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    if !app.version.isEmpty {
                        Text(app.version)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                
                Spacer()
                
                if !app.leftoverFiles.isEmpty {
                    Button(action: { expanded.toggle() }) {
                        HStack(spacing: 4) {
                            Text("+\(app.leftoverFiles.count) leftovers")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.orange.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Text(ByteFormatter.string(from: app.totalSize))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(app.isSelected ? Color.blue.opacity(0.04) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            }
            
            if expanded && !app.leftoverFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Leftover files found:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    
                    ForEach(app.leftoverFiles, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.3))
                            Text(url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                )
                .padding(.top, 4)
            }
        }
    }
}
