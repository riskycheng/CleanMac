import Foundation

// MARK: - Multi-Factor Junk Scoring

extension FileScanner {
    
    struct JunkScore {
        let file: JunkFile
        let ageScore: Double
        let sizeScore: Double
        let categoryScore: Double
        let orphanScore: Double
        
        var total: Double {
            ageScore * sizeScore * categoryScore * orphanScore
        }
    }
    
    // MARK: - Weights
    
    static func ageWeight(days: Double) -> Double {
        switch days {
        case ..<7:     return 0.1
        case 7..<30:   return 0.3
        case 30..<90:  return 0.6
        case 90..<180: return 0.8
        default:       return 1.0
        }
    }
    
    static func sizeWeight(bytes: Int64) -> Double {
        let mb = Double(bytes) / 1_048_576
        switch mb {
        case ..<1:       return 0.1
        case 1..<10:     return 0.3
        case 10..<100:   return 0.6
        case 100..<500:  return 0.8
        default:         return 1.0
        }
    }
    
    static func categoryWeight(_ category: JunkCategory) -> Double {
        switch category {
        case .tempFiles, .brokenDownloads, .trash:            return 1.0
        case .logs, .systemLogs, .userLogs, .orphanedSupport: return 0.9
        case .caches, .systemCaches, .browserCache,
             .xcodeJunk, .developerCache:                     return 0.8
        }
    }
    
    // MARK: - Orphan Detection
    
    static func orphanWeight(path: URL, installedBundleIDs: Set<String>) -> Double {
        let name = path.lastPathComponent.lowercased()
        for bundleID in installedBundleIDs {
            if name.contains(bundleID.lowercased()) { return 0.0 }
            let last = bundleID.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
            if !last.isEmpty, name.contains(last) { return 0.0 }
        }
        return 1.0
    }
    
    // MARK: - Smart Scan (concurrent, scored)
    
    static func smartScanJunk() async -> [JunkFile] {
        let installedBundleIDs = await LaunchServicesHelper.installedBundleIDsAsync()
        let locations = allSmartScanLocations()
        
        return await withTaskGroup(of: [JunkFile].self) { group in
            for (url, category, maxDepth) in locations {
                group.addTask {
                    await smartScanDirectory(url, category: category, maxDepth: maxDepth, installedBundleIDs: installedBundleIDs)
                }
            }
            
            // Special scans
            group.addTask { await scanBrokenDownloadsSmart(in: PathConstants.downloads) }
            group.addTask { await scanOrphanedSupportSmart(installedBundleIDs: installedBundleIDs) }
            
            var allFiles: [JunkFile] = []
            for await files in group {
                allFiles.append(contentsOf: files)
            }
            return allFiles.sorted { $0.size > $1.size }
        }
    }
    
    // MARK: - Scan Locations
    
    private static func allSmartScanLocations() -> [(URL, JunkCategory, Int)] {
        let fm = FileManager.default
        var locations: [(URL, JunkCategory, Int)] = []
        let home = PathConstants.home
        
        locations.append((home.appendingPathComponent("Library/Caches"), .caches, 3))
        
        let sysCaches = [
            home.appendingPathComponent("Library/Caches/com.apple"),
            home.appendingPathComponent("Library/Caches/com.apple.Safari"),
            home.appendingPathComponent("Library/Caches/com.apple.finder"),
            home.appendingPathComponent("Library/Caches/com.apple.dock"),
        ].filter { fm.fileExists(atPath: $0.path) }
        sysCaches.forEach { locations.append(($0, .systemCaches, 2)) }
        
        locations.append((home.appendingPathComponent("Library/Logs"), .logs, 3))
        
        let sysLogs = [
            URL(fileURLWithPath: "/var/log"),
            URL(fileURLWithPath: "/private/var/log"),
            home.appendingPathComponent("Library/Logs/DiagnosticReports"),
        ].filter { fm.fileExists(atPath: $0.path) }
        sysLogs.forEach { locations.append(($0, .systemLogs, 2)) }
        
        locations.append((PathConstants.tmp, .tempFiles, 2))
        ["/tmp", "/var/tmp", "/private/var/tmp"].forEach {
            let u = URL(fileURLWithPath: $0)
            if fm.fileExists(atPath: u.path) { locations.append((u, .tempFiles, 2)) }
        }
        
        let containers = home.appendingPathComponent("Library/Containers")
        if fm.fileExists(atPath: containers.path) { locations.append((containers, .tempFiles, 2)) }
        
        locations.append((PathConstants.trash, .trash, 2))
        
        let browserPaths = [
            home.appendingPathComponent("Library/Caches/com.apple.Safari"),
            home.appendingPathComponent("Library/Caches/com.apple.WebKit.PluginProcess"),
            home.appendingPathComponent("Library/WebKit/com.apple.Safari"),
            home.appendingPathComponent("Library/Caches/Google/Chrome"),
            home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"),
            home.appendingPathComponent("Library/Caches/Microsoft Edge"),
        ].filter { fm.fileExists(atPath: $0.path) }
        browserPaths.forEach { locations.append(($0, .browserCache, 2)) }
        
        if let ffProfiles = try? fm.contentsOfDirectory(
            at: home.appendingPathComponent("Library/Caches/Firefox/Profiles"),
            includingPropertiesForKeys: nil
        ) {
            ffProfiles.forEach { locations.append(($0, .browserCache, 2)) }
        }
        
        let xcodePaths = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/Xcode/watchOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/CoreSimulator"),
        ].filter { fm.fileExists(atPath: $0.path) }
        xcodePaths.forEach { locations.append(($0, .xcodeJunk, 1)) }
        
        let devPaths = [
            home.appendingPathComponent(".npm/_cacache"),
            home.appendingPathComponent(".yarn/cache"),
            home.appendingPathComponent("Library/Caches/pip"),
            home.appendingPathComponent("Library/Caches/composer"),
            home.appendingPathComponent("Library/Caches/CocoaPods"),
            home.appendingPathComponent("Library/Caches/org.swift.swiftpm"),
            home.appendingPathComponent(".gradle/caches"),
            home.appendingPathComponent(".docker"),
        ].filter { fm.fileExists(atPath: $0.path) }
        devPaths.forEach { locations.append(($0, .developerCache, 2)) }
        
        return locations
    }
    
    // MARK: - Smart Directory Scanning
    
    private static func smartScanDirectory(_ url: URL, category: JunkCategory, maxDepth: Int, installedBundleIDs: Set<String>) async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        let allURLs = enumerator.allObjects as! [URL]
        
        for fileURL in allURLs {
            let depth = fileURL.pathComponents.count - url.pathComponents.count
            guard depth <= maxDepth else { continue }
            
            do {
                let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
                let isDir = attrs.isDirectory ?? false
                let size = Int64(attrs.fileSize ?? 0)
                
                if !isDir, size > 0 {
                    let modDate = attrs.contentModificationDate ?? Date.distantPast
                    let days = Date().timeIntervalSince(modDate) / 86400.0
                    
                    let score = ageWeight(days: days)
                        * sizeWeight(bytes: size)
                        * categoryWeight(category)
                        * orphanWeight(path: fileURL, installedBundleIDs: installedBundleIDs)
                    
                    let file = JunkFile(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        url: fileURL,
                        size: size,
                        category: category,
                        isSelected: score > 0.3
                    )
                    files.append(file)
                }
                if files.count >= 5000 { break }
            } catch {
                continue
            }
        }
        
        return files
    }
    
    // MARK: - Smart Broken Downloads
    
    private static func scanBrokenDownloadsSmart(in url: URL) async -> [JunkFile] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        var files: [JunkFile] = []
        for fileURL in contents {
            let name = fileURL.lastPathComponent.lowercased()
            let brokenExts = [".crdownload", ".part", ".download", ".partial"]
            if brokenExts.contains(where: { name.hasSuffix($0) }) {
                guard let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                      let size = attrs.fileSize, size > 0 else { continue }
                files.append(JunkFile(
                    name: fileURL.lastPathComponent,
                    path: fileURL.path,
                    url: fileURL,
                    size: Int64(size),
                    category: .brokenDownloads,
                    isSelected: true
                ))
            }
        }
        return files
    }
    
    // MARK: - Smart Orphaned Support
    
    private static func scanOrphanedSupportSmart(installedBundleIDs: Set<String>) async -> [JunkFile] {
        let fm = FileManager.default
        let home = PathConstants.home
        var files: [JunkFile] = []
        
        let searchPaths = [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/Application Scripts"),
        ]
        
        for base in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for url in contents {
                let name = url.lastPathComponent.lowercased()
                
                // Skip generic/system folders
                let genericNames = ["apple", "microsoft", "google", "mozilla", "adobe", "unity", "unreal", "blender"]
                if genericNames.contains(where: { name.contains($0) }) { continue }
                
                // Check if orphaned
                guard orphanWeight(path: url, installedBundleIDs: installedBundleIDs) == 1.0 else { continue }
                
                // Calculate recursive size
                var size: Int64 = 0
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                    let allURLs = enumerator.allObjects as! [URL]
                    for fileURL in allURLs {
                        size += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                    }
                }
                
                if size > 102_400 { // Only flag if > 100KB
                    files.append(JunkFile(
                        name: url.lastPathComponent,
                        path: url.path,
                        url: url,
                        size: size,
                        category: .orphanedSupport,
                        isSelected: true
                    ))
                }
            }
        }
        
        return files
    }
}
