import Foundation

/// Fast large file tracer inspired by MacSift and Lume.
/// Walks the home directory with streaming enumeration, skipping known
/// directory patterns, and returns files above a size threshold sorted
/// by allocated size descending.
enum LargeFileScanner {
    
    /// Minimum file size threshold (default 10 MB).
    static let defaultThresholdBytes: Int64 = 10 * 1_048_576
    
    /// Directory names to skip entirely (exact match).
    private static let skipNames: Set<String> = [
        "node_modules", ".git", ".cache", "Pods", "DerivedData",
        ".build", ".next", ".nuxt", "venv", ".venv", "__pycache__",
        ".Trash", ".npm", ".pnpm-store", ".yarn", ".cargo", ".rustup",
        ".gradle", ".docker", ".vscode", ".idea", ".DS_Store",
    ]
    
    /// Path prefixes to skip (relative to home).
    private static let skipPrefixes = [
        "Library/", ".Trash/", "Downloads/",
        "node_modules/", ".git/", ".cache/", "Pods/", "DerivedData/",
        ".build/", ".next/", ".nuxt/", "venv/", ".venv/", "__pycache__/",
        ".npm/", ".pnpm-store/", ".yarn/", ".cargo/", ".rustup/",
        ".gradle/", ".docker/", ".vscode/", ".idea/",
        "go/pkg/mod/",
    ]
    
    // MARK: - Main Scan
    
    static func scan(
        thresholdBytes: Int64 = defaultThresholdBytes,
        homeDirectory: URL? = nil
    ) async -> [LargeFile] {
        let home = homeDirectory ?? PathConstants.home
        let fm = FileManager.default
        let homePath = home.path(percentEncoded: false)
        let homePrefix = homePath.hasSuffix("/") ? homePath : homePath + "/"
        
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
            .attributeModificationDateKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
        ]
        
        guard let enumerator = fm.enumerator(
            at: home,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        
        var files: [LargeFile] = []
        var checkCount = 0
        
        while let next = enumerator.nextObject() {
            checkCount += 1
            if checkCount % 200 == 0 && Task.isCancelled { break }
            guard let fileURL = next as? URL else { continue }
            
            let filePath = fileURL.path(percentEncoded: false)
            let relativePath = filePath.hasPrefix(homePrefix)
                ? String(filePath.dropFirst(homePrefix.count))
                : filePath
            
            // Skip by directory name
            let lastComponent = fileURL.lastPathComponent
            if skipNames.contains(lastComponent) {
                enumerator.skipDescendants()
                continue
            }
            
            // Skip by path prefix
            if skipPrefixes.contains(where: { relativePath.hasPrefix($0) }) {
                enumerator.skipDescendants()
                continue
            }
            
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            
            if values.isSymbolicLink == true || values.isDirectory == true { continue }
            
            let logicalSize = Int64(values.fileSize ?? 0)
            let allocatedSizeRaw = values.totalFileAllocatedSize ?? Int(values.fileSize ?? 0)
            let allocatedSize = Int64(allocatedSizeRaw)
            
            // Size pre-filter — skip files below threshold at metadata level
            guard allocatedSize >= thresholdBytes else { continue }
            
            // Access date: prefer attribute modification date (closest proxy on APFS)
            let accessDate = values.attributeModificationDate
            let modDate = values.contentModificationDate
            
            files.append(LargeFile(
                url: fileURL,
                size: logicalSize,
                allocatedSize: allocatedSize,
                accessDate: accessDate,
                modificationDate: modDate
            ))
            
            if files.count >= 2000 { break }
        }
        
        return files.sorted { $0.allocatedSize > $1.allocatedSize }
    }
    
    // MARK: - Access Time Buckets
    
    struct Bucket {
        let label: String
        let color: String
        let count: Int
        let totalSize: Int64
    }
    
    static func accessTimeBuckets(_ files: [LargeFile]) -> [Bucket] {
        let buckets = [
            ("Hot",    "EF4444", 0..<7),
            ("Warm",   "F97316", 7..<30),
            ("Cold",   "F59E0B", 30..<90),
            ("Frozen", "3B82F6", 90..<365),
            ("Zombie", "8B5CF6", 365..<Double.infinity),
        ]
        
        return buckets.map { label, color, range in
            let matched = files.filter { file in
                guard let days = file.daysSinceAccess else { return false }
                return range.contains(days)
            }
            return Bucket(
                label: label,
                color: color,
                count: matched.count,
                totalSize: matched.reduce(0) { $0 + $1.allocatedSize }
            )
        }
    }
}
