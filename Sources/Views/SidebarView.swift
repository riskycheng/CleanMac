import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case junkCleaner = "Junk Cleaner"
    case appUninstaller = "App Uninstaller"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .junkCleaner: return "trash.circle.fill"
        case .appUninstaller: return "xmark.app.fill"
        }
    }
    
    var gradient: Gradient {
        switch self {
        case .junkCleaner:
            return Gradient(colors: [Color(hex: "1B5E20"), Color(hex: "0D2810")])
        case .appUninstaller:
            return Gradient(colors: [Color(hex: "0D47A1"), Color(hex: "001233")])
        }
    }
    
    var accent: Color {
        switch self {
        case .junkCleaner: return Color(hex: "69F0AE")
        case .appUninstaller: return Color(hex: "448AFF")
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(item: item, isSelected: selection == item) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = item
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("CleanMac")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text("v1.0.0")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.bottom, 16)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .frame(width: 200)
        .background(
            Color.black.opacity(0.25)
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
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(isSelected ? item.accent : .white.opacity(0.85))
                
                Text(item.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
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
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
