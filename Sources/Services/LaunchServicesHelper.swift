import Foundation
import AppKit

/// Integration with macOS Launch Services and system data sources
/// to get real app usage data, installed bundle IDs, app categories,
/// and background agent detection.
enum LaunchServicesHelper {
    
    // MARK: - Installed Bundle IDs
    
    static func installedBundleIDs() -> Set<String> {
        var bundleIDs: Set<String> = []
        let fm = FileManager.default
        
        // Method 1: NSWorkspace installed apps
        for appURL in NSWorkspace.shared.installedApplications() {
            if let bundle = Bundle(url: appURL),
               let bid = bundle.bundleIdentifier, !bid.isEmpty {
                bundleIDs.insert(bid)
            }
        }
        
        // Method 2: Application Support directories
        let appSupport = PathConstants.home.appendingPathComponent("Library/Application Support")
        if let contents = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for url in contents {
                let name = url.lastPathComponent
                if name.contains(".") && name.count > 4 && !name.hasPrefix(".") {
                    bundleIDs.insert(name)
                }
            }
        }
        
        // Method 3: Containers
        let containers = PathConstants.home.appendingPathComponent("Library/Containers")
        if let contents = try? fm.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for url in contents {
                bundleIDs.insert(url.lastPathComponent)
            }
        }
        
        // Method 4: Group Containers
        let groupContainers = PathConstants.home.appendingPathComponent("Library/Group Containers")
        if let contents = try? fm.contentsOfDirectory(at: groupContainers, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for url in contents {
                let name = url.lastPathComponent
                if name.contains(".") {
                    bundleIDs.insert(name)
                }
            }
        }
        
        // Method 5: Saved Application State
        let savedState = PathConstants.home.appendingPathComponent("Library/Saved Application State")
        if let contents = try? fm.contentsOfDirectory(at: savedState, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for url in contents where url.pathExtension == "savedState" {
                let bundleID = url.deletingPathExtension().lastPathComponent
                if bundleID.contains(".") {
                    bundleIDs.insert(bundleID)
                }
            }
        }
        
        return bundleIDs
    }
    
    static func installedBundleIDsAsync() async -> Set<String> {
        await Task.detached { installedBundleIDs() }.value
    }
    
    // MARK: - App Usage Data
    
    /// Attempts to get days since last app usage.
    /// First tries the macOS KnowledgeC database, then falls back to file modification dates.
    static func daysSinceLastUsed(bundleID: String) -> Double? {
        // Try knowledgeC database first
        if let days = daysFromKnowledgeDB(bundleID: bundleID) {
            return days
        }
        
        // Fallback: check Application Support / Caches modification dates
        return daysFromFileDates(bundleID: bundleID)
    }
    
    private static func daysFromKnowledgeDB(bundleID: String) -> Double? {
        let dbPath = PathConstants.home.appendingPathComponent("Library/Application Support/Knowledge/knowledgeC.db").path
        
        // Try to open database
        guard let db = openSQLiteDB(path: dbPath) else { return nil }
        defer { closeSQLiteDB(db) }
        
        let query = """
            SELECT ZLASTUSEDDATE FROM ZUSAGECOUNTEDEVENT
            WHERE ZBUNDLEIDENTIFIER = ?
            ORDER BY ZLASTUSEDDATE DESC LIMIT 1
            """
        
        guard let stmt = prepareSQLiteStatement(db: db, sql: query) else { return nil }
        defer { finalizeSQLiteStatement(stmt) }
        
        bindSQLiteText(stmt: stmt, index: 1, text: bundleID)
        
        if stepSQLiteStatement(stmt) {
            let timestamp = doubleFromSQLiteColumn(stmt: stmt, column: 0)
            if timestamp > 0 {
                let date = Date(timeIntervalSinceReferenceDate: timestamp)
                return Date().timeIntervalSince(date) / 86400.0
            }
        }
        
        return nil
    }
    
    private static func daysFromFileDates(bundleID: String) -> Double? {
        let fm = FileManager.default
        let home = PathConstants.home
        
        // Check various support directories for this bundle's modification date
        let paths = [
            home.appendingPathComponent("Library/Application Support/\(bundleID)"),
            home.appendingPathComponent("Library/Caches/\(bundleID)"),
            home.appendingPathComponent("Library/Containers/\(bundleID)"),
        ]
        
        var mostRecent: Date?
        for path in paths {
            guard fm.fileExists(atPath: path.path) else { continue }
            if let attrs = try? fm.attributesOfItem(atPath: path.path),
               let modDate = attrs[.modificationDate] as? Date {
                if mostRecent == nil || modDate > mostRecent! {
                    mostRecent = modDate
                }
            }
        }
        
        guard let date = mostRecent else { return nil }
        return Date().timeIntervalSince(date) / 86400.0
    }
    
    // MARK: - App Category
    
    static func appCategory(appURL: URL) -> String {
        let name = appURL.deletingPathExtension().lastPathComponent.lowercased()
        
        let categories: [(String, [String])] = [
            ("Social", ["slack", "discord", "telegram", "whatsapp", "signal", "teams", "zoom", "skype", "webex", "gotomeeting", "mattermost", "element", "signal"]),
            ("Developer", ["xcode", "visual studio", "intellij", "webstorm", "pycharm", "datagrip", "docker", "postman", "sourcetree", "github", "tower", "sublime", "atom", "cursor", "fleet", "nova", "codekit", "dash", "charles", "proxyman"]),
            ("Media", ["spotify", "music", "vlc", "iina", "infuse", "plex", "netflix", "youtube", "tidal", "soundcloud", "deezer", "quicktime", "audacity", "obs"]),
            ("Productivity", ["notion", "obsidian", "evernote", "bear", "things", "omnifocus", "todoist", "trello", "linear", "asana", "monday", "clickup", "goodnotes", "notability", "craft", "ulysses", "pages", "numbers", "keynote"]),
            ("Creative", ["photoshop", "illustrator", "indesign", "premiere", "after effects", "final cut", "motion", "logic", "garageband", "ableton", "blender", "cinema", "sketch", "figma", "affinity", "procreate", "pixelmator", "acorn"]),
            ("Browser", ["safari", "chrome", "firefox", "edge", "brave", "opera", "vivaldi", "arc", "tor", "orion"]),
            ("Utilities", ["cleanmymac", "cleanmac", "onyx", "ccleaner", "malwarebytes", "little snitch", "istat", "coconut", "keychain", "console", "activity monitor", "terminal", "disk utility", "system", "app cleaner", "sensei", "stats", "hidden bar", "rectangle", "magnet", "bettertouchtool"]),
            ("Finance", ["quicken", "mint", "ynab", "robinhood", "coinbase", "bank", "credit", "expensify", "freshbooks"]),
            ("Game", ["steam", "epic games", "battle.net", "riot", "minecraft", "roblox", "gog", "origin", "ubisoft", "blizzard", "ea"]),
            ("Security", ["nordvpn", "expressvpn", "protonvpn", "tunnelbear", "1password", "bitwarden", "lastpass", "dashlane", "authy", "google authenticator"]),
        ]
        
        for (category, keywords) in categories {
            if keywords.contains(where: { name.contains($0) }) {
                return category
            }
        }
        
        return "Other"
    }
    
    // MARK: - Background Agent Detection
    
    static func hasBackgroundAgents(bundleID: String) -> Bool {
        let fm = FileManager.default
        let searchPaths = [
            PathConstants.home.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]
        
        let lastComponent = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        let searchTerms = [bundleID, lastComponent].filter { !$0.isEmpty }
        
        for base in searchPaths {
            guard fm.fileExists(atPath: base.path),
                  let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for url in contents where url.pathExtension == "plist" {
                let itemName = url.lastPathComponent.lowercased()
                if searchTerms.contains(where: { itemName.contains($0.lowercased()) }) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - SQLite Helpers (Runtime Dynamic Loading)
    
    /// Uses dlopen to dynamically load libsqlite3, avoiding direct linking issues
    private static func openSQLiteDB(path: String) -> OpaquePointer? {
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        guard handle != nil else { return nil }
        
        typealias OpenFn = @convention(c) (UnsafePointer<CChar>?, UnsafeMutablePointer<OpaquePointer?>?) -> CInt
        guard let sym = dlsym(handle, "sqlite3_open") else { return nil }
        let sqlite3_open = unsafeBitCast(sym, to: OpenFn.self)
        
        var db: OpaquePointer?
        let result = sqlite3_open(path, &db)
        dlclose(handle)
        
        return result == 0 ? db : nil
    }
    
    private static func closeSQLiteDB(_ db: OpaquePointer?) {
        guard let db else { return }
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        defer { dlclose(handle) }
        
        typealias CloseFn = @convention(c) (OpaquePointer?) -> CInt
        guard let sym = dlsym(handle, "sqlite3_close") else { return }
        let sqlite3_close = unsafeBitCast(sym, to: CloseFn.self)
        _ = sqlite3_close(db)
    }
    
    private static func prepareSQLiteStatement(db: OpaquePointer, sql: String) -> OpaquePointer? {
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        defer { dlclose(handle) }
        
        typealias PrepareFn = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, CInt, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> CInt
        guard let sym = dlsym(handle, "sqlite3_prepare_v2") else { return nil }
        let sqlite3_prepare_v2 = unsafeBitCast(sym, to: PrepareFn.self)
        
        var stmt: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        return result == 0 ? stmt : nil
    }
    
    private static func finalizeSQLiteStatement(_ stmt: OpaquePointer?) {
        guard let stmt else { return }
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        defer { dlclose(handle) }
        
        typealias FinalizeFn = @convention(c) (OpaquePointer?) -> CInt
        guard let sym = dlsym(handle, "sqlite3_finalize") else { return }
        let sqlite3_finalize = unsafeBitCast(sym, to: FinalizeFn.self)
        _ = sqlite3_finalize(stmt)
    }
    
    private static func bindSQLiteText(stmt: OpaquePointer, index: Int, text: String) {
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        defer { dlclose(handle) }
        
        typealias BindFn = @convention(c) (OpaquePointer?, CInt, UnsafePointer<CChar>?, CInt, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> CInt
        guard let sym = dlsym(handle, "sqlite3_bind_text") else { return }
        let sqlite3_bind_text = unsafeBitCast(sym, to: BindFn.self)
        _ = sqlite3_bind_text(stmt, CInt(index), text, -1, nil)
    }
    
    private static func stepSQLiteStatement(_ stmt: OpaquePointer) -> Bool {
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        defer { dlclose(handle) }
        
        typealias StepFn = @convention(c) (OpaquePointer?) -> CInt
        guard let sym = dlsym(handle, "sqlite3_step") else { return false }
        let sqlite3_step = unsafeBitCast(sym, to: StepFn.self)
        return sqlite3_step(stmt) == 100 // SQLITE_ROW = 100
    }
    
    private static func doubleFromSQLiteColumn(stmt: OpaquePointer, column: Int) -> Double {
        let handle = dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW)
        defer { dlclose(handle) }
        
        typealias ColumnFn = @convention(c) (OpaquePointer?, CInt) -> CDouble
        guard let sym = dlsym(handle, "sqlite3_column_double") else { return 0 }
        let sqlite3_column_double = unsafeBitCast(sym, to: ColumnFn.self)
        return sqlite3_column_double(stmt, CInt(column))
    }
}

// MARK: - NSWorkspace Extension

extension NSWorkspace {
    func installedApplications() -> [URL] {
        var apps: [URL] = []
        let fm = FileManager.default
        let paths = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        ]
        
        for base in paths {
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            for url in contents where url.pathExtension == "app" {
                apps.append(url)
            }
        }
        
        return apps
    }
}
