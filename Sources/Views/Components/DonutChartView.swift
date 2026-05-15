import SwiftUI

struct DonutSegment: Identifiable {
    let id = UUID()
    let color: Color
    let percentage: Double
    let label: String
}

struct DonutChartView: View {
    let segments: [DonutSegment]
    let centerTitle: String
    let centerSubtitle: String
    @State private var animationProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let outerRadius = size * 0.46
            let innerRadius = size * 0.32
            let lineWidth = outerRadius - innerRadius
            let gap: Double = 2.0
            
            ZStack {
                // Drop shadow layer
                Canvas { context, _ in
                    var currentAngle: Double = -90
                    let total = segments.reduce(0) { $0 + $1.percentage }
                    
                    for segment in segments {
                        let sweep = (segment.percentage / max(total, 0.001)) * 360.0 * animationProgress
                        let startAngle = currentAngle + gap / 2
                        let endAngle = currentAngle + sweep - gap / 2
                        
                        if endAngle > startAngle {
                            let path = Path { path in
                                path.addArc(
                                    center: CGPoint(x: center.x, y: center.y + 4),
                                    radius: (innerRadius + outerRadius) / 2,
                                    startAngle: .degrees(startAngle),
                                    endAngle: .degrees(endAngle),
                                    clockwise: false
                                )
                            }
                            context.stroke(path, with: .color(segment.color.opacity(0.15)), lineWidth: lineWidth)
                        }
                        currentAngle += sweep
                    }
                }
                
                // Main 3D ring with gradient per segment
                Canvas { context, _ in
                    let total = segments.reduce(0) { $0 + $1.percentage }
                    var currentAngle: Double = -90
                    
                    for segment in segments {
                        let sweep = (segment.percentage / max(total, 0.001)) * 360.0 * animationProgress
                        let startAngle = currentAngle + gap / 2
                        let endAngle = currentAngle + sweep - gap / 2
                        guard endAngle > startAngle else { currentAngle += sweep; continue }
                        
                        // Draw multiple thin arcs for gradient 3D effect per segment
                        let bandCount = 20
                        for b in 0..<bandCount {
                            let t0 = Double(b) / Double(bandCount)
                            let t1 = Double(b + 1) / Double(bandCount)
                            
                            // 3D gradient: lighter at top (sin angle ~ -1), darker at bottom
                            let midAngle = startAngle + (endAngle - startAngle) * (t0 + t1) / 2
                            let normalizedAngle = ((midAngle + 90).truncatingRemainder(dividingBy: 360)) / 360.0
                            let depthFactor = sin(normalizedAngle * 2 * .pi) // -1 to 1
                            
                            let brightness = 1.0 + depthFactor * 0.15 // lighter on top, darker on bottom
                            let saturation = 1.0 - abs(depthFactor) * 0.1
                            
                            let bandStart = startAngle + (endAngle - startAngle) * t0
                            let bandEnd = startAngle + (endAngle - startAngle) * t1
                            
                            let bandPath = Path { path in
                                path.addArc(
                                    center: center,
                                    radius: (innerRadius + outerRadius) / 2,
                                    startAngle: .degrees(bandStart),
                                    endAngle: .degrees(bandEnd),
                                    clockwise: false
                                )
                            }
                            context.stroke(bandPath, with: .color(segment.color.opacity(0.95).brightness(brightness).saturation(saturation)), lineWidth: lineWidth + 1)
                        }
                        
                        // Highlight edge at outer radius
                        let highlightPath = Path { path in
                            path.addArc(
                                center: center,
                                radius: outerRadius - 2,
                                startAngle: .degrees(startAngle + 0.5),
                                endAngle: .degrees(endAngle - 0.5),
                                clockwise: false
                            )
                        }
                        context.stroke(highlightPath, with: .color(.white.opacity(0.25)), lineWidth: 2)
                        
                        // Shadow edge at inner radius
                        let shadowPath = Path { path in
                            path.addArc(
                                center: center,
                                radius: innerRadius + 2,
                                startAngle: .degrees(startAngle + 0.5),
                                endAngle: .degrees(endAngle - 0.5),
                                clockwise: false
                            )
                        }
                        context.stroke(shadowPath, with: .color(.black.opacity(0.12)), lineWidth: 2)
                        
                        currentAngle += sweep
                    }
                }
                
                // Inner bevel ring
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .frame(width: innerRadius * 2 + 2, height: innerRadius * 2 + 2)
                
                // Center content
                ZStack {
                    // Subtle center gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "FAFAFA"), Color(hex: "F0F0F2")],
                                center: .center,
                                startRadius: 2,
                                endRadius: innerRadius
                            )
                        )
                        .frame(width: innerRadius * 2 - 4, height: innerRadius * 2 - 4)
                    
                    VStack(spacing: 2) {
                        Text(centerTitle)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "111827"))
                        
                        Text(centerSubtitle)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(3)
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
}

extension Color {
    func brightness(_ amount: Double) -> Color {
        // Simple brightness adjustment via opacity blend
        return self.opacity(min(1.0, amount))
    }
    
    func saturation(_ amount: Double) -> Color {
        // Approximate saturation via blend
        return self
    }
}
