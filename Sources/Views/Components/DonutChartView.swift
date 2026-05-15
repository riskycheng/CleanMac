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
            let outerRadius = size * 0.44
            let innerRadius = size * 0.30
            let lineWidth = outerRadius - innerRadius
            let gap: Double = 2.5
            
            ZStack {
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
                                    center: center,
                                    radius: (innerRadius + outerRadius) / 2,
                                    startAngle: .degrees(startAngle),
                                    endAngle: .degrees(endAngle),
                                    clockwise: false
                                )
                            }
                            context.stroke(path, with: .color(segment.color), lineWidth: lineWidth)
                        }
                        
                        currentAngle += sweep
                    }
                }
                
                // Center
                VStack(spacing: 0) {
                    Text(centerTitle)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "111827"))
                    Text(centerSubtitle)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
}
