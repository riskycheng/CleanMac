import Foundation

enum FileScanner {
    
    // MARK: - Comprehensive Junk Scan
    static func scanSystemJunk() async -> [JunkFile] {
        var results: [JunkFile] = []
        let fm = FileManager.default
        let home = PathConstants.home
        
        // 1. User Caches
        results += await scanDirectory(PathConstants.caches, category: .caches, maxDepth: 3)
        
        // 2. System Caches (macOS system caches)
        let systemCaches = [
            home.appendingPathComponent("Library/Caches/com.apple"),
            home.appendingPathComponent("Library/Caches/com.apple.Safari"),
            home.appendingPathComponent("Library/Caches/com.apple.finder"),
            home.appendingPathComponent("Library/Caches/com.apple.dock"),
        ]
        for cache in systemCaches {
            if fm.fileExists(atPath: cache.path) {
                results += await scanDirectory(cache, category: .systemCaches, maxDepth: 2)
            }
        }
        
        // 3. Logs
        results += await scanDirectory(PathConstants.logs, category: .logs, maxDepth: 3)
        
        // 4. System Logs
        let systemLogPaths = [
            URL(fileURLWithPath: "/var/log"),
            URL(fileURLWithPath: "/private/var/log"),
            home.appendingPathComponent("Library/Logs/DiagnosticReports"),
        ]
        for logPath in systemLogPaths {
            if fm.fileExists(atPath: logPath.path) {
                results += await scanDirectory(logPath, category: .systemLogs, maxDepth: 2)
            }
        }
        
        // 5. Temporary files
        results += await scanDirectory(PathConstants.tmp, category: .tempFiles, maxDepth: 2)
        let tempPaths = [
            URL(fileURLWithPath: "/tmp"),
            URL(fileURLWithPath: "/var/tmp"),
            URL(fileURLWithPath: "/private/var/tmp"),
        ]
        for temp in tempPaths {
            if fm.fileExists(atPath: temp.path) {
                results += await scanDirectory(temp, category: .tempFiles, maxDepth: 2)
            }
        }
        
        // 6. var/folders (macOS temp storage)
        let varFolders = home.appendingPathComponent("Library/Containers")
        if fm.fileExists(atPath: varFolders.path) {
            results += await scanDirectory(varFolders, category: .tempFiles, maxDepth: 2)
        }
        
        // 7. Broken downloads
        results += await scanBrokenDownloads(in: PathConstants.downloads)
        
        // 8. Trash
        results += await scanDirectory(PathConstants.trash, category: .trash, maxDepth: 2)
        
        // 9. Application Support (orphaned support files)
        results += await scanOrphanedSupportFiles()
        
        // 10. Browser caches
        results += await scanBrowserCaches()
        
        // 11. Xcode junk
        results += await scanXcodeJunk()
        
        // 12. Developer tool caches
        results += await scanDeveloperCaches()
        
        return results.sorted { $0.size > $1.size }
    }
    
    private static func scanDirectory(_ url: URL, category: JunkCategory, maxDepth: Int) async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        let allURLs = enumerator.allObjects as! [URL]
        
        for fileURL in allURLs {
            let depth = fileURL.pathComponents.count - url.pathComponents.count
            guard depth <= maxDepth else { continue }
            
            do {
                let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let isDir = attrs.isDirectory ?? false
                let size = Int64(attrs.fileSize ?? 0)
                
                if !isDir, size > 0 {
                    files.append(JunkFile(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        url: fileURL,
                        size: size,
                        category: category
                    ))
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
            if name.hasSuffix(".crdownload") || name.hasSuffix(".part") || name.hasSuffix(".download") || name.hasSuffix(".partial") {
                do {
                    let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let size = Int64(attrs.fileSize ?? 0)
                    if size > 0 {
                        files.append(JunkFile(
                            name: fileURL.lastPathComponent,
                            path: fileURL.path,
                            url: fileURL,
                            size: size,
                            category: .brokenDownloads
                        ))
                    }
                } catch { }
            }
        }
        
        return files
    }
    
    private static func scanOrphanedSupportFiles() async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        let home = PathConstants.home
        
        // Saved Application State
        let savedState = home.appendingPathComponent("Library/Saved Application State")
        if let contents = try? fm.contentsOfDirectory(at: savedState, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
            for url in contents where url.pathExtension == "savedState" {
                var size: Int64 = 0
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                    let allURLs = enumerator.allObjects as! [URL]
                    for fileURL in allURLs {
                        size += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                    }
                }
                if size > 0 {
                    files.append(JunkFile(
                        name: url.lastPathComponent,
                        path: url.path,
                        url: url,
                        size: size,
                        category: .orphanedSupport
                    ))
                }
            }
        }
        
        // Application Scripts
        let appScripts = home.appendingPathComponent("Library/Application Scripts")
        if let contents = try? fm.contentsOfDirectory(at: appScripts, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
            for url in contents {
                var size: Int64 = 0
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                    let allURLs = enumerator.allObjects as! [URL]
                    for fileURL in allURLs {
                        size += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                    }
                }
                if size > 0 {
                    files.append(JunkFile(
                        name: url.lastPathComponent,
                        path: url.path,
                        url: url,
                        size: size,
                        category: .orphanedSupport
                    ))
                }
            }
        }
        
        return files
    }
    
    private static func scanBrowserCaches() async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        let home = PathConstants.home
        
        // Safari WebKit caches
        let safariPaths = [
            home.appendingPathComponent("Library/Caches/com.apple.Safari"),
            home.appendingPathComponent("Library/Caches/com.apple.WebKit.PluginProcess"),
            home.appendingPathComponent("Library/WebKit/com.apple.Safari"),
        ]
        for path in safariPaths {
            if fm.fileExists(atPath: path.path) {
                files += await scanDirectory(path, category: .browserCache, maxDepth: 2)
            }
        }
        
        // Chrome caches
        let chromePaths = [
            home.appendingPathComponent("Library/Caches/Google/Chrome"),
            home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cache"),
        ]
        for path in chromePaths {
            if fm.fileExists(atPath: path.path) {
                files += await scanDirectory(path, category: .browserCache, maxDepth: 2)
            }
        }
        
        // Firefox caches
        if let ffProfiles = try? fm.contentsOfDirectory(at: home.appendingPathComponent("Library/Caches/Firefox/Profiles"), includingPropertiesForKeys: nil) {
            for profile in ffProfiles {
                files += await scanDirectory(profile, category: .browserCache, maxDepth: 2)
            }
        }
        
        return files
    }
    
    private static func scanXcodeJunk() async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        let home = PathConstants.home
        
        let xcodePaths = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/Xcode/watchOS DeviceSupport"),
            home.appendingPathComponent("Library/Developer/CoreSimulator"),
        ]
        
        for path in xcodePaths {
            if fm.fileExists(atPath: path.path) {
                files += await scanDirectory(path, category: .xcodeJunk, maxDepth: 1)
            }
        }
        
        return files
    }
    
    private static func scanDeveloperCaches() async -> [JunkFile] {
        var files: [JunkFile] = []
        let fm = FileManager.default
        let home = PathConstants.home
        
        let paths = [
            home.appendingPathComponent(".npm/_cacache"),
            home.appendingPathComponent(".yarn/cache"),
            home.appendingPathComponent("Library/Caches/pip"),
            home.appendingPathComponent("Library/Caches/composer"),
            home.appendingPathComponent("Library/Caches/CocoaPods"),
            home.appendingPathComponent("Library/Caches/org.swift.swiftpm"),
            home.appendingPathComponent(".gradle/caches"),
            home.appendingPathComponent(".docker"),
        ]
        
        for path in paths {
            if fm.fileExists(atPath: path.path) {
                files += await scanDirectory(path, category: .developerCache, maxDepth: 2)
            }
        }
        
        return files
    }
    
    // MARK: - Comprehensive App Scan
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
                size += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            }
        }
        
        var bundleID = ""
        var version = ""
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        if let plist = try? PropertyListSerialization.propertyList(from: Data(contentsOf: infoPlist), format: nil) as? [String: Any] {
            bundleID = plist["CFBundleIdentifier"] as? String ?? ""
            version = plist["CFBundleShortVersionString"] as? String ?? ""
        }
        
        var leftoverURLs: [URL] = []
        if !bundleID.isEmpty {
            leftoverURLs += await findLeftoverURLs(bundleID: bundleID, appName: name)
        }
        
        return AppBundle(
            name: name,
            bundleID: bundleID,
            version: version,
            url: url,
            size: size,
            leftoverFiles: leftoverURLs
        )
    }
    
    private static func findLeftoverURLs(bundleID: String, appName: String) async -> [URL] {
        var leftovers: [URL] = []
        let fm = FileManager.default
        let home = PathConstants.home
        
        let searchPaths = [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Group Containers"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/Application Scripts"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/WebKit"),
            home.appendingPathComponent("Library/LaunchAgents"),
        ]
        
        let bundleComponents = bundleID.split(separator: ".")
        let lastComponent = bundleComponents.last.map(String.init) ?? ""
        let searchTerms = [bundleID, lastComponent, appName].filter { !$0.isEmpty }
        
        for base in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else { continue }
            for url in contents {
                let itemName = url.lastPathComponent
                let shouldMatch = searchTerms.contains { term in
                    itemName.lowercased().contains(term.lowercased())
                }
                
                if shouldMatch {
                    leftovers.append(url)
                }
            }
        }
        
        return leftovers
    }
}
