import SwiftUI

@MainActor
@Observable
final class OverviewViewModel {
    var diskInfo: SystemInfo.DiskInfo?
    var memoryInfo: SystemInfo.MemoryInfo?
    var cpuInfo: SystemInfo.CPUInfo?
    
    func load() {
        diskInfo = SystemInfo.diskInfo()
        memoryInfo = SystemInfo.memoryInfo()
        cpuInfo = SystemInfo.cpuInfo()
    }
}

struct OverviewView: View {
    let onLaunchSmartCare: () -> Void
    @State private var viewModel = OverviewViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerRow
                .padding(.horizontal, 32)
                .padding(.top, 24)
            
            // Main content: chart + storage breakdown
            HStack(spacing: 0) {
                Spacer()
                
                // Donut chart - centered
                if let disk = viewModel.diskInfo {
                    DonutChartView(
                        segments: donutSegments(disk: disk),
                        centerTitle: "\(Int(disk.usedPercentage * 100))%",
                        centerSubtitle: "USED"
                    )
                    .frame(width: 380, height: 380)
                }
                
                Spacer()
                
                // Storage breakdown - right side
                storageBreakdown
                    .frame(width: 260)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Bottom stats
            bottomStats
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .onAppear { viewModel.load() }
    }
    
    private var headerRow: some View {
        HStack {
            // Left badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "3B82F6"))
                Text("SYSTEM HEALTH OPTIMAL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "3B82F6"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "3B82F6").opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
            
            // Center title
            Text("Macintosh HD")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(Color(hex: "111827"))
            
            Spacer()
            
            // Empty right side to balance
            Color.clear
                .frame(width: 140, height: 1)
        }
    }
    
    private var storageBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STORAGE BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(Color(hex: "9CA3AF"))
            
            // Bar
            if viewModel.diskInfo != nil {
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "3B82F6"))
                            .frame(width: max(4, geo.size.width * 0.55))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E5E7EB"))
                            .frame(width: max(4, geo.size.width * 0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "F472B6"))
                            .frame(width: max(4, geo.size.width * 0.08))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "A78BFA"))
                            .frame(width: max(4, geo.size.width * 0.05))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E5E7EB"))
                            .frame(width: max(4, geo.size.width * 0.17))
                    }
                    .frame(height: 8)
                }
                .frame(height: 8)
            }
            
            // Category list
            VStack(spacing: 8) {
                StorageRow(icon: "doc", iconBg: Color(hex: "EFF6FF"), iconColor: Color(hex: "3B82F6"), label: "Media & Files", value: "342 GB")
                StorageRow(icon: "app", iconBg: Color(hex: "FDF2F8"), iconColor: Color(hex: "F472B6"), label: "Applications", value: "85 GB")
                StorageRow(icon: "trash", iconBg: Color(hex: "F5F3FF"), iconColor: Color(hex: "A78BFA"), label: "System Junk", value: "12.4 GB")
                StorageRow(icon: "externaldrive", iconBg: Color(hex: "F3F4F6"), iconColor: Color(hex: "9CA3AF"), label: "Free Space", value: "145.6 GB")
            }
        }
    }
    
    private var bottomStats: some View {
        HStack(spacing: 14) {
            if let cpu = viewModel.cpuInfo {
                BottomStatCard(
                    icon: "cpu",
                    iconColor: Color(hex: "3B82F6"),
                    label: "PROCESSOR",
                    value: "\(Int(cpu.usagePercentage))%",
                    barColor: Color(hex: "3B82F6"),
                    barProgress: cpu.usagePercentage / 100.0,
                    subValue: "\(cpu.coreCount)-CORE M2 PRO"
                )
            }
            
            if let mem = viewModel.memoryInfo {
                BottomStatCard(
                    icon: "waveform",
                    iconColor: Color(hex: "A855F7"),
                    label: "MEMORY",
                    value: ByteFormatter.string(from: Int64(mem.used)),
                    barColor: Color(hex: "A855F7"),
                    barProgress: mem.usedPercentage,
                    subValue: "\(Int(mem.usedPercentage * 100))% HIGH UTILIZATION"
                )
            }
            
            if let disk = viewModel.diskInfo {
                BottomStatCard(
                    icon: "externaldrive",
                    iconColor: Color(hex: "EF4444"),
                    label: "DISK USAGE",
                    value: "\(Int(disk.usedPercentage * 100))%",
                    barColor: Color(hex: "EF4444"),
                    barProgress: disk.usedPercentage,
                    subValue: "\(ByteFormatter.string(from: disk.used)) / \(ByteFormatter.string(from: disk.total))"
                )
            }
        }
    }
    
    private func donutSegments(disk: SystemInfo.DiskInfo) -> [DonutSegment] {
        [
            DonutSegment(color: Color(hex: "3B82F6"), percentage: 0.55, label: "Media"),
            DonutSegment(color: Color(hex: "E5E7EB"), percentage: 0.15, label: "Apps"),
            DonutSegment(color: Color(hex: "F472B6"), percentage: 0.08, label: "Junk"),
            DonutSegment(color: Color(hex: "A78BFA"), percentage: 0.05, label: "Other"),
        ]
    }
}

struct StorageRow: View {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Color(hex: "9CA3AF"))
                Text(value)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "D1D5DB"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}

struct BottomStatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let barColor: Color
    let barProgress: Double
    let subValue: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "9CA3AF"))
                    
                    Text(value)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E5E7EB"))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: max(4, geo.size.width * CGFloat(barProgress)), height: 4)
                    }
                }
                .frame(width: 80, height: 4)
                
                Text(subValue)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
            
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}
