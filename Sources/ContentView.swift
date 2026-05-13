import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem = .smartCare
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-bleed gradient background
                LinearGradient(
                    gradient: selection.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    SidebarView(selection: $selection)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    detailView(for: selection)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
    
    @ViewBuilder
    func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .smartCare:
            SmartCareView()
        case .cleanup:
            CleanupLandingView()
        case .protection:
            ProtectionLandingView()
        case .performance:
            PerformanceLandingView()
        case .applications:
            ApplicationsLandingView()
        case .myClutter:
            MyClutterLandingView()
        case .spaceLens:
            SpaceLensView()
        case .assistant:
            AssistantView()
        }
    }
}
