import SwiftUI

struct SpaceLensView: View {
    @State private var viewModel = SpaceLensViewModel()
    @State private var hasScanned = false
    
    var body: some View {
        ZStack {
            if !hasScanned {
                ModuleHero(
                    icon: "circle.grid.3x3",
                    title: "Space Lens",
                    subtitle: "Build a visual map of your disk usage and find what's taking up space.",
                    accent: Color(hex: "B388FF"),
                    isScanning: viewModel.isScanning,
                    scanAction: {
                        viewModel.startScan()
                        hasScanned = true
                    }
                )
            } else {
                SpaceLensContentDark(viewModel: viewModel)
            }
        }
    }
}

struct SpaceLensContentDark: View {
    @Bindable var viewModel: SpaceLensViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Space Lens")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Visualize your disk usage")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                if !viewModel.navigationStack.isEmpty {
                    Button(action: { viewModel.goBack() }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: { viewModel.goToRoot() }) {
                        Label("Home", systemImage: "house")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            
            if viewModel.isScanning {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Building disk map...")
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            } else if let current = viewModel.currentItem {
                ScrollView {
                    VStack(spacing: 16) {
                        Text(current.name)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        Text(current.formattedSize)
                            .font(.headline)
                            .foregroundColor(Color(hex: "B388FF"))
                        
                        if let children = current.children, !children.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                                ForEach(children) { child in
                                    SpaceLensBlockDark(item: child) {
                                        viewModel.drillInto(child)
                                    }
                                }
                            }
                            .padding()
                        } else {
                            Text("No subfolders")
                                .foregroundColor(.white.opacity(0.5))
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct SpaceLensBlockDark: View {
    let item: DiskItem
    let action: () -> Void
    
    var normalizedSize: Double {
        guard let parent = item.url.deletingLastPathComponent().path.isEmpty ? nil : try? FileManager.default.attributesOfItem(atPath: item.url.deletingLastPathComponent().path),
              let parentSize = parent[.size] as? Int64, parentSize > 0 else {
            return 1.0
        }
        return min(1.0, Double(item.size) / Double(parentSize))
    }
    
    var color: Color {
        let ratio = min(1.0, Double(item.size) / (500 * 1024 * 1024))
        return Color(
            hue: 0.75 - (ratio * 0.25),
            saturation: 0.7,
            brightness: 0.9
        )
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.5), lineWidth: 1.5)
                    )
                    .frame(height: max(60, 120 * normalizedSize))
                    .overlay(
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.title2)
                            .foregroundColor(color)
                    )
                
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }
}
