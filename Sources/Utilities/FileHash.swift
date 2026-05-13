import Foundation
import CryptoKit

enum FileHash {
    static func md5(for url: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        
        var md5 = Insecure.MD5()
        
        while let data = try? handle.read(upToCount: 65536), !data.isEmpty {
            md5.update(data: data)
        }
        
        let digest = md5.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func quickHash(for url: URL) async throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int64 ?? 0
        let modDate = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)_\(modDate)_\(url.lastPathComponent)"
    }
}
