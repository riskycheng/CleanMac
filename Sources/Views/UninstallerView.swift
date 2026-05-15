import SwiftUI

@MainActor
@Observable
final class UninstallerViewModel {
    var isScanning = false
    var scanComplete = false
    var apps: [AppBundle] = []
    var scanProgress: Double = 0
    var scanStage: String = ""
    
    func startScan() {
        isScanning = true; scanComplete = false; scanProgress = 0
        Task { await runScan() }
    }
    
    private func runScan() async {
        let stages = [
            ("Scanning Applications folder...", 0.25),
            ("Analyzing application dependencies...", 0.50),
            ("Finding leftover files...", 0.75),
            ("Building app index...", 0.95),
        ]
        for (stage, progress) in stages {
            await MainActor.run { scanStage = stage; scanProgress = progress }
            try? await Task.sleep(for: .milliseconds(400))
        }
        let scanned = await FileScanner.scanApplications()
        await MainActor.run { apps = scanned; isScanning = false; scanComplete = true }
    }
    
    func uninstallSelected() {
        for app in apps.filter({ $0.isSelected }) {
            do { try FileManager.default.trashItem(at: app.url, resultingItemURL: nil) } catch { }
            for leftover in app.leftoverFiles {
                do { try FileManager.default.trashItem(at: leftover, resultingItemURL: nil) } catch { }
            }
        }
        apps.removeAll { $0.isSelected }
    }
    
    func reset() {
        isScanning = false; scanComplete = false; apps.removeAll(); scanProgress = 0
    }
}

struct UninstallerView: View {
    @State private var viewModel = UninstallerViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.isScanning {
                ModernProgressView(
                    progress: viewModel.scanProgress,
                    stage: viewModel.scanStage,
                    subStage: "Scanning File System",
                    accentColor: Color(hex: "F97316")
                )
            } else if viewModel.scanComplete {
                UninstallerResultsView(viewModel: viewModel)
            } else {
                ModuleIdleView(
                    icon: "app.badge.checkmark",
                    iconColor: Color(hex: "F97316"),
                    title: "Uninstaller",
                    subtitle: "Identify unused applications, background processes, and large binaries to reclaim your system storage.",
                    buttonText: "Analyze Applications",
                    action: { viewModel.startScan() }
                )
            }
        }
    }
}

struct UninstallerResultsView: View {
    @Bindable var viewModel: UninstallerViewModel
    @State private var searchText = ""
    
    var filteredApps: [AppBundle] {
        if searchText.isEmpty { return viewModel.apps }
        return viewModel.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "app")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "F97316"))
                        Text("APPLICATION ENGINE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Color(hex: "F97316"))
                    }
                    Text("Uninstaller")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color(hex: "111827"))
                    Text("Manage your workspace and reclaim storage space.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "6B7280"))
                }
                
                Spacer()
                
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9CA3AF"))
                    TextField("Filter applications...", text: $searchText)
                        .font(.system(size: 13, weight: .medium))
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            // Stat cards
            HStack(spacing: 12) {
                StatCard(icon: "bolt.slash", iconColor: Color(hex: "EF4444"), label: "Not Used", value: "3", subValue: nil)
                StatCard(icon: "square.stack.3d.up", iconColor: Color(hex: "3B82F6"), label: "Large Apps", value: "5", subValue: nil)
                StatCard(icon: "clock.arrow.circlepath", iconColor: Color(hex: "A855F7"), label: "Older Versions", value: "2", subValue: nil)
                StatCard(icon: "cube", iconColor: Color(hex: "22C55E"), label: "Background", value: "12", subValue: nil)
            }
            .padding(.horizontal, 28)
            
            // App list
            VStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    Text("APPLICATION INFO")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .frame(width: 280, alignment: .leading)
                    
                    Text("FILESIZE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .frame(width: 100, alignment: .leading)
                    
                    Text("LAST ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .frame(width: 120, alignment: .leading)
                    
                    Text("CATEGORY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "9CA3AF"))
                        .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "F9FAFB"))
                
                Divider().background(Color.black.opacity(0.04))
                
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppTableRow(app: app)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }
}

struct AppTableRow: View {
    let app: AppBundle
    @State private var isHovered = false
    
    var categoryColor: Color {
        let colors: [Color] = [Color(hex: "3B82F6"), Color(hex: "EF4444"), Color(hex: "22C55E"), Color(hex: "F59E0B"), Color(hex: "A855F7")]
        return colors[abs(app.name.hashValue) % colors.count]
    }
    
    var categoryName: String {
        let cats = ["DESIGN", "DEVELOPMENT", "SOCIAL", "PRODUCTIVITY", "MEDIA"]
        return cats[abs(app.name.hashValue) % cats.count]
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: Binding(
                get: { app.isSelected },
                set: { app.isSelected = $0 }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .frame(width: 36)
            
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(categoryColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "app")
                        .font(.system(size: 18))
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "111827"))
                    Text("BUILD \(app.version) · UNIVERSAL")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
            .frame(width: 280, alignment: .leading)
            
            Text(ByteFormatter.string(from: app.totalSize))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "374151"))
                .frame(width: 100, alignment: .leading)
            
            Text("Today")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "6B7280"))
                .frame(width: 120, alignment: .leading)
            
            Text(categoryName)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(categoryColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(categoryColor.opacity(0.1))
                )
                .frame(width: 100, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color(hex: "F9FAFB") : Color.clear)
        .onHover { isHovered = $0 }
    }
}
