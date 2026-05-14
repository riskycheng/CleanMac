import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case auto = "Auto Clean"
    case junkCleaner = "Junk Cleaner"
    case appUninstaller = "Uninstaller"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .junkCleaner: return "trash"
        case .appUninstaller: return "xmark.app"
        }
    }
    
    var accent: Color {
        switch self {
        case .auto: return .green
        case .junkCleaner: return .green
        case .appUninstaller: return .green
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    
    var body: some View {
        VStack(spacing: 6) {
            // Logo area
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green.opacity(0.8))
                Text("CleanMac")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            
            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 12)
            
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(item: item, isSelected: selection == item) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = item
                    }
                }
            }
            
            Spacer()
            
            // Status footer
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green.opacity(0.7))
                    .frame(width: 5, height: 5)
                Text("Ready")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.vertical, 8)
        .frame(width: 180)
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    @State private var hover: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
