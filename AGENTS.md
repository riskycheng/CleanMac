# CleanMac — Agent Context

## Project
- **Name**: CleanMac
- **Repo**: https://github.com/riskycheng/CleanMac
- **Stack**: macOS 14.0+, Swift 6.3.1, Xcode 26.4.1, SwiftUI with `@Observable`
- **Build**: xcodegen (`project.yml` → `.xcodeproj`)
- **Architecture**: MVVM, single-window SwiftUI app
- **Window**: `.hiddenTitleBar`, 1100×750, transparent titlebar (no dark strip)
- **Theme**: Light "PureClean" — gray `#F0F0F2` bg, white cards, soft shadows, `#111827` text

## Build
```bash
xcodegen generate && xcodebuild -project CleanMac.xcodeproj -scheme CleanMac -destination 'platform=macOS' build
```

## Key Files
| Purpose | Path |
|---------|------|
| Project spec | `project.yml` |
| App entry | `Sources/CleanMacApp.swift` |
| Main view | `Sources/ContentView.swift` |
| Junk model | `Sources/Models/JunkFile.swift` |
| App model | `Sources/Models/AppBundle.swift` |
| Basic scanner | `Sources/Services/FileScanner.swift` |
| **Advanced junk scan** | `Sources/Services/FileScanner+Advanced.swift` |
| **App intelligence** | `Sources/Services/AppIntelligenceEngine.swift` |
| **Launch Services** | `Sources/Services/LaunchServicesHelper.swift` |
| System info | `Sources/Services/SystemInfo.swift` |
| Algorithm design | `ALGORITHM.md` |

## Sidebar Tabs
1. **Overview** — Donut chart (interactive hover), storage breakdown, stat cards
2. **Smart Care** — Terminal scanner → Review → Clean → Complete
3. **Junks** — Category cards, file list with checkboxes
4. **Uninstaller** — App table with search, real categories, last active
5. **Preferences** — Settings panel

## Safety Rules
- All deletions use `FileManager.default.trashItem` (never permanent delete)
- Concurrency: ViewModels are `@MainActor @Observable`; models are `@unchecked Sendable`
- Scan cap: 5,000 items per location

## Current State (Post Phase 2 + Smart Care Polish)
- Advanced scanning algorithms implemented with real usage data
- Junk files scored by age × size × category × orphan weight
- App bundles get real categories, last-used dates, 32-bit/background/AppStore flags
- Orphaned support files detected via LaunchServices bundle ID cross-reference
- `knowledgeC.db` read dynamically for real app usage (with file-date fallback)

### Smart Care Flow
1. **Idle** — Large squircle icon, title, subtitle, Start button
2. **Scanning** — Terminal window (640×220) with live logs showing actual `[Int(progress*100)%]`
3. **Reviewing** — Three clickable category cards (System Junk / Unused Apps / Large Files) + Total Savings card
   - Cards hover with colored border + chevron indicator
   - Clicking a card navigates to a detail list with checkboxes
   - Back button returns to overview; Clean button starts cleanup
4. **Cleaning** — Progress ring with item count and space reclaimed
5. **Complete** — Checkmark animation with stats and "Scan Again" button

### Smart Care Detail Views
- **System Junk** — All `JunkFile` items with checkbox, path, size
- **Unused Apps** — Apps with `daysSinceUsed > 90`, checkbox, bundle ID, size, unused days
- **Large Files** — Apps with `totalSize > 500MB`, sorted by size descending
