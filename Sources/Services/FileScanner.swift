import Foundation

enum FileScanner {
    
    // MARK: - System Junk Scan
    static func scanSystemJunk() async -> [JunkFile] {
        var results: [JunkFile] = []
        
        let cachePaths = [
            PathConstants.caches,
            PathConstants.applicationSupport,
            PathConstants.tmp
        ]
        
        for path in cachePaths {
            results += await scanDirectory(path, type: .cache, maxDepth: 3)
        }
        
        // Logs
        results += await scanDirectory(PathConstants.logs, type: .log, maxDepth: 2)
        
        // Downloads - broken/very old files
        results += await scanBrokenDownloads(in: PathConstants.downloads)
        
        // Trash
        results += await scanDirectory(PathConstants.trash, type: .trash, maxDepth: 1)
        
        return results.sorted { $0.size > $1.size }
    }
    
    private static func scanDirectory(_ url: URL, type: JunkFile.JunkType, maxDepth: Int) async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        let allURLs = enumerator.allObjects as! [URL]
        
        for fileURL in allURLs {
            let depth = fileURL.pathComponents.count - url.pathComponents.count
            guard depth <= maxDepth else {
                continue
            }
            
            do {
                let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let isDir = attrs.isDirectory ?? false
                let size = Int64(attrs.fileSize ?? 0)
                
                if !isDir, size > 0 {
                    files.append(JunkFile(url: fileURL, size: size, type: type))
                }
                
                if files.count >= 5000 { break }
            } catch {
                continue
            }
        }
        
        return files
    }
    
    private static func scanBrokenDownloads(in url: URL) async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        for fileURL in contents {
            let name = fileURL.lastPathComponent.lowercased()
            if name.hasSuffix(".crdownload") || name.hasSuffix(".part") || name.hasSuffix(".download") {
                do {
                    let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let size = Int64(attrs.fileSize ?? 0)
                    if size > 0 {
                        files.append(JunkFile(url: fileURL, size: size, type: .download))
                    }
                } catch { }
            }
        }
        
        return files
    }
    
    // MARK: - App Scan
    static func scanApplications() async -> [AppBundle] {
        var apps: [AppBundle] = []
        let paths = [PathConstants.applications, PathConstants.userApplications]
        
        for baseURL in paths {
            guard let contents = try? FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { continue }
            
            for url in contents where url.pathExtension == "app" {
                if let app = await parseAppBundle(url) {
                    apps.append(app)
                }
            }
        }
        
        return apps.sorted { $0.totalSize > $1.totalSize }
    }
    
    private static func parseAppBundle(_ url: URL) async -> AppBundle? {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        
        var size: Int64 = 0
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            let allURLs = enumerator.allObjects as! [URL]
            for fileURL in allURLs {
                if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                    size += Int64(attrs.fileSize ?? 0)
                }
            }
        }
        
        var bundleID: String?
        var version: String?
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        if let plist = try? PropertyListSerialization.propertyList(from: Data(contentsOf: infoPlist), format: nil) as? [String: Any] {
            bundleID = plist["CFBundleIdentifier"] as? String
            version = plist["CFBundleShortVersionString"] as? String
        }
        
        // Find leftovers in ~/Library
        var leftovers: [AppBundle.LeftoverFile] = []
        if let bid = bundleID {
            leftovers += await findLeftovers(bundleID: bid)
        }
        
        return AppBundle(
            name: name,
            bundleURL: url,
            bundleIdentifier: bundleID,
            version: version,
            size: size,
            lastUsed: nil,
            leftovers: leftovers
        )
    }
    
    private static func findLeftovers(bundleID: String) async -> [AppBundle.LeftoverFile] {
        var leftovers: [AppBundle.LeftoverFile] = []
        let fm = FileManager.default
        let paths = [
            PathConstants.caches,
            PathConstants.applicationSupport,
            PathConstants.home.appendingPathComponent("Library/Preferences"),
            PathConstants.home.appendingPathComponent("Library/Containers")
        ]
        
        for base in paths {
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else { continue }
            for url in contents {
                let itemName = url.lastPathComponent
                if itemName.contains(bundleID) || itemName.contains(bundleID.split(separator: ".").last ?? "") {
                    var size: Int64 = 0
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                            let allURLs = enumerator.allObjects as! [URL]
                            for fileURL in allURLs {
                                if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                                    size += Int64(attrs.fileSize ?? 0)
                                }
                            }
                        }
                    } else {
                        size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                    }
                    leftovers.append(AppBundle.LeftoverFile(url: url, size: size))
                }
            }
        }
        
        return leftovers
    }
    
    // MARK: - Large Files
    static func scanLargeFiles(minSize: Int64 = 100 * 1024 * 1024, maxAgeDays: Int = 365) async -> [LargeFile] {
        var results: [LargeFile] = []
        let fm = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-Double(maxAgeDays) * 24 * 60 * 60)
        
        let searchPaths = [PathConstants.home, PathConstants.downloads]
        
        for base in searchPaths {
            guard let enumerator = fm.enumerator(at: base, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            
            let allURLs = enumerator.allObjects as! [URL]
            
            for url in allURLs {
                do {
                    let attrs = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                    guard !(attrs.isDirectory ?? false) else { continue }
                    
                    let size = Int64(attrs.fileSize ?? 0)
                    let modDate = attrs.contentModificationDate ?? Date.distantPast
                    
                    if size >= minSize || modDate < cutoffDate {
                        results.append(LargeFile(url: url, size: size, modificationDate: modDate))
                    }
                    
                    if results.count >= 2000 { break }
                } catch { continue }
            }
        }
        
        return results.sorted { $0.size > $1.size }
    }
    
    // MARK: - Space Lens
    static func buildDiskTree(for url: URL, maxDepth: Int = 3) async -> DiskItem? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        
        let item = await buildDiskItem(url: url, currentDepth: 0, maxDepth: maxDepth)
        return item
    }
    
    private static func buildDiskItem(url: URL, currentDepth: Int, maxDepth: Int) async -> DiskItem {
        let fm = FileManager.default
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return DiskItem(url: url, name: name, size: 0, isDirectory: false, children: nil)
        }
        
        if !isDir.boolValue {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return DiskItem(url: url, name: name, size: size, isDirectory: false, children: nil)
        }
        
        var totalSize: Int64 = 0
        var children: [DiskItem] = []
        
        if currentDepth < maxDepth {
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: .skipsHiddenFiles) {
                for childURL in contents.prefix(100) {
                    let child = await buildDiskItem(url: childURL, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                    totalSize += child.size
                    children.append(child)
                }
            }
        } else {
            // At max depth, just calculate total size without building children
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                let allURLs = enumerator.allObjects as! [URL]
                for fileURL in allURLs {
                    totalSize += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                }
            }
        }
        
        children.sort { $0.size > $1.size }
        return DiskItem(url: url, name: name, size: totalSize, isDirectory: true, children: children.isEmpty ? nil : children)
    }
    
    // MARK: - Duplicates
    static func findDuplicates(in url: URL, minSize: Int64 = 1024 * 1024) async -> [DuplicateGroup] {
        let fm = FileManager.default
        var sizeMap: [Int64: [URL]] = [:]
        
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        let allURLs = enumerator.allObjects as! [URL]
        
        for fileURL in allURLs {
            do {
                let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                guard !(attrs.isDirectory ?? false) else { continue }
                let size = Int64(attrs.fileSize ?? 0)
                guard size >= minSize else { continue }
                sizeMap[size, default: []].append(fileURL)
            } catch { continue }
        }
        
        var groups: [DuplicateGroup] = []
        for (size, urls) in sizeMap where urls.count > 1 {
            var hashMap: [String: [URL]] = [:]
            for fileURL in urls {
                if let hash = try? await FileHash.quickHash(for: fileURL) {
                    hashMap[hash, default: []].append(fileURL)
                }
            }
            
            for (hash, matchingURLs) in hashMap where matchingURLs.count > 1 {
                let files = matchingURLs.map { DuplicateGroup.DuplicateFile(url: $0, size: size) }
                groups.append(DuplicateGroup(hash: hash, files: files, totalSize: size * Int64(files.count)))
            }
        }
        
        return groups.sorted { $0.wastedSpace > $1.wastedSpace }
    }
    
    // MARK: - Privacy
    static func scanPrivacyTraces() async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let fm = FileManager.default
        
        // Safari history
        if fm.fileExists(atPath: PathConstants.safariHistory.path) {
            let size = (try? PathConstants.safariHistory.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            items.append(PrivacyItem(name: "Safari History", url: PathConstants.safariHistory, type: .browserHistory, size: size))
        }
        
        // Chrome history
        if let chrome = PathConstants.chromeHistory, fm.fileExists(atPath: chrome.path) {
            let size = (try? chrome.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            items.append(PrivacyItem(name: "Chrome History", url: chrome, type: .browserHistory, size: size))
        }
        
        // Recent items
        let recentDirs = [
            PathConstants.home.appendingPathComponent("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments.sfl2"),
            PathConstants.home.appendingPathComponent("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.RecentDocuments.sfl2")
        ]
        for dir in recentDirs {
            if fm.fileExists(atPath: dir.path) {
                let size = (try? dir.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                items.append(PrivacyItem(name: "Recent Documents", url: dir, type: .recentItems, size: size))
            }
        }
        
        return items
    }
    
    // MARK: - Malware Heuristics
    static func scanMalware() async -> [MalwareThreat] {
        var threats: [MalwareThreat] = []
        let fm = FileManager.default
        
        // Suspicious launch agents
        if let contents = try? fm.contentsOfDirectory(at: PathConstants.launchAgents, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "plist" {
                let name = url.deletingPathExtension().lastPathComponent
                if name.lowercased().contains("miner") || name.lowercased().contains("coin") {
                    threats.append(MalwareThreat(
                        name: "Suspicious Launch Agent: \(name)",
                        path: url.path,
                        type: .suspiciousLaunchAgent,
                        severity: .high
                    ))
                }
            }
        }
        
        // Check for quarantined files
        let quarantineDir = PathConstants.home.appendingPathComponent("Library/Quarantine")
        if fm.fileExists(atPath: quarantineDir.path) {
            if let contents = try? fm.contentsOfDirectory(at: quarantineDir, includingPropertiesForKeys: nil) {
                for url in contents {
                    threats.append(MalwareThreat(
                        name: "Quarantined: \(url.lastPathComponent)",
                        path: url.path,
                        type: .quarantinedFile,
                        severity: .medium
                    ))
                }
            }
        }
        
        // Check Downloads for suspicious executables
        if let contents = try? fm.contentsOfDirectory(at: PathConstants.downloads, includingPropertiesForKeys: nil) {
            for url in contents {
                let name = url.lastPathComponent.lowercased()
                if name.hasSuffix(".dmg") || name.hasSuffix(".pkg") || name.hasSuffix(".app.zip") {
                    // In a real app, we'd verify code signatures here
                    // For demo purposes, we skip unsigned DMGs to avoid false positives
                }
            }
        }
        
        return threats
    }
}
