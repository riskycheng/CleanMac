import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case smartCare = "Smart Care"
    case cleanup = "Cleanup"
    case protection = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case myClutter = "My Clutter"
    case spaceLens = "Space Lens"
    case assistant = "Assistant"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .smartCare: return "sparkles.tv"
        case .cleanup: return "bubbles.and.sparkles"
        case .protection: return "hand.raised.fill"
        case .performance: return "bolt.fill"
        case .applications: return "square.grid.2x2"
        case .myClutter: return "folder.fill"
        case .spaceLens: return "circle.grid.3x3"
        case .assistant: return "bubble.left.and.bubble.right.fill"
        }
    }
    
    var gradient: Gradient {
        switch self {
        case .smartCare:
            return Gradient(colors: [Color(hex: "4A148C"), Color(hex: "1A0033")])
        case .cleanup:
            return Gradient(colors: [Color(hex: "1B5E20"), Color(hex: "0D2810")])
        case .protection:
            return Gradient(colors: [Color(hex: "880E4F"), Color(hex: "330018")])
        case .performance:
            return Gradient(colors: [Color(hex: "E65100"), Color(hex: "3E1C00")])
        case .applications:
            return Gradient(colors: [Color(hex: "0D47A1"), Color(hex: "001233")])
        case .myClutter:
            return Gradient(colors: [Color(hex: "006064"), Color(hex: "001F22")])
        case .spaceLens:
            return Gradient(colors: [Color(hex: "311B92"), Color(hex: "0D0221")])
        case .assistant:
            return Gradient(colors: [Color(hex: "4A148C"), Color(hex: "1A0033")])
        }
    }
    
    var accent: Color {
        switch self {
        case .smartCare: return Color(hex: "E040FB")
        case .cleanup: return Color(hex: "69F0AE")
        case .protection: return Color(hex: "FF4081")
        case .performance: return Color(hex: "FFAB40")
        case .applications: return Color(hex: "448AFF")
        case .myClutter: return Color(hex: "18FFFF")
        case .spaceLens: return Color(hex: "B388FF")
        case .assistant: return Color(hex: "E040FB")
        }
    }
    
    var ringColor: Color {
        switch self {
        case .smartCare: return .cyan
        case .cleanup: return .green
        case .protection: return .pink
        case .performance: return .orange
        case .applications: return .blue
        case .myClutter: return .teal
        case .spaceLens: return .purple
        case .assistant: return .cyan
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(item: item, isSelected: selection == item) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(width: 200)
        .background(
            Color.black.opacity(0.25)
                .blur(radius: 0.5)
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
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isSelected ? item.accent : .white.opacity(0.85))
                
                Text(item.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? item.accent.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
