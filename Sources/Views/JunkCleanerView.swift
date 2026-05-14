import SwiftUI

struct JunkCleanerView: View {
    @State private var viewModel = SystemJunkViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Junk Cleaner")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Scan and remove system junk, caches, logs, and temporary files")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                if viewModel.scanComplete && !viewModel.files.isEmpty {
                    Text("Selected: \(ByteFormatter.string(from: viewModel.totalSize))")
                        .font(.callout.weight(.medium))
                        .foregroundColor(Color(hex: "69F0AE"))
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
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                    Text("Scanning for junk files...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            } else if viewModel.files.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.4), radius: 15)
                    Text("Your Mac is clean!")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    Text("No junk files were found.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Button("Scan Again") {
                        viewModel.startScan()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                Spacer()
            } else if !viewModel.files.isEmpty {
                List {
                    ForEach(JunkFile.JunkType.allCases, id: \.id) { type in
                        let group = viewModel.files.filter { $0.type == type }
                        if !group.isEmpty {
                            Section {
                                ForEach($viewModel.files) { $file in
                                    if file.type == type {
                                        JunkFileRow(file: $file)
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: type.icon)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(type.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                    Text("\(group.count) items")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds(.enabled)
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack(spacing: 16) {
                    Button("Select All") {
                        viewModel.toggleAll(true)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Button("Deselect All") {
                        viewModel.toggleAll(false)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("\(viewModel.selectedCount) items selected")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button("Clean Selected") {
                        viewModel.cleanSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isCleaning || viewModel.selectedCount == 0)
                }
                .padding()
            } else {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .blur(radius: 25)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "69F0AE").opacity(0.9), Color(hex: "69F0AE").opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "69F0AE").opacity(0.4), radius: 15)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Ready to Clean")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Scan your Mac to find and remove junk files.")
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

struct JunkFileRow: View {
    @Binding var file: JunkFile
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $file.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            Image(systemName: file.type.icon)
                .foregroundColor(typeColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.url.lastPathComponent)
                    .lineLimit(1)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                Text(file.url.deletingLastPathComponent().path)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Text(ByteFormatter.string(from: file.size))
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(typeColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    var typeColor: Color {
        switch file.type {
        case .cache, .systemCache: return .cyan
        case .log, .systemLog: return .yellow
        case .temp: return .orange
        case .download: return .blue
        case .trash: return .red
        case .browserCache: return .purple
        case .xcode: return .indigo
        case .developerCache: return .teal
        case .orphanedSupport: return .gray
        }
    }
}
