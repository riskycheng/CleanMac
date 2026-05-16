# CleanMac Scanning & Management Algorithm

## Overview

This document describes the advanced scanning, scoring, and management algorithms used by CleanMac. The algorithm is designed to be **accurate, safe, and transparent** — every file recommendation is backed by measurable criteria, and all destructive operations move files to the macOS Trash (never permanent deletion).

---

## 1. Intelligent Junk Scanner (`SmartJunkScanner`)

### 1.1 Multi-Factor Junk Scoring

Each candidate file receives a `JunkScore` from 0.0 to 1.0 computed as a weighted product of four factors:

```
JunkScore = AgeWeight × SizeWeight × CategoryWeight × OrphanWeight
```

| Factor | Description | Weight Range |
|--------|-------------|-------------|
| **AgeWeight** | How long since the file was last modified/accessed | 0.1 – 1.0 |
| **SizeWeight** | How large the file is (larger = more reclaimable) | 0.1 – 1.0 |
| **CategoryWeight** | How "safe" the category is to delete | 0.5 – 1.0 |
| **OrphanWeight** | Whether the owning application is still installed | 0.0 or 1.0 |

#### Age Weighting

```swift
func ageWeight(days: Double) -> Double {
    switch days {
    case ..<7:    return 0.1   // Very recent — likely in use
    case 7..<30:  return 0.3   // Recent — possibly in use
    case 30..<90: return 0.6   // Old — probably safe
    case 90..<180: return 0.8  // Very old — almost certainly safe
    default:      return 1.0   // Ancient — definitely safe
    }
}
```

For cache files, we use **modification date** (`contentModificationDate`).  
For log files, we use the **log rotation timestamp** or modification date.

#### Size Weighting

```swift
func sizeWeight(bytes: Int64) -> Double {
    let mb = Double(bytes) / 1_048_576
    switch mb {
    case ..<1:      return 0.1
    case 1..<10:    return 0.3
    case 10..<100:  return 0.6
    case 100..<500: return 0.8
    default:        return 1.0
    }
}
```

Larger files are weighted higher because they provide more reclaimable space.

#### Category Weighting

| Category | Weight | Rationale |
|----------|--------|-----------|
| `tempFiles` | 1.0 | Temp files are designed to be ephemeral |
| `brokenDownloads` | 1.0 | Incomplete downloads are useless |
| `trash` | 1.0 | Already in trash |
| `logs` | 0.9 | Logs older than 30 days are rarely needed |
| `systemLogs` | 0.9 | System logs rotate automatically |
| `caches` | 0.8 | Caches are rebuildable |
| `systemCaches` | 0.8 | System caches are rebuildable |
| `browserCache` | 0.8 | Browser caches rebuild on next launch |
| `xcodeJunk` | 0.8 | DerivedData/Archives are rebuildable |
| `developerCache` | 0.8 | npm/yarn/pip caches are redownloadable |
| `orphanedSupport` | 0.9 | Leftover files from uninstalled apps |
| `userLogs` | 0.9 | User logs are generally safe after 30 days |

#### Orphan Weighting

```swift
func orphanWeight(path: URL, installedBundleIDs: Set<String>) -> Double {
    // Extract bundle ID from path (e.g., "~/Library/Caches/com.company.app")
    let pathComponents = path.pathComponents
    for component in pathComponents {
        let reversed = component.split(separator: ".").reversed().joined(separator: ".")
        // Check if any installed app's bundle ID contains this component
        if installedBundleIDs.contains(where: { $0.lowercased().contains(component.lowercased()) }) {
            return 0.0  // Owning app still exists — not an orphan
        }
    }
    return 1.0  // No owning app found — orphan
}
```

### 1.2 Scanning Locations

The scanner covers **14 categories** across **40+ filesystem locations**:

#### User Caches
- `~/Library/Caches/*` — Application caches
- `~/Library/Caches/com.apple.*` — macOS system caches

#### System Caches
- `/System/Library/Caches/*`
- `/Library/Caches/*`
- `/private/var/folders/*` — macOS temporary file storage

#### Log Files
- `~/Library/Logs/*`
- `/var/log/*`
- `/private/var/log/*`
- `~/Library/Logs/DiagnosticReports/*` — Crash logs

#### Temporary Files
- `NSTemporaryDirectory()`
- `/tmp/*`
- `/var/tmp/*`
- `~/Library/Containers/*/tmp/`

#### Broken Downloads
- `~/Downloads/*.crdownload`, `*.part`, `*.download`, `*.partial`

#### Trash
- `~/.Trash/*`

#### Orphaned Support Files
- `~/Library/Application Support/*` — Cross-referenced with installed apps
- `~/Library/Preferences/*.plist` — Cross-referenced with installed apps
- `~/Library/Saved Application State/*.savedState`
- `~/Library/Application Scripts/*`

#### Browser Cache
- Safari: `~/Library/Caches/com.apple.Safari`, `~/Library/WebKit/com.apple.Safari`
- Chrome: `~/Library/Caches/Google/Chrome`, `~/Library/Application Support/Google/Chrome/Default/Cache`
- Firefox: `~/Library/Caches/Firefox/Profiles/*`
- Edge: `~/Library/Caches/Microsoft Edge/*`

#### Xcode Artifacts
- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Developer/Xcode/Archives`
- `~/Library/Developer/Xcode/iOS DeviceSupport`
- `~/Library/Developer/CoreSimulator`

#### Developer Caches
- npm: `~/.npm/_cacache`
- Yarn: `~/.yarn/cache`
- CocoaPods: `~/Library/Caches/CocoaPods`
- SwiftPM: `~/Library/Caches/org.swift.swiftpm`
- pip: `~/Library/Caches/pip`
- Docker: `~/.docker`
- Gradle: `~/.gradle/caches`

#### Mail Attachments
- `~/Library/Mail Downloads/*`
- `~/Library/Mail/V*/Mailboxes/*/Attachments/*`

#### Messages Attachments
- `~/Library/Messages/Attachments/*`

#### iOS Device Backups
- `~/Library/Application Support/MobileSync/Backup/*`

#### Photo Cache
- `~/Library/Containers/com.apple.photolibraryd/Data/Library/Caches/`

### 1.3 Orphaned File Detection Algorithm

```
ORPHANED-FILE-DETECTION:
    1. Collect all installed app bundle IDs via:
       a. LSRegister database (LSCopyApplicationURLsForBundleIdentifier)
       b. /Applications/*.app Info.plist CFBundleIdentifier
       c. ~/Applications/*.app Info.plist CFBundleIdentifier
    
    2. For each candidate directory in support locations:
       a. Extract the folder name (e.g., "com.slack.Slack")
       b. Check if any installed bundle ID matches (case-insensitive)
       c. If NO match → mark as ORPHANED
       d. If match → skip (not junk)
    
    3. Special cases:
       a. Folders with generic names ("Apple", "Microsoft") → skip
       b. Folders under 100KB → skip (not worth cleanup)
```

### 1.4 Large File Detection

Files > 100MB are flagged as "Large Files" regardless of category, as they represent the highest-impact cleanup targets. These are surfaced in a dedicated section.

---

## 2. Smart App Scanner (`SmartAppScanner`)

### 2.1 App Discovery

Apps are discovered from multiple sources:
1. `/Applications/*.app` — System-wide applications
2. `~/Applications/*.app` — User applications
3. `~/Library/Widgets/*.wdgt` — Dashboard widgets (legacy)
4. `/Library/PreferencePanes/*.prefPane` — System preference panes
5. `~/Library/PreferencePanes/*.prefPane` — User preference panes

### 2.2 True Size Calculation

```
TRUE-APP-SIZE(bundleID, appURL):
    1. appBundleSize = recursiveSize(appURL)
    2. supportSize = sum of:
       - ~/Library/Application Support/{bundleID}/
       - ~/Library/Caches/{bundleID}/
       - ~/Library/Preferences/{bundleID}*.plist
       - ~/Library/Containers/{bundleID}/
       - ~/Library/Group Containers/{groupID}/ (if applicable)
       - ~/Library/Saved Application State/{bundleID}.savedState/
       - ~/Library/Application Scripts/{bundleID}/
       - ~/Library/WebKit/{bundleID}/
       - ~/Library/Logs/{bundleID}/
       - /private/var/folders/*/C/{bundleID}/
    3. pluginSize = sum of:
       - /Library/QuickLook/{bundleID}*.qlgenerator
       - ~/Library/QuickLook/{bundleID}*.qlgenerator
       - /Library/Spotlight/{bundleID}*.mdimporter
       - ~/Library/Spotlight/{bundleID}*.mdimporter
       - /Library/Extensions/{bundleID}*.kext
    4. agentSize = sum of associated LaunchAgents/LaunchDaemons
    5. return appBundleSize + supportSize + pluginSize + agentSize
```

### 2.3 Unused App Detection

```
UNUSED-APP-DETECTION(appURL, bundleID):
    1. Query Spotlight for kMDItemLastUsedDate:
       mdfind "kMDItemCFBundleIdentifier == '{bundleID}'"
    
    2. If Spotlight returns a lastUsedDate:
       daysSinceUsed = now - lastUsedDate
       if daysSinceUsed > 180:
           return HIGHLY_UNUSED
       else if daysSinceUsed > 90:
           return MODERATELY_UNUSED
       else:
           return ACTIVE
    
    3. Fallback: Check Launch Services database via NSWorkspace
    
    4. Fallback: Check file modification date of the .app bundle
       if bundle mod date > 180 days ago:
           return POSSIBLY_UNUSED
```

### 2.4 App Categorization

```
APP-CATEGORIZATION(infoPlist):
    1. Read LSApplicationCategoryType from Info.plist
    2. Map to display category:
       - public.app-category.business → Productivity
       - public.app-category.developer-tools → Development
       - public.app-category.graphics-design → Design
       - public.app-category.social-networking → Social
       - public.app-category.entertainment → Entertainment
       - public.app-category.games → Games
       - public.app-category.education → Education
       - public.app-category.finance → Finance
       - public.app-category.health-fitness → Health
       - public.app-category.news → News
       - public.app-category.photography → Photography
       - public.app-category.reference → Reference
       - public.app-category.utilities → Utilities
       - public.app-category.video → Video
       - public.app-category.music → Music
    3. Fallback: Parse bundle ID for known publishers:
       - com.apple.* → System
       - com.microsoft.* → Productivity
       - com.google.* → Internet
       - com.adobe.* → Design
    4. Fallback: Use file system location:
       - /System/Applications/* → System
       - /Applications/Xcode.app → Development
```

### 2.5 Background App Detection

```
BACKGROUND-APP-DETECTION(bundleID, appURL):
    1. Check for associated LaunchAgents:
       Search ~/Library/LaunchAgents/ and /Library/LaunchAgents/
       for .plist files referencing the bundle ID
    
    2. Check for associated LaunchDaemons:
       Search /Library/LaunchDaemons/ for .plist files
       referencing the bundle ID
    
    3. Check Info.plist for UIBackgroundModes (rare on Mac)
       or LSBackgroundOnly = true
    
    4. If any found → mark as BACKGROUND_APP
```

---

## 3. App Update Checker (`AppUpdateChecker`)

### 3.1 Sparkle Framework Detection

```
SPARKLE-UPDATE-CHECK(appURL, infoPlist):
    1. Check if app contains Sparkle.framework:
       appURL/Contents/Frameworks/Sparkle.framework exists?
    
    2. Read feed URL from Info.plist:
       - SUFeedURL (Sparkle 1.x)
       - SUFeedURL_str (alternate key)
       - For Sparkle 2.x with edDSA: extract from appcast or SUAppcast
    
    3. Fetch appcast XML from feed URL
    
    4. Parse the <enclosure> or <item> for sparkle:version
    
    5. Compare sparkle:version with app's CFBundleVersion
    
    6. If remote > local → UPDATE_AVAILABLE
```

### 3.2 Homebrew Cask Detection

```
HOMEBREW-UPDATE-CHECK():
    1. Check if Homebrew is installed: /opt/homebrew/bin/brew or /usr/local/bin/brew
    
    2. Run: brew outdated --json=v2
    
    3. Parse JSON output for outdated casks
    
    4. Map cask names to app bundle IDs (where possible)
    
    5. For each matching installed app → mark as UPDATE_AVAILABLE
    
    6. Cache results for 1 hour to avoid repeated shell calls
```

### 3.3 App Store Detection

```
APP-STORE-DETECTION(appURL):
    1. Check for App Store receipt:
       appURL/Contents/_MASReceipt/receipt exists?
    
    2. If present → mark as APP_STORE
    
    3. Read bundle ID from Info.plist
    
    4. (Optional) Query iTunes Search API for latest version:
       https://itunes.apple.com/lookup?bundleId={bundleID}
    
    5. Compare with local version
```

---

## 4. Complete Uninstaller (`AppUninstaller`)

### 4.1 Comprehensive Leftover Discovery

```
DISCOVER-LEFTOVERS(bundleID, appName, appURL):
    leftovers = []
    
    // Standard support directories
    SEARCH-PATHS = [
        ~/Library/Application Support,
        ~/Library/Caches,
        ~/Library/Preferences,
        ~/Library/Containers,
        ~/Library/Group Containers,
        ~/Library/Saved Application State,
        ~/Library/Application Scripts,
        ~/Library/Logs,
        ~/Library/WebKit,
        ~/Library/LaunchAgents,
        /Library/Application Support,
        /Library/Caches,
        /Library/Preferences,
        /Library/LaunchAgents,
        /Library/LaunchDaemons,
        /Library/PrivilegedHelperTools,
        /private/var/db/receipts,
    ]
    
    for path in SEARCH-PATHS:
        for item in directoryContents(path):
            if item.name matches bundleID OR item.name matches appName:
                leftovers.append(item)
    
    // Plugin directories
    PLUGIN-PATHS = [
        /Library/QuickLook,
        ~/Library/QuickLook,
        /Library/Spotlight,
        ~/Library/Spotlight,
        /Library/Extensions,
        /System/Library/Extensions,
    ]
    
    for path in PLUGIN-PATHS:
        for item in directoryContents(path):
            if item.name matches bundleID:
                leftovers.append(item)
    
    // Kernel extensions (requires elevated privileges, warn user)
    KEXT-PATHS = [
        /Library/Extensions,
        /System/Library/Extensions,
    ]
    
    // Login items (read from LSSharedFileList or modern API)
    loginItems = getLoginItems()
    for item in loginItems:
        if item.bundleID == bundleID:
            leftovers.append(item)
    
    return leftovers
```

### 4.2 Safety Rules

1. **Never permanently delete.** All operations use `FileManager.trashItem()`.
2. **Require explicit selection.** No file is removed without user confirmation.
3. **System file protection.** Files in `/System/`, `/usr/`, `/bin/`, `/sbin/` are NEVER touched.
4. **Preference backup.** Before removing `.plist` files, optionally offer to back them up.
5. **Admin privilege warning.** If uninstall requires elevated privileges (e.g., kernel extensions), warn the user and skip those files.

### 4.3 Uninstall Preview

Before any cleanup, the user sees a preview:

```
App Bundle:          245 MB
Application Support:  12 MB
Caches:               89 MB
Preferences:           4 KB
Containers:          156 MB
Login Items:           2 items
LaunchAgents:          1 plist
─────────────────────────────
Total Reclaimable:   502 MB
```

---

## 5. Implementation Architecture

### 5.1 Service Layer

```
Services/
├── SystemInfo.swift              // Disk, Memory, CPU (existing)
├── SmartJunkScanner.swift        // Junk scanning + scoring
├── SmartAppScanner.swift         // App discovery + analysis
├── AppUpdateChecker.swift        // Sparkle / Homebrew / MAS
├── AppUninstaller.swift          // Leftover discovery + removal
└── LaunchServicesHelper.swift    // LSRegister queries, bundle ID lookups
```

### 5.2 Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  SmartJunkScan  │────▶│  JunkScore Engine│────▶│  UI Results  │
│  (40+ locations)│     │  (4-factor score)│     │  (categorized)│
└─────────────────┘     └──────────────────┘     └─────────────┘

┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  SmartAppScan   │────▶│  App Analysis    │────▶│  UI Results  │
│  (LS + Spotlight)│     │  (size + usage)  │     │  (sorted)    │
└─────────────────┘     └──────────────────┘     └─────────────┘

┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  AppUpdateCheck │────▶│  Version Compare │────▶│  UI Results  │
│  (Sparkle + HB) │     │  (semver parse)  │     │  (outdated)  │
└─────────────────┘     └──────────────────┘     └─────────────┘
```

### 5.3 Concurrency Model

All scanning operations run on a **background Task** with `@MainActor` results:

```swift
Task {
    let results = await SmartJunkScanner.scan()
    await MainActor.run {
        viewModel.junkFiles = results
    }
}
```

Each location is scanned **concurrently** using `TaskGroup`:

```swift
await withTaskGroup(of: [JunkFile].self) { group in
    for location in locations {
        group.addTask { await scanLocation(location) }
    }
    // Collect results...
}
```

### 5.4 Caching Strategy

- **App bundle ID cache:** Cached for the app session (rarely changes during use)
- **App size cache:** Cached for 5 minutes (sizes don't change rapidly)
- **Homebrew cache:** Cached for 1 hour (`brew outdated` is expensive)
- **Sparkle appcast cache:** Cached per-app for 30 minutes
