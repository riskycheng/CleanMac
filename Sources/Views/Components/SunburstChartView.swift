import SwiftUI

struct SunburstSegment: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let size: Int64
    let color: Color
    let icon: String
    
    static func == (lhs: SunburstSegment, rhs: SunburstSegment) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.size == rhs.size && lhs.icon == rhs.icon
    }
}

struct SunburstChartView: View {
    let segments: [SunburstSegment]
    let centerTitle: String
    let centerSubtitle: String
    @Binding var selectedIndex: Int?
    let onSelect: (Int?) -> Void
    
    @State private var animationProgress: Double = 0
    @State private var hoveredIndex: Int? = nil
    
    private var totalSize: Int64 {
        segments.reduce(0) { $0 + $1.size }
    }
    
    private var normalizedSegments: [(segment: SunburstSegment, startAngle: Double, endAngle: Double, percentage: Double)] {
        var result: [(SunburstSegment, Double, Double, Double)] = []
        var currentAngle: Double = -90 // Start from top
        let total = Double(max(totalSize, 1))
        
        for segment in segments {
            let percentage = Double(segment.size) / total
            let sweep = percentage * 360.0 * animationProgress
            result.append((segment, currentAngle, currentAngle + sweep, percentage))
            currentAngle += sweep
        }
        return result
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let outerRadius = size * 0.42
            let innerRadius = size * 0.18
            
            ZStack {
                // Background subtle rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.02), lineWidth: 0.5)
                        .frame(width: (innerRadius + outerRadius) / 2 * CGFloat(i + 1) * 0.8)
                }
                
                // Sunburst wedges
                Canvas { context, _ in
                    let normalized = normalizedSegments
                    
                    for (index, item) in normalized.enumerated() {
                        let isSelected = selectedIndex == index
                        let isHovered = hoveredIndex == index
                        let expand: CGFloat = isSelected ? 6 : (isHovered ? 3 : 0)
                        
                        let path = wedgePath(
                            center: center,
                            innerRadius: innerRadius + expand,
                            outerRadius: outerRadius + expand,
                            startAngle: item.1,
                            endAngle: item.2
                        )
                        
                        // Main fill with subtle gradient
                        var fillColor = item.0.color
                        if isSelected {
                            fillColor = fillColor.opacity(0.95)
                        } else if isHovered {
                            fillColor = fillColor.opacity(0.85)
                        } else {
                            fillColor = fillColor.opacity(0.65)
                        }
                        
                        context.fill(path, with: .color(fillColor))
                        
                        // Inner highlight arc for depth
                        let innerArc = wedgePath(
                            center: center,
                            innerRadius: innerRadius + expand,
                            outerRadius: innerRadius + expand + 2,
                            startAngle: item.1,
                            endAngle: item.2
                        )
                        context.fill(innerArc, with: .color(item.0.color.opacity(0.4)))
                        
                        // Subtle outer glow for selected
                        if isSelected || isHovered {
                            let glowPath = wedgePath(
                                center: center,
                                innerRadius: innerRadius + expand - 1,
                                outerRadius: outerRadius + expand + 2,
                                startAngle: item.1,
                                endAngle: item.2
                            )
                            context.stroke(glowPath, with: .color(item.0.color.opacity(0.5)), lineWidth: 1.5)
                        }
                        
                        // Separator lines
                        let sepPath = separatorPath(
                            center: center,
                            innerRadius: innerRadius + expand,
                            outerRadius: outerRadius + expand,
                            angle: item.1
                        )
                        context.stroke(sepPath, with: .color(Color.black.opacity(0.4)), lineWidth: 1.2)
                    }
                    
                    // Final separator
                    if let last = normalized.last {
                        let sepPath = separatorPath(
                            center: center,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius,
                            angle: last.2
                        )
                        context.stroke(sepPath, with: .color(Color.black.opacity(0.4)), lineWidth: 1.2)
                    }
                }
                
                // Center circle
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "1a1a1a").opacity(0.95),
                                    Color(hex: "121212").opacity(0.98)
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: innerRadius
                            )
                        )
                        .frame(width: innerRadius * 2 - 4, height: innerRadius * 2 - 4)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: innerRadius * 2 - 4, height: innerRadius * 2 - 4)
                    
                    VStack(spacing: 2) {
                        Text(centerTitle)
                            .font(.system(size: min(innerRadius * 0.35, 18), weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(centerSubtitle)
                            .font(.system(size: min(innerRadius * 0.22, 11), weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        guard distance >= innerRadius && distance <= outerRadius + 10 else {
                            onSelect(nil)
                            return
                        }
                        
                        var angle = atan2(dy, dx) * 180 / .pi
                        angle = (angle + 90 + 360).truncatingRemainder(dividingBy: 360)
                        
                        let normalized = normalizedSegments
                        for (index, item) in normalized.enumerated() {
                            let start = (item.1 + 90 + 360).truncatingRemainder(dividingBy: 360)
                            let end = (item.2 + 90 + 360).truncatingRemainder(dividingBy: 360)
                            
                            let inRange: Bool
                            if end < start {
                                inRange = angle >= start || angle <= end
                            } else {
                                inRange = angle >= start && angle < end
                            }
                            
                            if inRange {
                                onSelect(selectedIndex == index ? nil : index)
                                return
                            }
                        }
                        onSelect(nil)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let dx = location.x - center.x
                    let dy = location.y - center.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    guard distance >= innerRadius - 5 && distance <= outerRadius + 10 else {
                        hoveredIndex = nil
                        return
                    }
                    
                    var angle = atan2(dy, dx) * 180 / .pi
                    angle = (angle + 90 + 360).truncatingRemainder(dividingBy: 360)
                    
                    let normalized = normalizedSegments
                    for (index, item) in normalized.enumerated() {
                        let start = (item.1 + 90 + 360).truncatingRemainder(dividingBy: 360)
                        let end = (item.2 + 90 + 360).truncatingRemainder(dividingBy: 360)
                        
                        let inRange: Bool
                        if end < start {
                            inRange = angle >= start || angle <= end
                        } else {
                            inRange = angle >= start && angle < end
                        }
                        
                        if inRange {
                            hoveredIndex = index
                            return
                        }
                    }
                    hoveredIndex = nil
                    
                case .ended:
                    hoveredIndex = nil
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: segments) { _, _ in
            animationProgress = 0
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func wedgePath(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat, startAngle: Double, endAngle: Double) -> Path {
        var path = Path()
        let startRad = (startAngle - 90) * .pi / 180
        let endRad = (endAngle - 90) * .pi / 180
        
        let innerStart = CGPoint(
            x: center.x + innerRadius * cos(startRad),
            y: center.y + innerRadius * sin(startRad)
        )
        let outerStart = CGPoint(
            x: center.x + outerRadius * cos(startRad),
            y: center.y + outerRadius * sin(startRad)
        )
        let innerEnd = CGPoint(
            x: center.x + innerRadius * cos(endRad),
            y: center.y + innerRadius * sin(endRad)
        )
        
        path.move(to: innerStart)
        path.addLine(to: outerStart)
        path.addArc(center: center, radius: outerRadius, startAngle: .radians(startRad), endAngle: .radians(endRad), clockwise: false)
        path.addLine(to: innerEnd)
        path.addArc(center: center, radius: innerRadius, startAngle: .radians(endRad), endAngle: .radians(startRad), clockwise: true)
        path.closeSubpath()
        
        return path
    }
    
    private func separatorPath(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat, angle: Double) -> Path {
        var path = Path()
        let rad = (angle - 90) * .pi / 180
        let inner = CGPoint(
            x: center.x + innerRadius * cos(rad),
            y: center.y + innerRadius * sin(rad)
        )
        let outer = CGPoint(
            x: center.x + outerRadius * cos(rad),
            y: center.y + outerRadius * sin(rad)
        )
        path.move(to: inner)
        path.addLine(to: outer)
        return path
    }
}

// MARK: - Legend

struct SunburstLegendView: View {
    let segments: [SunburstSegment]
    let totalSize: Int64
    @Binding var selectedIndex: Int?
    let onSelect: (Int?) -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    LegendRow(
                        segment: segment,
                        percentage: Double(segment.size) / Double(max(totalSize, 1)),
                        isSelected: selectedIndex == index,
                        isOthers: false
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onSelect(selectedIndex == index ? nil : index)
                        }
                    }
                }
            }
        }
    }
}

struct LegendRow: View {
    let segment: SunburstSegment
    let percentage: Double
    let isSelected: Bool
    let isOthers: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Color dot
            Circle()
                .fill(segment.color.opacity(isSelected ? 1.0 : 0.7))
                .frame(width: 8, height: 8)
            
            // Icon
            Image(systemName: segment.icon)
                .font(.system(size: 12))
                .foregroundColor(segment.color.opacity(0.7))
                .frame(width: 16, height: 16)
            
            // Name
            Text(segment.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .lineLimit(1)
            
            Spacer()
            
            // Percentage
            Text(String(format: "%.1f%%", percentage * 100))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
            
            // Size
            Text(ByteFormatter.string(from: segment.size))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.4))
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? segment.color.opacity(0.12) : (isHovered ? Color.white.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? segment.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Detail Panel for selected segment

struct SunburstDetailPanel: View {
    let segment: SunburstSegment
    let files: [JunkFile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: segment.icon)
                        .font(.system(size: 14))
                        .foregroundColor(segment.color)
                    
                    Text(segment.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(files.count) items · \(ByteFormatter.string(from: files.reduce(0) { $0 + $1.size }))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }
            
            Divider().background(Color.white.opacity(0.06))
            
            LazyVStack(spacing: 3) {
                ForEach(files.prefix(30)) { file in
                    @Bindable var bindableFile = file
                    HStack {
                        Toggle("", isOn: $bindableFile.isSelected)
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                        
                        Text(file.name)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(ByteFormatter.string(from: file.size))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(file.isSelected ? segment.color.opacity(0.06) : Color.clear)
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Color Extension

extension JunkCategory {
    var chartColor: Color {
        switch self {
        case .caches: return Color(hex: "4ECDC4")
        case .systemCaches: return Color(hex: "45B7D1")
        case .logs: return Color(hex: "96CEB4")
        case .tempFiles: return Color(hex: "FECA57")
        case .brokenDownloads: return Color(hex: "FF6B6B")
        case .trash: return Color(hex: "A29BFE")
        case .orphanedSupport: return Color(hex: "FD79A8")
        case .browserCache: return Color(hex: "FDCB6E")
        case .xcodeJunk: return Color(hex: "00B894")
        case .developerCache: return Color(hex: "6C5CE7")
        case .systemLogs: return Color(hex: "74B9FF")
        case .userLogs: return Color(hex: "55EFC4")
        }
    }
}
