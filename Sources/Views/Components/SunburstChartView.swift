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

// MARK: - Sunburst Chart

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
        var currentAngle: Double = -90
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
            let outerRadius = size * 0.44
            let innerRadius = size * 0.24
            let gapAngle: Double = 1.5 // degrees between wedges
            
            ZStack {
                // Subtle concentric rings for depth
                ForEach(0..<4) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.015 + Double(i) * 0.008), lineWidth: 0.5)
                        .frame(width: innerRadius * 2 + CGFloat(i) * (outerRadius - innerRadius) * 0.5)
                }
                
                // Glow behind chart
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                selectedIndex != nil
                                ? segments[safe: selectedIndex!]?.color.opacity(0.08) ?? Color.white.opacity(0.03)
                                : Color.white.opacity(0.02),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: innerRadius,
                            endRadius: outerRadius + 30
                        )
                    )
                    .frame(width: (outerRadius + 30) * 2, height: (outerRadius + 30) * 2)
                
                Canvas { context, _ in
                    let normalized = normalizedSegments
                    
                    for (index, item) in normalized.enumerated() {
                        let isSelected = selectedIndex == index
                        let isHovered = hoveredIndex == index
                        let expand: CGFloat = isSelected ? 8 : (isHovered ? 4 : 0)
                        
                        let startA = item.1 + (gapAngle / 2)
                        let endA = item.2 - (gapAngle / 2)
                        
                        guard endA > startA else { continue }
                        
                        // Main wedge path
                        _ = wedgePath(
                            center: center,
                            innerRadius: innerRadius + expand,
                            outerRadius: outerRadius + expand,
                            startAngle: startA,
                            endAngle: endA
                        )
                        
                        // Gradient fill for 3D depth
                        let baseColor = item.0.color
                        
                        // Draw gradient wedge using multiple thin arcs
                        let steps = 24
                        for s in 0..<steps {
                            let t0 = Double(s) / Double(steps)
                            let t1 = Double(s + 1) / Double(steps)
                            let r0 = innerRadius + expand + (outerRadius - innerRadius) * CGFloat(t0)
                            let r1 = innerRadius + expand + (outerRadius - innerRadius) * CGFloat(t1)
                            
                            let interpColor = baseColor.opacity(
                                isSelected
                                ? 0.95 - t0 * 0.35
                                : 0.8 - t0 * 0.4
                            )
                            
                            let bandPath = wedgePath(
                                center: center,
                                innerRadius: r0,
                                outerRadius: r1,
                                startAngle: startA + 0.3,
                                endAngle: endA - 0.3
                            )
                            context.fill(bandPath, with: .color(interpColor))
                        }
                        
                        // Highlight arc at outer edge
                        let highlightPath = wedgePath(
                            center: center,
                            innerRadius: outerRadius + expand - 3,
                            outerRadius: outerRadius + expand,
                            startAngle: startA + 0.5,
                            endAngle: endA - 0.5
                        )
                        context.fill(highlightPath, with: .color(baseColor.opacity(0.5)))
                        
                        // Shadow/glow for selected
                        if isSelected {
                            let glowPath = wedgePath(
                                center: center,
                                innerRadius: innerRadius + expand - 2,
                                outerRadius: outerRadius + expand + 4,
                                startAngle: startA - 0.5,
                                endAngle: endA + 0.5
                            )
                            context.stroke(glowPath, with: .color(baseColor.opacity(0.35)), lineWidth: 2)
                        }
                    }
                    
                    // Separators
                    for (_, item) in normalizedSegments.enumerated() {
                        let sepPath = separatorPath(
                            center: center,
                            innerRadius: innerRadius - 2,
                            outerRadius: outerRadius + 2,
                            angle: item.1
                        )
                        context.stroke(sepPath, with: .color(Color.black.opacity(0.5)), lineWidth: 1.5)
                    }
                    
                    if let last = normalized.last {
                        let sepPath = separatorPath(
                            center: center,
                            innerRadius: innerRadius - 2,
                            outerRadius: outerRadius + 2,
                            angle: last.2
                        )
                        context.stroke(sepPath, with: .color(Color.black.opacity(0.5)), lineWidth: 1.5)
                    }
                }
                
                // Center circle
                ZStack {
                    // Outer ring glow
                    Circle()
                        .stroke(
                            selectedIndex != nil
                            ? segments[safe: selectedIndex!]?.color.opacity(0.15) ?? Color.white.opacity(0.05)
                            : Color.white.opacity(0.05),
                            lineWidth: 1.5
                        )
                        .frame(width: innerRadius * 2 + 4, height: innerRadius * 2 + 4)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "1c1c1e").opacity(0.98),
                                    Color(hex: "141414").opacity(0.99)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: innerRadius
                            )
                        )
                        .frame(width: innerRadius * 2 - 2, height: innerRadius * 2 - 2)
                        .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: innerRadius * 2 - 2, height: innerRadius * 2 - 2)
                    
                    VStack(spacing: 2) {
                        Text(centerTitle)
                            .font(.system(size: min(innerRadius * 0.32, 20), weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(centerSubtitle)
                            .font(.system(size: min(innerRadius * 0.2, 11), weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleTap(at: value.location, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    handleHover(at: location, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
                case .ended:
                    hoveredIndex = nil
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) {
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
    
    private func handleTap(at point: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance >= innerRadius - 10 && distance <= outerRadius + 15 else {
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
    
    private func handleHover(at point: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance >= innerRadius - 10 && distance <= outerRadius + 15 else {
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
                        isSelected: selectedIndex == index
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
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Color indicator
            ZStack {
                Circle()
                    .fill(segment.color.opacity(isSelected ? 0.25 : 0.12))
                    .frame(width: 22, height: 22)
                
                Circle()
                    .fill(segment.color)
                    .frame(width: 8, height: 8)
            }
            
            // Icon
            Image(systemName: segment.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(segment.color.opacity(isSelected ? 0.9 : 0.6))
                .frame(width: 18, height: 18)
            
            // Name
            Text(segment.name)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                .lineLimit(1)
            
            Spacer()
            
            // Percentage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 40, height: 4)
                    
                    Capsule()
                        .fill(segment.color.opacity(isSelected ? 0.8 : 0.5))
                        .frame(width: max(4, CGFloat(percentage) * 40), height: 4)
                }
            }
            .frame(width: 40, height: 12)
            
            // Percentage text
            Text(String(format: "%.1f%%", percentage * 100))
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? segment.color.opacity(0.9) : .white.opacity(0.3))
                .frame(width: 42, alignment: .trailing)
            
            // Size
            Text(ByteFormatter.string(from: segment.size))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.85) : .white.opacity(0.45))
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? segment.color.opacity(0.1)
                      : (isHovered ? Color.white.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? segment.color.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Detail Panel

struct SunburstDetailPanel: View {
    let segment: SunburstSegment
    let files: [JunkFile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(segment.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: segment.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(segment.color)
                    }
                    
                    Text(segment.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("\(files.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("items")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                    
                    Text(ByteFormatter.string(from: files.reduce(0) { $0 + $1.size }))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(segment.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                segment.color.opacity(0.04)
            )
            
            Divider().background(Color.white.opacity(0.06))
            
            // File list - scrollable
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                        @Bindable var bindableFile = file
                        FileListRow(file: file, color: segment.color, isEven: index % 2 == 0)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "161618").opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(segment.color.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct FileListRow: View {
    let file: JunkFile
    let color: Color
    let isEven: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { file.isSelected },
                set: { file.isSelected = $0 }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            
            // File type indicator
            Circle()
                .fill(file.isSelected ? color.opacity(0.6) : color.opacity(0.2))
                .frame(width: 6, height: 6)
            
            Text(file.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(file.isSelected ? .white.opacity(0.9) : .white.opacity(0.55))
                .lineLimit(1)
            
            Spacer()
            
            Text(ByteFormatter.string(from: file.size))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(file.isSelected ? color.opacity(0.8) : .white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            isEven
            ? (isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.015))
            : (isHovered ? Color.white.opacity(0.04) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - App Detail Panel

struct AppDetailPanel: View {
    let apps: [AppBundle]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "5B8DEF").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "app")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "5B8DEF"))
                    }
                    
                    Text("Applications")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("\(apps.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("apps")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                    
                    Text(ByteFormatter.string(from: apps.reduce(0) { $0 + $1.totalSize }))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "5B8DEF"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(hex: "5B8DEF").opacity(0.04)
            )
            
            Divider().background(Color.white.opacity(0.06))
            
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        @Bindable var bindableApp = app
                        AppListRow(app: app, isEven: index % 2 == 0)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "161618").opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "5B8DEF").opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct AppListRow: View {
    let app: AppBundle
    let isEven: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { app.isSelected = $0 }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            
            Circle()
                .fill(app.isSelected ? Color(hex: "5B8DEF").opacity(0.6) : Color(hex: "5B8DEF").opacity(0.2))
                .frame(width: 6, height: 6)
            
            Text(app.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(app.isSelected ? .white.opacity(0.9) : .white.opacity(0.55))
                .lineLimit(1)
            
            Spacer()
            
            Text(ByteFormatter.string(from: app.totalSize))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(app.isSelected ? Color(hex: "5B8DEF").opacity(0.8) : .white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            isEven
            ? (isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.015))
            : (isHovered ? Color.white.opacity(0.04) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

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
