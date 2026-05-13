import SwiftUI

struct PerformanceLandingView: View {
    @State private var viewModel = PrivacyViewModel()
    @State private var hasScanned = false
    
    var body: some View {
        ZStack {
            if !hasScanned {
                ModuleHero(
                    icon: "bolt.fill",
                    title: "Performance",
                    subtitle: "Run recommended maintenance tasks to optimize your Mac's performance.",
                    accent: Color(hex: "FFAB40"),
                    isScanning: viewModel.isScanning,
                    scanAction: {
                        viewModel.startScan()
                        hasScanned = true
                    }
                )
            } else {
                PrivacyViewDark(viewModel: viewModel)
            }
        }
    }
}

struct PrivacyViewDark: View {
    @Bindable var viewModel: PrivacyViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select privacy traces to remove")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                if viewModel.scanComplete && !viewModel.items.isEmpty {
                    Text("Selected: \(ByteFormatter.string(from: viewModel.totalSize))")
                        .font(.callout.weight(.medium))
                        .foregroundColor(Color(hex: "FFAB40"))
                }
            }
            .padding()
            
            if viewModel.items.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Privacy Clean")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            } else if !viewModel.items.isEmpty {
                List {
                    ForEach($viewModel.items) { $item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $item.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            Image(systemName: item.type.icon)
                                .foregroundColor(Color(hex: "FFAB40"))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.body)
                                    .foregroundColor(.white)
                                if let path = item.url?.path {
                                    Text(path)
                                        .lineLimit(1)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            
                            Spacer()
                            
                            Text(ByteFormatter.string(from: item.size))
                                .font(.caption.weight(.medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "FFAB40").opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
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
                    Button("Clean Selected") {
                        viewModel.cleanSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isCleaning)
                }
                .padding()
            }
        }
    }
}
