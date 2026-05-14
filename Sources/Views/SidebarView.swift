import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case auto = "Auto Clean"
    case junkCleaner = "Junk Cleaner"
    case appUninstaller = "Uninstaller"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .auto: return "cpu"
        case .junkCleaner: return "trash.circle.fill"
        case .appUninstaller: return "xmark.app.fill"
        }
    }
    
    var accent: Color {
        switch self {
        case .auto: return .cyan
        case .junkCleaner: return .green
        case .appUninstaller: return .blue
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    
    var body: some View {
        VStack(spacing: 8) {
            // Logo area
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("CleanMac")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 12)
            
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(item: item, isSelected: selection == item) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                }
            }
            
            Spacer()
            
            // Status footer
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("System Ready")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .padding(.vertical, 8)
        .frame(width: 180)
        .background(
            ZStack {
                Color.black.opacity(0.3)
                VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                    .opacity(0.5)
            }
        )
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? item.accent : .white.opacity(0.6))
                
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(item.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: item.accent.opacity(0.6), radius: 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? item.accent.opacity(0.3) : Color.clear, lineWidth: 1)
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
