import SwiftUI

struct ProtectionLandingView: View {
    @State private var viewModel = MalwareViewModel()
    @State private var hasScanned = false
    
    var body: some View {
        ZStack {
            if !hasScanned {
                ModuleHero(
                    icon: "hand.raised.fill",
                    title: "Protection",
                    subtitle: "Check your Mac for all kinds of threats and vulnerabilities.",
                    accent: Color(hex: "FF4081"),
                    isScanning: viewModel.isScanning,
                    scanAction: {
                        viewModel.startScan()
                        hasScanned = true
                    }
                )
            } else {
                MalwareViewDark(viewModel: viewModel)
            }
        }
    }
}

struct MalwareViewDark: View {
    @Bindable var viewModel: MalwareViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Malware Removal")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select threats to remove")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                if viewModel.scanComplete && !viewModel.threats.isEmpty {
                    Text("\(viewModel.selectedCount) selected")
                        .font(.callout.weight(.medium))
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            if viewModel.threats.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Threats Found")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            } else if !viewModel.threats.isEmpty {
                List {
                    ForEach($viewModel.threats) { $threat in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $threat.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            Image(systemName: threat.severity.icon)
                                .foregroundColor(severityColor(threat.severity))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(threat.name)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.white)
                                Text(threat.path)
                                    .lineLimit(1)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                Text(threat.type.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityColor(threat.severity).opacity(0.15))
                                    .foregroundColor(severityColor(threat.severity))
                                    .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            Text(threat.severity.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(severityColor(threat.severity))
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
                    Button("Remove Threats") {
                        viewModel.removeSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isRemoving || viewModel.selectedCount == 0)
                }
                .padding()
            }
        }
    }
    
    func severityColor(_ severity: MalwareThreat.Severity) -> Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}
