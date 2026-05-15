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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                headerRow
                
                // Main content
                HStack(alignment: .top, spacing: 32) {
                    // Donut chart
                    if let disk = viewModel.diskInfo {
                        DonutChartView(
                            segments: donutSegments(disk: disk),
                            centerTitle: "\(Int(disk.usedPercentage * 100))%",
                            centerSubtitle: "USED"
                        )
                        .frame(width: 320, height: 320)
                    }
                    
                    // Storage breakdown
                    storageBreakdown
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                // Bottom stats
                bottomStats
            }
            .padding(28)
        }
        .onAppear { viewModel.load() }
    }
    
    private var headerRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 14, weight: .bold))
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
            
            if viewModel.diskInfo != nil {
                Text("Macintosh HD")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(Color(hex: "111827"))
            }
            
            Spacer()
            
            Button(action: onLaunchSmartCare) {
                HStack(spacing: 8) {
                    Text("LAUNCH SMART CARE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "1C1C1E"))
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var storageBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STORAGE BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(Color(hex: "9CA3AF"))
            
            // Bar
            if viewModel.diskInfo != nil {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "3B82F6"))
                            .frame(width: max(4, geo.size.width * 0.55))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "F472B6"))
                            .frame(width: max(4, geo.size.width * 0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "EF4444"))
                            .frame(width: max(4, geo.size.width * 0.08))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "E5E7EB"))
                            .frame(width: max(4, geo.size.width * 0.22))
                    }
                    .frame(height: 8)
                }
                .frame(width: 220, height: 8)
            }
            
            // Category list
            VStack(spacing: 10) {
                storageRow(icon: "doc", iconColor: Color(hex: "3B82F6"), label: "Media & Files", value: "342 GB")
                storageRow(icon: "app", iconColor: Color(hex: "F472B6"), label: "Applications", value: "85 GB")
                storageRow(icon: "trash", iconColor: Color(hex: "EF4444"), label: "System Junk", value: "12.4 GB")
                storageRow(icon: "externaldrive", iconColor: Color(hex: "9CA3AF"), label: "Free Space", value: "145.6 GB")
            }
        }
        .frame(width: 240)
    }
    
    private func storageRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(Color(hex: "9CA3AF"))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color(hex: "111827"))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "D1D5DB"))
        }
    }
    
    private var bottomStats: some View {
        HStack(spacing: 14) {
            if let cpu = viewModel.cpuInfo {
                StatCard(
                    icon: "cpu",
                    iconColor: Color(hex: "3B82F6"),
                    label: "Processor",
                    value: "\(Int(cpu.usagePercentage))%",
                    subValue: "\(cpu.coreCount)-CORE M2 PRO"
                )
            }
            
            if let mem = viewModel.memoryInfo {
                StatCard(
                    icon: "memorychip",
                    iconColor: Color(hex: "A855F7"),
                    label: "Memory",
                    value: ByteFormatter.string(from: Int64(mem.used)),
                    subValue: "\(Int(mem.usedPercentage * 100))% HIGH UTILIZATION"
                )
            }
            
            if let disk = viewModel.diskInfo {
                StatCard(
                    icon: "externaldrive",
                    iconColor: Color(hex: "EF4444"),
                    label: "Disk Usage",
                    value: "\(Int(disk.usedPercentage * 100))%",
                    subValue: "\(ByteFormatter.string(from: disk.used)) / \(ByteFormatter.string(from: disk.total))"
                )
            }
        }
    }
    
    private func donutSegments(disk: SystemInfo.DiskInfo) -> [DonutSegment] {
        [
            DonutSegment(color: Color(hex: "3B82F6"), percentage: 0.55, label: "Media"),
            DonutSegment(color: Color(hex: "F472B6"), percentage: 0.15, label: "Apps"),
            DonutSegment(color: Color(hex: "EF4444"), percentage: 0.08, label: "Junk"),
        ]
    }
}
