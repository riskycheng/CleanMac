import Foundation

/// Advanced app scanner that discovers applications, calculates true sizes
/// (including all support files), detects unused apps, and categorizes them.
enum AppIntelligenceEngine {
    
    // MARK: - Main Scan
    
    static func scanAll() async -> [AppBundle] {
        let appURLs = discoverAppURLs()
        let installedBundleIDs = await LaunchServicesHelper.installedBundleIDsAsync()
        
        return await withTaskGroup(of: AppBundle?.self) { group in
            for url in appURLs {
                group.addTask {
                    await analyzeApp(url: url, installedBundleIDs: installedBundleIDs)
                }
            }
            
            var results: [AppBundle] = []
            for await result in group {
                if let r = result { results.append(r) }
            }
            return results.sorted { $0.totalSize > $1.totalSize }
        }
    }
    
    // MARK: - App Discovery
    
    private static func discoverAppURLs() -> [URL] {
        let fm = FileManager.default
        var urls: [URL] = []
        
        let paths = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        ]
        
        for base in paths {
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else { continue }
            for url in contents where url.pathExtension == "app" {
                urls.append(url)
            }
        }
        
        return urls
    }
    
    // MARK: - App Analysis
    
    private static func analyzeApp(url: URL, installedBundleIDs: Set<String>) async -> AppBundle? {
        let fm = FileManager.default
        let name = url.deletingPathExtension().lastPathComponent
        
        // Parse Info.plist
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        var bundleID = ""
        var version = ""
        var plistDict: [String: Any]?
        
        if let data = try? Data(contentsOf: infoPlist),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            plistDict = plist
            bundleID = plist["CFBundleIdentifier"] as? String ?? ""
            version = plist["CFBundleShortVersionString"] as? String ?? ""
        }
        
        // Calculate true size (bundle + all support files)
        let bundleSize = recursiveSize(of: url)
        let leftovers = findLeftovers(bundleID: bundleID, appName: name)
        _ = leftovers.reduce(Int64(0)) { sum, u in sum + (fileSize(at: u) ?? 0) }
        
        // Intelligence
        let category = LaunchServicesHelper.appCategory(appURL: url)
        let daysSinceUsed = bundleID.isEmpty ? nil : LaunchServicesHelper.daysSinceLastUsed(bundleID: bundleID)
        let hasBgAgents = !bundleID.isEmpty && LaunchServicesHelper.hasBackgroundAgents(bundleID: bundleID)
        let is32Bit = check32Bit(appURL: url, plist: plistDict)
        let isAppStore = fm.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path)
        
        return AppBundle(
            name: name,
            bundleID: bundleID,
            version: version,
            url: url,
            size: bundleSize,
            leftoverFiles: leftovers,
            isSelected: false,
            category: category,
            daysSinceUsed: daysSinceUsed,
            hasBackgroundAgents: hasBgAgents,
            is32Bit: is32Bit,
            isAppStore: isAppStore
        )
    }
    
    // MARK: - True Size Calculation
    
    static func recursiveSize(of url: URL) -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            var checkCount = 0
            while let next = enumerator.nextObject() {
                checkCount += 1
                if checkCount % 200 == 0 && Task.isCancelled { break }
                guard let fileURL = next as? URL else { continue }
                total += (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            }
        }
        return total
    }
    
    static func fileSize(at url: URL) -> Int64? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
    }
    
    // MARK: - Leftover Discovery
    
    static func findLeftovers(bundleID: String, appName: String) -> [URL] {
        guard !bundleID.isEmpty else { return [] }
        
        let fm = FileManager.default
        let home = PathConstants.home
        var leftovers: [URL] = []
        
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
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for url in contents {
                let itemName = url.lastPathComponent
                if searchTerms.contains(where: { itemName.lowercased().contains($0.lowercased()) }) {
                    leftovers.append(url)
                }
            }
        }
        
        // System-level paths
        let systemPaths = [
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
            URL(fileURLWithPath: "/Library/PrivilegedHelperTools"),
            URL(fileURLWithPath: "/Library/Extensions"),
            URL(fileURLWithPath: "/Library/QuickLook"),
            URL(fileURLWithPath: "/Library/Spotlight"),
        ]
        
        for base in systemPaths {
            guard fm.fileExists(atPath: base.path),
                  let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for url in contents {
                let itemName = url.lastPathComponent
                if searchTerms.contains(where: { itemName.lowercased().contains($0.lowercased()) }) {
                    leftovers.append(url)
                }
            }
        }
        
        return leftovers
    }
    
    // MARK: - 32-bit Detection
    
    private static func check32Bit(appURL: URL, plist: [String: Any]?) -> Bool {
        if let archDict = plist?["LSMinimumSystemVersionByArchitecture"] as? [String: String] {
            return archDict.keys.contains("i386") && !archDict.keys.contains("x86_64")
        }
        
        if let platforms = plist?["CFBundleSupportedPlatforms"] as? [String] {
            return platforms.contains("iPhoneOS") || platforms.contains("iOS")
        }
        
        if let execName = plist?["CFBundleExecutable"] as? String {
            let execPath = appURL.appendingPathComponent("Contents/MacOS/\(execName)")
            if FileManager.default.fileExists(atPath: execPath.path) {
                if let data = try? Data(contentsOf: execPath, options: .mappedIfSafe), data.count >= 8 {
                    let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
                    return magic == 0xfeedface // MH_MAGIC = 32-bit
                }
            }
        }
        
        return false
    }
    
    // MARK: - Intelligence Queries
    
    static func unusedApps(_ apps: [AppBundle], daysThreshold: Double = 90) -> [AppBundle] {
        apps.filter { $0.isUnused }
    }
    
    static func largeApps(_ apps: [AppBundle], thresholdMB: Double = 500) -> [AppBundle] {
        apps.filter { Double($0.totalSize) / 1_048_576 > thresholdMB }
    }
    
    static func backgroundApps(_ apps: [AppBundle]) -> [AppBundle] {
        apps.filter { $0.hasBackgroundAgents }
    }
    
    static func appsByCategory(_ apps: [AppBundle]) -> [String: [AppBundle]] {
        Dictionary(grouping: apps, by: { $0.category })
    }
}
