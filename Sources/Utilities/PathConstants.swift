import Foundation

enum PathConstants {
    static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
    
    static var caches: URL {
        home.appendingPathComponent("Library/Caches")
    }
    
    static var logs: URL {
        home.appendingPathComponent("Library/Logs")
    }
    
    static var applicationSupport: URL {
        home.appendingPathComponent("Library/Application Support")
    }
    
    static var downloads: URL {
        home.appendingPathComponent("Downloads")
    }
    
    static var trash: URL {
        home.appendingPathComponent(".Trash")
    }
    
    static var tmp: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    static var applications: URL {
        URL(fileURLWithPath: "/Applications")
    }
    
    static var userApplications: URL {
        home.appendingPathComponent("Applications")
    }
    
    static var safariHistory: URL {
        home.appendingPathComponent("Library/Safari/History.db")
    }
    
    static var chromeHistory: URL? {
        home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/History")
    }
    
    static var firefoxProfiles: URL? {
        home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
    }
    
    static var launchAgents: URL {
        home.appendingPathComponent("Library/LaunchAgents")
    }
    
    static var launchDaemons: URL {
        URL(fileURLWithPath: "/Library/LaunchDaemons")
    }
}
