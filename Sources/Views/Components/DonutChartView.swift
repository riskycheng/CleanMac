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
    @Binding var hoveredIndex: Int?
    @State private var animationProgress: Double = 0
    
    // Pre-computed angles — stable, no GeometryReader dependency
    private func segmentAngles(progress: Double) -> [(start: Double, end: Double)] {
        let total = segments.reduce(0) { $0 + $1.percentage }
        var angles: [(start: Double, end: Double)] = []
        var currentAngle: Double = -90
        let gap: Double = 2.0
        for segment in segments {
            let sweep = (segment.percentage / max(total, 0.001)) * 360.0 * progress
            let start = currentAngle + gap / 2
            let end = currentAngle + sweep - gap / 2
            angles.append((start, max(start, end)))
            currentAngle += sweep
        }
        return angles
    }
    
    var body: some View {
        ZStack {
            // MARK: Main drawing
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let localCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let outerRadius = size * 0.46
                let innerRadius = size * 0.32
                let lineWidth = outerRadius - innerRadius
                let angles = segmentAngles(progress: animationProgress)
                
                ZStack {
                    // Drop shadow layer
                    Canvas { context, _ in
                        for (i, segment) in segments.enumerated() {
                            let (startAngle, endAngle) = angles[i]
                            guard endAngle > startAngle else { continue }
                            let path = Path { path in
                                path.addArc(
                                    center: CGPoint(x: localCenter.x, y: localCenter.y + 4),
                                    radius: (innerRadius + outerRadius) / 2,
                                    startAngle: .degrees(startAngle),
                                    endAngle: .degrees(endAngle),
                                    clockwise: false
                                )
                            }
                            context.stroke(path, with: .color(segment.color.opacity(0.15)), lineWidth: lineWidth)
                        }
                    }
                    
                    // Main 3D ring — all segments normally
                    Canvas { context, _ in
                        for (i, segment) in segments.enumerated() {
                            let (startAngle, endAngle) = angles[i]
                            guard endAngle > startAngle else { continue }
                            
                            let bandCount = 20
                            for b in 0..<bandCount {
                                let t0 = Double(b) / Double(bandCount)
                                let t1 = Double(b + 1) / Double(bandCount)
                                let midAngle = startAngle + (endAngle - startAngle) * (t0 + t1) / 2
                                let normalizedAngle = ((midAngle + 90).truncatingRemainder(dividingBy: 360)) / 360.0
                                let depthFactor = sin(normalizedAngle * 2 * .pi)
                                let brightness = 1.0 + depthFactor * 0.15
                                let saturation = 1.0 - abs(depthFactor) * 0.1
                                let bandStart = startAngle + (endAngle - startAngle) * t0
                                let bandEnd = startAngle + (endAngle - startAngle) * t1
                                let bandPath = Path { path in
                                    path.addArc(
                                        center: localCenter,
                                        radius: (innerRadius + outerRadius) / 2,
                                        startAngle: .degrees(bandStart),
                                        endAngle: .degrees(bandEnd),
                                        clockwise: false
                                    )
                                }
                                let baseColor = segment.color.opacity(0.95).brightness(brightness).saturation(saturation)
                                context.stroke(bandPath, with: .color(baseColor), lineWidth: lineWidth + 1)
                            }
                            
                            let highlightPath = Path { path in
                                path.addArc(center: localCenter, radius: outerRadius - 2, startAngle: .degrees(startAngle + 0.5), endAngle: .degrees(endAngle - 0.5), clockwise: false)
                            }
                            context.stroke(highlightPath, with: .color(.white.opacity(0.25)), lineWidth: 2)
                            
                            let shadowPath = Path { path in
                                path.addArc(center: localCenter, radius: innerRadius + 2, startAngle: .degrees(startAngle + 0.5), endAngle: .degrees(endAngle - 0.5), clockwise: false)
                            }
                            context.stroke(shadowPath, with: .color(.black.opacity(0.12)), lineWidth: 2)
                        }
                    }
                    
                    // Inner bevel ring
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 1).frame(width: innerRadius * 2, height: innerRadius * 2)
                    Circle().stroke(Color.black.opacity(0.06), lineWidth: 1).frame(width: innerRadius * 2 + 2, height: innerRadius * 2 + 2)
                    
                    // Center content
                    ZStack {
                        Circle().fill(RadialGradient(colors: [Color(hex: "FAFAFA"), Color(hex: "F0F0F2")], center: .center, startRadius: 2, endRadius: innerRadius)).frame(width: innerRadius * 2 - 4, height: innerRadius * 2 - 4)
                        VStack(spacing: 2) {
                            Text(centerTitle).font(.system(size: 48, weight: .black, design: .rounded)).foregroundColor(Color(hex: "111827"))
                            Text(centerSubtitle).font(.system(size: 11, weight: .bold)).tracking(3).foregroundColor(Color(hex: "9CA3AF"))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // MARK: Hovered segment overlay (ALWAYS in view tree, animates via opacity + scale)
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let localCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let outerRadius = size * 0.46 + 4
                let innerRadius = size * 0.32 + 4
                let lineWidth = outerRadius - innerRadius
                let angles = segmentAngles(progress: animationProgress)
                
                Canvas { context, _ in
                    guard let hovered = hoveredIndex, hovered < segments.count else { return }
                    let (startAngle, endAngle) = angles[hovered]
                    let segment = segments[hovered]
                    guard endAngle > startAngle else { return }
                    
                    // Shadow beneath
                    let shadowPath = Path { path in
                        path.addArc(center: CGPoint(x: localCenter.x, y: localCenter.y + 8), radius: (innerRadius + outerRadius) / 2, startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: false)
                    }
                    context.stroke(shadowPath, with: .color(segment.color.opacity(0.2)), lineWidth: lineWidth + 2)
                    
                    // 3D bands brighter
                    for b in 0..<24 {
                        let t0 = Double(b) / 24.0
                        let t1 = Double(b + 1) / 24.0
                        let midAngle = startAngle + (endAngle - startAngle) * (t0 + t1) / 2
                        let normalizedAngle = ((midAngle + 90).truncatingRemainder(dividingBy: 360)) / 360.0
                        let depthFactor = sin(normalizedAngle * 2 * .pi)
                        let brightness = 1.0 + depthFactor * 0.15 + 0.18
                        let bandStart = startAngle + (endAngle - startAngle) * t0
                        let bandEnd = startAngle + (endAngle - startAngle) * t1
                        let bandPath = Path { path in
                            path.addArc(center: localCenter, radius: (innerRadius + outerRadius) / 2, startAngle: .degrees(bandStart), endAngle: .degrees(bandEnd), clockwise: false)
                        }
                        context.stroke(bandPath, with: .color(segment.color.opacity(1.0).brightness(brightness)), lineWidth: lineWidth + 1)
                    }
                    
                    // Highlight edge
                    let hPath = Path { path in
                        path.addArc(center: localCenter, radius: outerRadius - 2, startAngle: .degrees(startAngle + 0.5), endAngle: .degrees(endAngle - 0.5), clockwise: false)
                    }
                    context.stroke(hPath, with: .color(.white.opacity(0.5)), lineWidth: 2)
                    
                    // Inner shadow
                    let sPath = Path { path in
                        path.addArc(center: localCenter, radius: innerRadius + 2, startAngle: .degrees(startAngle + 0.5), endAngle: .degrees(endAngle - 0.5), clockwise: false)
                    }
                    context.stroke(sPath, with: .color(.black.opacity(0.18)), lineWidth: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(hoveredIndex != nil ? 1 : 0)
            .scaleEffect(hoveredIndex != nil ? 1.03 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hoveredIndex)
            
            // MARK: Stable hit-test layer (always on top, never changes structure)
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let size = min(geo.size.width, geo.size.height)
                let outerR = size * 0.46 + 30
                let innerR = max(0, size * 0.32 - 30)
                let angles = segmentAngles(progress: animationProgress)
                
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let dx = location.x - center.x
                            let dy = location.y - center.y
                            let distance = sqrt(dx * dx + dy * dy)
                            
                            if distance >= innerR && distance <= outerR {
                                var angle = atan2(dy, dx) * 180 / .pi
                                angle = angle + 90
                                if angle < 0 { angle += 360 }
                                
                                for (i, (start, end)) in angles.enumerated() {
                                    // Convert path angles (0°=right, 90°=bottom) to visual angles (0°=top, 90°=right)
                                    let visStart = (start + 90).truncatingRemainder(dividingBy: 360)
                                    let visEnd = (end + 90).truncatingRemainder(dividingBy: 360)
                                    let isInSegment: Bool
                                    if visStart <= visEnd {
                                        isInSegment = angle >= visStart && angle <= visEnd
                                    } else {
                                        isInSegment = angle >= visStart || angle <= visEnd
                                    }
                                    if isInSegment {
                                        if hoveredIndex != i {
                                            hoveredIndex = i
                                        }
                                        return
                                    }
                                }
                            }
                            if hoveredIndex != nil {
                                hoveredIndex = nil
                            }
                        case .ended:
                            if hoveredIndex != nil {
                                hoveredIndex = nil
                            }
                        }
                    }
            }
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
        return self.opacity(min(1.0, amount))
    }
    func saturation(_ amount: Double) -> Color {
        return self
    }
}
