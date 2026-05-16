import Foundation
import CryptoKit

/// 3-stage duplicate detection engine inspired by Lume.
///
/// Pipeline:
///   100,000 files
///     → Stage 1: Group by size        [instant metadata, 0 I/O]      → ~5,000
///     → Stage 2: Sample hash          [parallel, 16KB read each]     → ~200
///     → Stage 3: Full SHA-256         [parallel, 256KB buffer]       → ~50 true duplicates
enum DuplicateScanner {
    
    /// Minimum file size to consider for duplicate detection.
    /// Files smaller than this are skipped (too much overhead for tiny files).
    static let minSizeBytes: Int64 = 4_096 // 4 KB
    
    /// Number of concurrent hash workers.
    static let maxConcurrentHashers = 8
    
    /// Sample size for Stage 2 (head + tail = 2 × sampleSize).
    static let sampleSize = 8_192 // 8 KB
    
    /// I/O buffer size for Stage 3 full hashing.
    static let fullHashBufferSize = 262_144 // 256 KB
    
    // MARK: - Main Scan
    
    static func scan(
        in directory: URL? = nil,
        progress: ((ScanProgress) -> Void)? = nil
    ) async -> [DuplicateGroup] {
        let home = directory ?? PathConstants.home
        
        // Stage 1: Collect file metadata and group by size
        let sizeGroups = await stage1CollectFiles(in: home, progress: progress)
        
        // Filter to sizes with 2+ files
        let candidates = sizeGroups.filter { $0.value.count >= 2 }
        
        // Stage 2: Sample hash (head + tail)
        let sampleCollisions = await stage2SampleHash(
            candidates: candidates,
            progress: progress
        )
        
        // Stage 3: Full SHA-256 for sample collisions only
        let duplicateGroups = await stage3FullHash(
            collisions: sampleCollisions,
            progress: progress
        )
        
        return duplicateGroups.sorted { $0.totalWastedSpace > $1.totalWastedSpace }
    }
    
    // MARK: - Stage 1: Size-Based Grouping
    
    private static func stage1CollectFiles(
        in directory: URL,
        progress: ((ScanProgress) -> Void)?
    ) async -> [Int64: [URL]] {
        let fm = FileManager.default
        var sizeGroups: [Int64: [URL]] = [:]
        var fileCount = 0
        
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
        ]
        
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [:] }
        
        // Skip directories that are unlikely to contain user duplicates
        let skipNames: Set<String> = [
            ".git", "node_modules", ".cache", "DerivedData",
            ".build", "Pods", ".Trash", ".npm", ".yarn",
            ".pnpm-store", ".cargo", ".rustup", ".gradle",
            ".docker", ".vscode", ".idea",
        ]
        
        var checkCount = 0
        while let next = enumerator.nextObject() {
            checkCount += 1
            if checkCount % 200 == 0 && Task.isCancelled { break }
            guard let fileURL = next as? URL else { continue }
            
            if skipNames.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true || values.isDirectory == true { continue }
            
            let size = Int64(values.fileSize ?? 0)
            guard size >= minSizeBytes else { continue }
            
            sizeGroups[size, default: []].append(fileURL)
            fileCount += 1
            
            if fileCount % 500 == 0 {
                progress?(ScanProgress(
                    deltaFiles: 500,
                    deltaBytes: 0,
                    currentPath: fileURL.lastPathComponent,
                    category: "Duplicates Stage 1"
                ))
            }
        }
        
        return sizeGroups
    }
    
    // MARK: - Stage 2: Sample Hashing
    
    private static func stage2SampleHash(
        candidates: [Int64: [URL]],
        progress: ((ScanProgress) -> Void)?
    ) async -> [String: [URL]] {
        // Flatten all multi-file size groups into a single candidate list
        var allCandidates: [(url: URL, size: Int64)] = []
        for (size, urls) in candidates {
            for url in urls {
                allCandidates.append((url, size))
            }
        }
        
        // Parallel sample hashing
        let results = await withTaskGroup(of: (url: URL, hash: String).self) { group in
            var active = 0
            var collected: [(url: URL, hash: String)] = []
            var iterator = allCandidates.makeIterator()
            
            // Launch up to maxConcurrentHashers at a time
            while active < maxConcurrentHashers {
                guard let candidate = iterator.next() else { break }
                group.addTask {
                    let hash = await sampleHash(of: candidate.url, size: candidate.size)
                    return (candidate.url, hash)
                }
                active += 1
            }
            
            for await result in group {
                collected.append(result)
                active -= 1
                
                // Launch next worker
                if let candidate = iterator.next() {
                    group.addTask {
                        let hash = await sampleHash(of: candidate.url, size: candidate.size)
                        return (candidate.url, hash)
                    }
                    active += 1
                }
            }
            
            return collected
        }
        
        // Group by sample hash
        var hashGroups: [String: [URL]] = [:]
        for (url, hash) in results {
            hashGroups[hash, default: []].append(url)
        }
        
        // Only return groups with 2+ files
        return hashGroups.filter { $0.value.count >= 2 }
    }
    
    private static func sampleHash(of url: URL, size: Int64) async -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ""
        }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        
        // Read head
        if let head = try? handle.read(upToCount: sampleSize), !head.isEmpty {
            hasher.update(data: head)
        }
        
        // Read tail (if file is larger than 2× sample size)
        if size > Int64(sampleSize * 2) {
            let tailOffset = max(0, size - Int64(sampleSize))
            try? handle.seek(toOffset: UInt64(tailOffset))
            if let tail = try? handle.read(upToCount: sampleSize), !tail.isEmpty {
                hasher.update(data: tail)
            }
        }
        
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Stage 3: Full Hashing
    
    private static func stage3FullHash(
        collisions: [String: [URL]],
        progress: ((ScanProgress) -> Void)?
    ) async -> [DuplicateGroup] {
        // Flatten all sample collisions into full-hash candidates
        var allCandidates: [(url: URL, size: Int64)] = []
        for (_, urls) in collisions {
            for url in urls {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                allCandidates.append((url, size))
            }
        }
        
        // Parallel full hashing
        let results = await withTaskGroup(of: (url: URL, size: Int64, hash: String).self) { group in
            var active = 0
            var collected: [(url: URL, size: Int64, hash: String)] = []
            var iterator = allCandidates.makeIterator()
            
            while active < maxConcurrentHashers {
                guard let candidate = iterator.next() else { break }
                group.addTask {
                    let hash = await fullHash(of: candidate.url)
                    return (candidate.url, candidate.size, hash)
                }
                active += 1
            }
            
            for await result in group {
                collected.append(result)
                active -= 1
                
                if let candidate = iterator.next() {
                    group.addTask {
                        let hash = await fullHash(of: candidate.url)
                        return (candidate.url, candidate.size, hash)
                    }
                    active += 1
                }
            }
            
            return collected
        }
        
        // Group by full hash
        var hashGroups: [String: [(url: URL, size: Int64)]] = [:]
        for (url, size, hash) in results {
            hashGroups[hash, default: []].append((url, size))
        }
        
        // Build DuplicateGroup objects
        var groups: [DuplicateGroup] = []
        for (hash, items) in hashGroups where items.count >= 2 {
            let size = items.first?.size ?? 0
            let files = items.map { DuplicateFile(url: $0.url, size: $0.size) }
            groups.append(DuplicateGroup(hash: hash, size: size, files: files))
        }
        
        return groups
    }
    
    private static func fullHash(of url: URL) async -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ""
        }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        
        while true {
            guard let chunk = try? handle.read(upToCount: fullHashBufferSize) else { break }
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
