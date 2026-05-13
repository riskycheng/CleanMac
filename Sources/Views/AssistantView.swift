import SwiftUI

struct AssistantView: View {
    @State private var viewModel = SmartScanViewModel()
    @State private var diskInfo = (total: Int64(0), free: Int64(0), used: Int64(0))
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                // Left panel: Health ring
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    ZStack {
                        // Outer glow ring
                        Circle()
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 4)
                            .frame(width: 280, height: 280)
                            .blur(radius: 10)
                        
                        // Animated health ring
                        HealthRing(score: viewModel.healthScore, size: 260)
                        
                        // Center content
                        VStack(spacing: 4) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.8))
                            Text(macModelName())
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 300)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Mac Health:")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            Text(healthText)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(healthColor)
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Text("Your Mac is in \(healthText.lowercased()) shape. Run some maintenance to make it perform even better.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: 320, alignment: .leading)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                // Right panel: Recommendation cards
                VStack(spacing: 16) {
                    Spacer().frame(height: 20)
                    
                    GlassCard(
                        icon: "sparkles.tv",
                        iconColor: .pink,
                        title: "It's time to care for your Mac!",
                        description: "It's been a while since your last cleanup. Run Smart Care regularly to keep your Mac in shape.",
                        buttonText: "Run Smart Care",
                        action: {}
                    )
                    
                    GlassCard(
                        icon: "arrow.up.circle.fill",
                        iconColor: .blue,
                        title: "Install application updates",
                        description: "Some applications may be ready to be updated. Install the latest versions to use new features and stay secure.",
                        buttonText: "Update My Applications",
                        action: {}
                    )
                    
                    GlassCard(
                        icon: "xmark.app.fill",
                        iconColor: .cyan,
                        title: "Uninstall unused apps",
                        description: "You may have applications you haven't used for a very long time. Review and uninstall the ones you don't need.",
                        buttonText: "Review Unused Applications",
                        action: {}
                    )
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            viewModel.startSmartScan()
            Task {
                let info = await SystemProfiler.shared.diskSpaceInfo()
                await MainActor.run {
                    diskInfo = info
                }
            }
        }
    }
    
    var healthText: String {
        if viewModel.healthScore >= 80 { return "Good" }
        if viewModel.healthScore >= 50 { return "Fair" }
        return "Poor"
    }
    
    var healthColor: Color {
        if viewModel.healthScore >= 80 { return .green }
        if viewModel.healthScore >= 50 { return .yellow }
        return .red
    }
    
    func macModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let name = String(decoding: model.map(UInt8.init), as: UTF8.self)
        // Simplify common names
        if name.contains("MacBookPro") { return "MacBook Pro" }
        if name.contains("MacBookAir") { return "MacBook Air" }
        if name.contains("MacBook") { return "MacBook" }
        if name.contains("Macmini") { return "Mac mini" }
        if name.contains("MacStudio") { return "Mac Studio" }
        if name.contains("MacPro") { return "Mac Pro" }
        if name.contains("iMac") { return "iMac" }
        return name.isEmpty ? "Mac" : name
    }
}

struct HealthRing: View {
    let score: Int
    let size: CGFloat
    
    var color: Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
            
            // Progress ring with glow
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: 10, x: 0, y: 0)
                .animation(.easeInOut(duration: 1.0), value: score)
            
            // Inner gradient fill
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [color.opacity(0.15), Color.clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
        }
        .frame(width: size, height: size)
    }
}
