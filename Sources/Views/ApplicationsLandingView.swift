import SwiftUI

struct ApplicationsLandingView: View {
    @State private var viewModel = UninstallerViewModel()
    @State private var hasScanned = false
    
    var body: some View {
        ZStack {
            if !hasScanned {
                ModuleHero(
                    icon: "square.grid.2x2",
                    title: "Applications",
                    subtitle: "Take control of your applications. Uninstall, update or remove old application leftovers.",
                    accent: Color(hex: "448AFF"),
                    isScanning: viewModel.isScanning,
                    scanAction: {
                        viewModel.startScan()
                        hasScanned = true
                    }
                )
            } else {
                UninstallerViewDark(viewModel: viewModel)
            }
        }
    }
}

struct UninstallerViewDark: View {
    @Bindable var viewModel: UninstallerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uninstaller")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select apps to uninstall with leftovers")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                if viewModel.scanComplete && !viewModel.apps.isEmpty {
                    Text("\(viewModel.selectedApps.count) selected")
                        .font(.callout.weight(.medium))
                        .foregroundColor(Color(hex: "448AFF"))
                }
            }
            .padding()
            
            if viewModel.apps.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Apps Found")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            } else if !viewModel.apps.isEmpty {
                List {
                    ForEach($viewModel.apps) { $app in
                        AppBundleRowDark(app: $app)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    Spacer()
                    Button("Uninstall \(viewModel.selectedApps.count) Apps") {
                        viewModel.uninstallSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isUninstalling || viewModel.selectedApps.isEmpty)
                }
                .padding()
            }
        }
    }
}

struct AppBundleRowDark: View {
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
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "448AFF").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text(app.version ?? "Unknown version")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                        Text(app.formattedLastUsed)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(app.formattedSize)
                    .font(.callout.weight(.medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "448AFF").opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            if app.isSelected && !app.leftovers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associated Files")
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
