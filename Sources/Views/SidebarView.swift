import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case smartCare = "Smart Care"
    case systemJunk = "System Junk"
    case uninstaller = "Uninstaller"
    case preferences = "Preferences"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .smartCare: return "sparkles"
        case .systemJunk: return "trash"
        case .uninstaller: return "app.badge.checkmark"
        case .preferences: return "gearshape"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .overview: return Color(hex: "3B82F6")
        case .smartCare: return Color(hex: "A855F7")
        case .systemJunk: return Color(hex: "EF4444")
        case .uninstaller: return Color(hex: "F97316")
        case .preferences: return Color(hex: "6B7280")
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "3B82F6"))
                        .frame(width: 34, height: 34)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("PureClean")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "111827"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            // Nav items
            VStack(spacing: 4) {
                ForEach(SidebarItem.allCases.prefix(4)) { item in
                    SidebarRow(
                        item: item,
                        isSelected: selection == item
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selection = item
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            Divider()
                .background(Color.black.opacity(0.06))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            SidebarRow(
                item: .preferences,
                isSelected: selection == .preferences
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    selection = .preferences
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(width: 210)
        .background(Color(hex: "E8E8EA"))
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.accentColor)
                    .frame(width: 4, height: isSelected ? 24 : 0)
                
                // Icon background
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? item.accentColor.opacity(0.12) : Color.clear)
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? item.accentColor : Color(hex: "9CA3AF"))
                }
                .frame(width: 34, height: 34)
                
                Text(item.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "111827") : Color(hex: "6B7280"))
                
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.black.opacity(0.04) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
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
