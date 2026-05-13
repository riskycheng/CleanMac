import SwiftUI

struct ScoreRing: View {
    let score: Int
    let size: CGFloat
    
    var color: Color {
        if score >= 80 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: size * 0.08)
            
            Circle()
                .trim(from: 0, to: CGFloat(min(score, 100)) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: score)
        }
        .frame(width: size, height: size)
        .overlay(
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Health")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        )
    }
}

struct ModuleHero: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let isScanning: Bool
    let scanAction: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Large icon with glow effect
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 100, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: accent.opacity(0.5), radius: 20, x: 0, y: 0)
            }
            .frame(height: 220)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            
            Spacer()
            
            CircularScanButton(
                isScanning: isScanning,
                accent: accent,
                action: scanAction
            )
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CircularScanButton: View {
    let isScanning: Bool
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(accent.opacity(0.3))
                    .frame(width: 90, height: 90)
                    .blur(radius: 20)
                
                // Button background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.8), accent.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                if isScanning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Text("Scan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
    }
}

struct GlassCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let buttonText: String
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: action) {
                    Text(buttonText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(16)
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
