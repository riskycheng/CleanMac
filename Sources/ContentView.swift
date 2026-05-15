import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .overview
    
    var body: some View {
        ZStack {
            Color(hex: "F0F0F2")
            
            HStack(spacing: 0) {
                SidebarView(selection: $selectedItem)
                
                ZStack {
                    switch selectedItem {
                    case .overview:
                        OverviewView(onLaunchSmartCare: { selectedItem = .smartCare })
                    case .smartCare:
                        SmartCareView()
                    case .systemJunk:
                        SystemJunkView()
                    case .uninstaller:
                        UninstallerView()
                    case .preferences:
                        PreferencesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
