import SwiftUI

struct SmartCareView: View {
    @State private var viewModel = SmartScanViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.scanComplete {
                // After scan, show summary cards
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Scan Complete")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.top, 40)
                        
                        ScoreRing(score: viewModel.healthScore, size: 160)
                            .padding(.vertical, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            resultCard(
                                icon: "trash",
                                title: ByteFormatter.string(from: viewModel.totalJunkSize),
                                subtitle: "Junk to clean",
                                color: .cyan
                            )
                            resultCard(
                                icon: "shield",
                                title: "\(viewModel.threatCount) threats",
                                subtitle: viewModel.threatCount == 0 ? "You're safe" : "Action needed",
                                color: viewModel.threatCount > 0 ? .red : .green
                            )
                            resultCard(
                                icon: "eye.slash",
                                title: "\(viewModel.privacyItemCount) items",
                                subtitle: "Privacy traces",
                                color: .purple
                            )
                            resultCard(
                                icon: "doc.text.magnifyingglass",
                                title: "\(viewModel.largeFileCount) files",
                                subtitle: "Large or old files",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 40)
                        
                        Button("Scan Again") {
                            viewModel.startSmartScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Landing state
                ModuleHero(
                    icon: "sparkles.tv",
                    title: "Welcome back!",
                    subtitle: "Start with a quick and extensive scan of your Mac.",
                    accent: .purple,
                    isScanning: viewModel.isScanning,
                    scanAction: { viewModel.startSmartScan() }
                )
            }
            
            if viewModel.isScanning {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Scanning your Mac...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4))
            }
        }
    }
    
    func resultCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
