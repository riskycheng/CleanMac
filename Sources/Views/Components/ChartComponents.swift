import SwiftUI

// MARK: - Horizontal Bar Chart

struct HorizontalBarChart: View {
    let data: [(label: String, value: Int64, color: Color)]
    let total: Int64
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(data.indices, id: \.self) { i in
                let item = data[i]
                let pct = total > 0 ? Double(item.value) / Double(total) : 0
                
                HStack(spacing: 10) {
                    Text(item.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 100, alignment: .trailing)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 14)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(item.color.opacity(0.8))
                                .frame(width: max(2, geo.size.width * pct), height: 14)
                                .shadow(color: item.color.opacity(0.4), radius: 3)
                        }
                    }
                    .frame(height: 14)
                    
                    Text(ByteFormatter.string(from: item.value))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(item.color)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Donut Chart

struct DonutChart: View {
    let data: [(label: String, value: Int64, color: Color)]
    let total: Int64
    let centerLabel: String
    let centerValue: String
    
    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10
                let innerRadius = radius * 0.65
                
                var startAngle = -Double.pi / 2
                
                for item in data where total > 0 {
                    let sweep = Double(item.value) / Double(total) * 2 * Double.pi
                    let endAngle = startAngle + sweep
                    
                    var path = Path()
                    path.addArc(center: center, radius: radius, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
                    path.addArc(center: center, radius: innerRadius, startAngle: .radians(endAngle), endAngle: .radians(startAngle), clockwise: true)
                    path.closeSubpath()
                    
                    context.fill(path, with: .color(item.color))
                    
                    // Glow effect
                    context.stroke(path, with: .color(item.color.opacity(0.5)), lineWidth: 1)
                    
                    startAngle = endAngle
                }
            }
            .frame(width: 160, height: 160)
            
            VStack(spacing: 2) {
                Text(centerValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(centerLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Legend Row

struct ChartLegend: View {
    let items: [(label: String, color: Color, value: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    Circle()
                        .fill(items[i].color)
                        .frame(width: 8, height: 8)
                    Text(items[i].label)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(items[i].value)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

// MARK: - Stat Card Grid

struct StatGrid: View {
    let stats: [(icon: String, label: String, value: String, color: Color)]
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(stats.indices, id: \.self) { i in
                let stat = stats[i]
                HStack(spacing: 10) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 16))
                        .foregroundColor(stat.color)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(stat.color.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(stat.value)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text(stat.label)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(stat.color.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Top Items Chart

struct TopItemsChart: View {
    let items: [(name: String, size: Int64, color: Color)]
    let maxSize: Int64
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let pct = maxSize > 0 ? Double(item.size) / Double(maxSize) : 0
                
                HStack(spacing: 8) {
                    Text("\(i + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 16)
                    
                    Text(item.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .frame(minWidth: 80, alignment: .leading)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [item.color.opacity(0.8), item.color.opacity(0.4)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(2, geo.size.width * pct), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text(ByteFormatter.string(from: item.size))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Category Breakdown Helper

extension JunkCategory {
    var chartColor: Color {
        switch self {
        case .caches: return .cyan
        case .systemCaches: return .blue
        case .logs: return .green
        case .tempFiles: return .orange
        case .brokenDownloads: return .red
        case .trash: return .purple
        case .orphanedSupport: return .pink
        case .browserCache: return .yellow
        case .xcodeJunk: return .mint
        case .developerCache: return .indigo
        case .systemLogs: return .teal
        case .userLogs: return .green.opacity(0.7)
        }
    }
}

func categoryBreakdown(from files: [JunkFile]) -> [(label: String, value: Int64, color: Color)] {
    let grouped = Dictionary(grouping: files) { $0.category }
    var result: [(label: String, value: Int64, color: Color)] = []
    for (category, items) in grouped {
        let size = items.reduce(0) { $0 + $1.size }
        result.append((label: category.displayName, value: size, color: category.chartColor))
    }
    return result.sorted { $0.value > $1.value }
}

func topItems(from files: [JunkFile], limit: Int = 10) -> [(name: String, size: Int64, color: Color)] {
    let sorted = files.sorted { $0.size > $1.size }
    let top = Array(sorted.prefix(limit))
    let maxSize = top.first?.size ?? 1
    return top.map { (name: $0.name, size: $0.size, color: $0.category.chartColor) }
}
