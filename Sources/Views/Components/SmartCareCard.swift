import SwiftUI

struct SmartCareCard: View {
    let result: ScanModuleResult
    let isActive: Bool
    let showCheckbox: Bool
    let showReview: Bool
    let onToggle: (() -> Void)?
    let onReview: (() -> Void)?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: result.type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if showCheckbox && result.hasIssues {
                        Button(action: { onToggle?() }) {
                            Image(systemName: result.isSelected ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(result.isSelected ? result.type.accent : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    } else if showCheckbox && !result.hasIssues {
                        Image(systemName: "square")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    
                    Text(result.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    // Module icon with glow
                    Image(systemName: result.type.icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(result.type.accent.opacity(0.8))
                        .shadow(color: result.type.accent.opacity(0.4), radius: 12, x: 0, y: 0)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.primaryText)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(result.secondaryText)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                if showReview && result.hasIssues {
                    HStack {
                        Spacer()
                        Button(action: { onReview?() }) {
                            Text("Review")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .overlay(
            // Active glow overlay
            RoundedRectangle(cornerRadius: 20)
                .stroke(result.type.accent.opacity(isActive ? 0.5 : 0), lineWidth: 2)
                .shadow(color: result.type.accent.opacity(isActive ? 0.3 : 0), radius: 20, x: 0, y: 0)
        )
    }
}

struct CompletedCard: View {
    let result: ScanModuleResult
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: result.type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(result.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    
                    Image(systemName: result.type.icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(result.type.accent.opacity(0.8))
                        .shadow(color: result.type.accent.opacity(0.4), radius: 12, x: 0, y: 0)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.primaryText)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: result.completionStatus.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(result.completionStatus.color)
                        
                        Text(result.completionSubtext)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(result.completionStatus.color)
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
    }
}

struct ActiveScanCard: View {
    let type: ScanModuleType
    let title: String
    let subtitle: String
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            VStack(spacing: 0) {
                HStack {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                
                Spacer()
                
                // Animated icon
                ZStack {
                    Circle()
                        .fill(type.accent.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 70, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [type.accent.opacity(0.9), type.accent.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: type.accent.opacity(0.5), radius: 20, x: 0, y: 0)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                }
                .frame(height: 160)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
                .onDisappear {
                    isAnimating = false
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(type.accent.opacity(0.4), lineWidth: 2)
                .shadow(color: type.accent.opacity(0.3), radius: 20, x: 0, y: 0)
        )
    }
}

struct ProcessingDetailCard: View {
    let result: ScanModuleResult
    let currentItemIndex: Int
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: result.type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(result.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }
                
                Text(result.type.processingTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                // Detail items list
                VStack(spacing: 12) {
                    ForEach(result.detailItems.prefix(4)) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.status.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(item.status.color)
                                .frame(width: 20)
                            
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if item.size > 0 {
                                Text(ByteFormatter.string(from: item.size))
                                    .font(.system(size: 13).monospacedDigit())
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            if item.status == .processing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else if item.status == .done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(result.type.accent.opacity(0.4), lineWidth: 2)
                .shadow(color: result.type.accent.opacity(0.3), radius: 20, x: 0, y: 0)
        )
    }
}


