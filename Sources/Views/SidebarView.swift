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
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @State private var hoveredItem: SidebarItem? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            // Logo icon
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.green.opacity(0.8))
                .frame(width: 44, height: 44)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            
            ForEach(SidebarItem.allCases) { item in
                SidebarIconButton(
                    item: item,
                    isSelected: selection == item,
                    isHovered: hoveredItem == item
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = item
                    }
                }
                .onHover { isHover in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredItem = isHover ? item : nil
                    }
                }
            }
            
            Spacer()
            
            // Status dot
            HStack {
                Circle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: 5, height: 5)
            }
            .padding(.bottom, 16)
        }
        .padding(.vertical, 8)
        .frame(width: 60)
        .background(
            Color.black.opacity(0.3)
                .overlay(
                    VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                        .opacity(0.3)
                )
        )
    }
}

struct SidebarIconButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Selection background
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                
                // Active indicator bar
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 3, height: isSelected ? 20 : 0)
                        .padding(.leading, -14)
                    Spacer()
                }
                
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                    .frame(width: 22, height: 22)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .overlay(
            // Tooltip
            Group {
                if isHovered {
                    HStack(spacing: 0) {
                        Text(item.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.85))
                                    .shadow(color: .black.opacity(0.3), radius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                        
                        // Arrow pointing left
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 5))
                            path.addLine(to: CGPoint(x: 6, y: 0))
                            path.addLine(to: CGPoint(x: 6, y: 10))
                            path.closeSubpath()
                        }
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 6, height: 10)
                    }
                    .offset(x: 72)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        )
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
