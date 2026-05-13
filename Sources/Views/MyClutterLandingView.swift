import SwiftUI

struct MyClutterLandingView: View {
    @State private var viewModel = LargeFilesViewModel()
    @State private var hasScanned = false
    
    var body: some View {
        ZStack {
            if !hasScanned {
                ModuleHero(
                    icon: "folder.fill",
                    title: "My Clutter",
                    subtitle: "Find large and old files you may have forgotten about.",
                    accent: Color(hex: "18FFFF"),
                    isScanning: viewModel.isScanning,
                    scanAction: {
                        viewModel.startScan()
                        hasScanned = true
                    }
                )
            } else {
                LargeFilesViewDark(viewModel: viewModel)
            }
        }
    }
}

struct LargeFilesViewDark: View {
    @Bindable var viewModel: LargeFilesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large & Old Files")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select files to move to trash")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                
                Picker("Sort by", selection: $viewModel.sortBy) {
                    ForEach(LargeFilesViewModel.SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                if viewModel.scanComplete && !viewModel.files.isEmpty {
                    Text("Selected: \(ByteFormatter.string(from: viewModel.selectedSize))")
                        .font(.callout.weight(.medium))
                        .foregroundColor(Color(hex: "18FFFF"))
                }
            }
            .padding()
            
            if viewModel.files.isEmpty && viewModel.scanComplete {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.folder.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Large Files Found")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            } else if !viewModel.files.isEmpty {
                List {
                    ForEach($viewModel.files) { $file in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $file.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            
                            Image(systemName: "doc")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.url.lastPathComponent)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                Text(file.url.deletingLastPathComponent().path)
                                    .lineLimit(1)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            Text(file.formattedDate)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(ByteFormatter.string(from: file.size))
                                .font(.caption.weight(.medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "18FFFF").opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
                .alternatingRowBackgrounds(.enabled)
                .scrollContentBackground(.hidden)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                HStack {
                    Button("Select All") { viewModel.toggleAll(true) }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white.opacity(0.8))
                    Button("Deselect All") { viewModel.toggleAll(false) }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Button("Move to Trash") {
                        viewModel.removeSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(viewModel.isCleaning || viewModel.files.filter(\.isSelected).isEmpty)
                }
                .padding()
            }
        }
    }
}
