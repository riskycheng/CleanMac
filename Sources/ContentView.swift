import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .auto
    
    var body: some View {
        ZStack {
            // Deep dark background
            Color.black.opacity(0.92)
            
            // Subtle grid pattern
            GridPattern()
                .opacity(0.03)
            
            // Matrix particles
            MatrixParticlesView()
                .opacity(0.25)
            
            // Main content
            HStack(spacing: 0) {
                SidebarView(selection: $selectedItem)
                    .frame(width: 180)
                    .background(
                        Color.black.opacity(0.4)
                            .overlay(
                                VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                                    .opacity(0.4)
                            )
                    )
                
                Divider()
                    .background(Color.white.opacity(0.06))
                
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
                .background(Color.black.opacity(0.15))
            }
        }
    }
}

struct GridPattern: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let spacing: CGFloat = 40
                for x in stride(from: 0, to: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(.white), lineWidth: 0.3)
                }
                for y in stride(from: 0, to: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.white), lineWidth: 0.3)
                }
            }
        }
    }
}
