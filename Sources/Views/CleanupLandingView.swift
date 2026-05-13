import SwiftUI

struct CleanupLandingView: View {
    @State private var viewModel = SystemJunkViewModel()
    @State private var hasScanned = false
    
    var body: some View {
        ZStack {
            if !hasScanned {
                ModuleHero(
                    icon: "bubbles.and.sparkles",
                    title: "Cleanup",
                    subtitle: "Clean your system to achieve maximum performance and reclaim free space.",
                    accent: Color(hex: "69F0AE"),
                    isScanning: viewModel.isScanning,
                    scanAction: {
                        viewModel.startScan()
                        hasScanned = true
                    }
                )
            } else {
                SystemJunkViewDark(viewModel: viewModel)
            }
        }
    }
}

struct SystemJunkViewDark: View {
    @Bindable var viewModel: SystemJunkViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Junk")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select items to clean")
                        .font(.subheadline)
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
            
            if viewModel.files.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No junk found!")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            } else if !viewModel.files.isEmpty {
                List {
                    ForEach(JunkFile.JunkType.allCases, id: \.self) { type in
                        let group = viewModel.files.filter { $0.type == type }
                        if !group.isEmpty {
                            Section {
                                ForEach($viewModel.files) { $file in
                                    if file.type == type {
                                        JunkFileRowDark(file: $file)
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                    Spacer()
                                    Text("\(group.count) items")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds(.enabled)
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    Button("Select All") { viewModel.toggleAll(true) }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white.opacity(0.8))
                    Button("Deselect All") { viewModel.toggleAll(false) }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button("Clean \(viewModel.selectedCount) Items") {
                        viewModel.cleanSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isCleaning || viewModel.selectedCount == 0)
                }
                .padding()
            }
        }
    }
}

struct JunkFileRowDark: View {
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
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "69F0AE").opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    var typeColor: Color {
        switch file.type {
        case .cache, .systemCache: return .cyan
        case .log: return .yellow
        case .temp: return .orange
        case .download: return .blue
        case .trash: return .red
        }
    }
}
