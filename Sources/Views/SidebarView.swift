import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case junkCleaner = "Junk"
    case appUninstaller = "Apps"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .junkCleaner: return "trash"
        case .appUninstaller: return "xmark.app"
        }
    }
    
    var fullTitle: String {
        switch self {
        case .auto: return "Auto Clean"
        case .junkCleaner: return "Junk Cleaner"
        case .appUninstaller: return "Uninstaller"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.9), .mint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            VStack(spacing: 8) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarIconCell(
                        item: item,
                        isSelected: selection == item
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selection = item
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: 5, height: 5)
                Text("Ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.bottom, 16)
        }
        .frame(width: 90)
        .background(
            Color.black.opacity(0.25)
                .overlay(
                    VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                        .opacity(0.3)
                )
        )
    }
}

struct SidebarIconCell: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var titleVisible = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Selection glow background
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? Color.green.opacity(0.08)
                          : (isHovered ? Color.white.opacity(0.04) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
                
                VStack(spacing: 4) {
                    // Icon
                    ZStack {
                        // Glow behind selected icon
                        if isSelected {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 46, height: 46)
                                .blur(radius: 8)
                        }
                        
                        Image(systemName: item.icon)
                            .font(.system(size: isSelected ? 26 : 24, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(
                                isSelected
                                ? Color.white
                                : Color.white.opacity(0.35)
                            )
                            .frame(width: 30, height: 30)
                            .scaleEffect(isHovered && !isSelected ? 1.1 : 1.0)
                    }
                    .frame(height: 38)
                    
                    // Title - appears on hover/selection
                    Text(item.fullTitle)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.5))
                        .lineLimit(1)
                        .opacity(titleVisible ? 1 : 0)
                        .offset(y: titleVisible ? 0 : 4)
                }
                .padding(.vertical, 10)
                
                // Active indicator - left bar
                HStack {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.green)
                        .frame(width: 3, height: isSelected ? 28 : 0)
                        .padding(.leading, -32)
                    Spacer()
                }
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                titleVisible = hover || isSelected
            }
        }
        .onAppear {
            titleVisible = isSelected
        }
        .onChange(of: isSelected) { _, new in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                titleVisible = new || isHovered
            }
        }
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
