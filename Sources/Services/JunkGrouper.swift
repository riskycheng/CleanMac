import Foundation

/// Groups raw junk files by their owning app, inspired by MacSift.
/// Extracts bundle IDs from paths like `~/Library/Caches/com.apple.Safari/...`
/// and maps them to human-readable app names.
enum JunkGrouper {
    
    // MARK: - Main Grouping
    
    static func group(_ files: [JunkFile]) -> [JunkGroup] {
        var buckets: [String: [JunkFile]] = [:]
        
        for file in files {
            let groupKey = appName(for: file.path)
            buckets[groupKey, default: []].append(file)
        }
        
        return buckets.map { (name, files) in
            // Use the most common category among files, or .caches as fallback
            let category = files.mostCommonCategory()
            return JunkGroup(
                appName: name,
                category: category,
                files: files.sorted { $0.size > $1.size }
            )
        }.sorted { $0.totalSize > $1.totalSize }
    }
    
    // MARK: - App Name Extraction
    
    private static func appName(for path: String) -> String {
        let components = path.split(separator: "/")
        
        // Look for a reverse-DNS component in the path
        for (index, component) in components.enumerated() {
            let name = String(component)
            if name.contains(".") && !name.hasPrefix(".") && name.count > 4 {
                // This looks like a bundle ID: com.apple.Safari, com.google.Chrome, etc.
                // Check if we have a human-readable mapping
                if let mapped = bundleIDToName[name] {
                    return mapped
                }
                // Try extracting the last segment as a fallback
                let last = name.split(separator: ".").last.map(String.init) ?? name
                return last.capitalized
            }
            
            // For standard macOS library paths, the parent of the file is the group
            if index >= 2 {
                let parent = String(components[index - 1])
                let grandparent = index >= 3 ? String(components[index - 2]) : ""
                
                // If parent is a known library folder, use the folder before it
                if ["Caches", "Logs", "Application Support", "Preferences",
                    "Containers", "Group Containers", "Saved Application State",
                    "Application Scripts", "WebKit", "HTTPStorages", "Cookies"].contains(parent) {
                    if grandparent == "Library" || grandparent == "Data" {
                        // Use the directory name itself
                        return String(component).capitalized
                    }
                    return parent
                }
            }
        }
        
        // Ultimate fallback: last path component
        return (components.last.map(String.init) ?? "Unknown").capitalized
    }
    
    // MARK: - Bundle ID → Name Mapping
    
    private static let bundleIDToName: [String: String] = [
        // Apple
        "com.apple.Safari": "Safari",
        "com.apple.finder": "Finder",
        "com.apple.dock": "Dock",
        "com.apple.Music": "Music",
        "com.apple.mail": "Mail",
        "com.apple.MobileSMS": "Messages",
        "com.apple.Photos": "Photos",
        "com.apple.iPhoto": "Photos",
        "com.apple.dt.Xcode": "Xcode",
        "com.apple.iphonesimulator": "Simulator",
        "com.apple.WebKit": "WebKit",
        "com.apple.Spotlight": "Spotlight",
        "com.apple.Safari.SafeBrowsing.Service": "Safari",
        "com.apple.Safari.WebApp": "Safari",
        "com.apple.siri": "Siri",
        "com.apple.podcasts": "Podcasts",
        "com.apple.tv": "TV",
        "com.apple.Maps": "Maps",
        "com.apple.calculator": "Calculator",
        "com.apple.Preview": "Preview",
        "com.apple.QuickTimePlayerX": "QuickTime Player",
        "com.apple.Terminal": "Terminal",
        "com.apple.systempreferences": "System Settings",
        "com.apple.AppStore": "App Store",
        "com.apple.CoreSimulator": "Simulator",
        
        // Browsers
        "com.google.Chrome": "Google Chrome",
        "com.google.Chrome.canary": "Chrome Canary",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.mozilla.firefox": "Firefox",
        "org.mozilla.firefox": "Firefox",
        "com.operasoftware.Opera": "Opera",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "company.thebrowser.Browser": "Arc",
        "com.brave.Browser": "Brave",
        
        // Development
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.jetbrains.intellij": "IntelliJ IDEA",
        "com.jetbrains.WebStorm": "WebStorm",
        "com.jetbrains.PyCharm": "PyCharm",
        "com.jetbrains.DataGrip": "DataGrip",
        "com.jetbrains.CLion": "CLion",
        "com.jetbrains.AppCode": "AppCode",
        "com.jetbrains.RubyMine": "RubyMine",
        "com.jetbrains.GoLand": "GoLand",
        "com.jetbrains.Rider": "Rider",
        "com.sublimetext.4": "Sublime Text",
        "com.sublimetext.3": "Sublime Text",
        "com.github.atom": "Atom",
        "dev.zed.Zed": "Zed",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        
        // Communication
        "com.tinyspeck.slack.macgap": "Slord",
        "com.hnc.Discord": "Discord",
        "ru.keepcoder.Telegram": "Telegram",
        "com.apple.iChat": "Messages",
        "com.microsoft.teams": "Microsoft Teams",
        "com.microsoft.skype.teams": "Microsoft Teams",
        "us.zoom.xos": "Zoom",
        "com.skype.skype": "Skype",
        
        // Productivity
        "notion.id": "Notion",
        "md.obsidian": "Obsidian",
        "com.evernote.Evernote": "Evernote",
        "net.shinyfrog.bear": "Bear",
        "com.culturedcode.ThingsMac": "Things",
        "com.omnigroup.OmniFocus3": "OmniFocus",
        "com.todoist.mac.Todoist": "Todoist",
        "com.atlassian.trello": "Trello",
        "com.linear": "Linear",
        "com.asana.Asana": "Asana",
        "com.apple.iWork.Pages": "Pages",
        "com.apple.iWork.Numbers": "Numbers",
        "com.apple.iWork.Keynote": "Keynote",
        "com.goodnotesapp.x": "GoodNotes",
        
        // Creative
        "com.adobe.Photoshop": "Adobe Photoshop",
        "com.adobe.Illustrator": "Adobe Illustrator",
        "com.adobe.InDesign": "Adobe InDesign",
        "com.adobe.PremierePro": "Adobe Premiere Pro",
        "com.adobe.AfterEffects": "Adobe After Effects",
        "com.adobe.Lightroom": "Adobe Lightroom",
        "com.apple.FinalCut": "Final Cut Pro",
        "com.apple.motionapp": "Motion",
        "com.apple.logic10": "Logic Pro",
        "com.apple.garageband10": "GarageBand",
        "com.ableton.live": "Ableton Live",
        "org.blenderfoundation.blender": "Blender",
        "com.bohemiancoding.sketch3": "Sketch",
        "com.figma.Desktop": "Figma",
        "com.seriflabs.affinitydesigner2": "Affinity Designer",
        
        // Media
        "com.spotify.client": "Spotify",
        "com.netflix.Netflix": "Netflix",
        "com.vlc.vlc": "VLC",
        "com.colliderli.iina": "IINA",
        "com.firecore.infuse": "Infuse",
        "com.plexapp.plexmediaserver": "Plex",
        
        // Utilities
        "com.macpaw.CleanMyMac4": "CleanMyMac",
        "com.piriform.ccleaner": "CCleaner",
        "com.littlesnitch": "Little Snitch",
        "com.bjango.istatmenus": "iStat Menus",
        "com.coconut-flavour.coconutbattery": "CoconutBattery",
        "net.freemacsoft.AppCleaner": "AppCleaner",
        "com.protonvpn.mac": "Proton VPN",
        
        // Package Managers
        "com.apple.dt.SwiftPlayground": "Swift Playgrounds",
        
        // Social
        "com.facebook.archon": "Messenger",
        "com.whatsapp.WhatsApp": "WhatsApp",
        
        // Finance
        "com.intuit.quicken.2018": "Quicken",
        
        // Games
        "com.valvesoftware.steam": "Steam",
        "com.epicgames.EpicGamesLauncher": "Epic Games",
    ]
}

// MARK: - Array Extension

private extension [JunkFile] {
    func mostCommonCategory() -> JunkCategory {
        let counts = self.reduce(into: [:]) { counts, file in
            counts[file.category, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .caches
    }
}
