import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .auto
    
    var body: some View {
        ZStack {
            // Soft dark background
            Color.black.opacity(0.92)
            
            // Subtle ambient gradient
            RadialGradient(
                colors: [
                    Color(hex: "1a2e1a").opacity(0.4),
                    Color(hex: "0d1a0d").opacity(0.2),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 100,
                endRadius: 800
            )
            
            // Main content
            HStack(spacing: 0) {
                SidebarView(selection: $selectedItem)
                    .frame(width: 180)
                    .background(
                        Color.black.opacity(0.3)
                            .overlay(
                                VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                                    .opacity(0.3)
                            )
                    )
                
                Divider()
                    .background(Color.white.opacity(0.05))
                
                ZStack {
                    switch selectedItem {
                    case .auto:
                        AutoModeView()
                    case .junkCleaner:
                        JunkCleanerView()
                    case .appUninstaller:
                        AppUninstallerView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
