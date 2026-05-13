import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem = .smartCare
    @State private var completedModules: Set<ScanModuleType> = []
    @State private var currentScanModule: ScanModuleType? = nil
    
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
                    SidebarView(
                        selection: $selection,
                        completedModules: completedModules
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    detailView(for: selection)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: selection) { _, _ in
                            // Reset completed modules when leaving Smart Care
                            if selection != .smartCare {
                                completedModules = []
                            }
                        }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .environment(\.completedModules, $completedModules)
    }
    
    @ViewBuilder
    func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .smartCare:
            SmartCareView(completedModules: $completedModules)
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

private struct CompletedModulesKey: EnvironmentKey {
    static let defaultValue: Binding<Set<ScanModuleType>> = .constant([])
}

extension EnvironmentValues {
    var completedModules: Binding<Set<ScanModuleType>> {
        get { self[CompletedModulesKey.self] }
        set { self[CompletedModulesKey.self] = newValue }
    }
}
