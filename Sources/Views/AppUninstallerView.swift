import SwiftUI

struct AppUninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Uninstaller")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Find and completely uninstall applications with all leftover files")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                if viewModel.scanComplete && !viewModel.apps.isEmpty {
                    Text("Selected: \(ByteFormatter.string(from: viewModel.selectedTotalSize))")
                        .font(.callout.weight(.medium))
                        .foregroundColor(Color(hex: "448AFF"))
                }
            }
            .padding()
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if viewModel.isScanning {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                    Text("Scanning applications...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            } else if viewModel.apps.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.4), radius: 15)
                    Text("No Applications Found")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            } else if !viewModel.apps.isEmpty {
                List {
                    ForEach($viewModel.apps) { $app in
                        AppRow(app: $app)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 16) {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Button("Deselect All") {
                        viewModel.deselectAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(viewModel.selectedApps.count) apps selected")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button("Uninstall Selected") {
                        viewModel.uninstallSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isUninstalling || viewModel.selectedApps.isEmpty)
                }
                .padding()
            } else {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .blur(radius: 25)
                        
                        Image(systemName: "app.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "448AFF").opacity(0.9), Color(hex: "448AFF").opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "448AFF").opacity(0.4), radius: 15)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Ready to Scan")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Find applications and their leftover files for complete removal.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Button("Scan Now") {
                        viewModel.startScan()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }
}

struct AppRow: View {
    @Binding var app: AppBundle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Toggle("", isOn: $app.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                
                Image(systemName: "app.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "448AFF"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "448AFF").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text(app.version ?? "Unknown version")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        if app.bundleIdentifier != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                            Text(app.bundleIdentifier!)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedSize)
                        .font(.callout.weight(.medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.9))
                    if !app.leftovers.isEmpty {
                        Text("+ \(app.leftovers.count) leftover files")
                            .font(.caption)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "448AFF").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            if app.isSelected && !app.leftovers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leftover Files to Remove")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal)
                    
                    ForEach($app.leftovers) { $leftover in
                        HStack {
                            Toggle("", isOn: $leftover.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            Text(leftover.url.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text(ByteFormatter.string(from: leftover.size))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
