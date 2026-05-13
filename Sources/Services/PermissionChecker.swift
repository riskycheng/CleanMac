import Foundation

enum PermissionChecker {
    static func hasFullDiskAccess() -> Bool {
        let testURL = PathConstants.caches
        do {
            _ = try FileManager.default.contentsOfDirectory(at: testURL, includingPropertiesForKeys: nil)
            return true
        } catch {
            return false
        }
    }
    
    @MainActor
    static func requestFolderAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "CleanMac needs access to your home folder to scan for junk files."
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url
    }
}

import AppKit
