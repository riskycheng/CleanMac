import Foundation
import AppKit

enum TrashManager {
    static func moveToTrash(urls: [URL]) async throws -> Int {
        var count = 0
        for url in urls {
            do {
                try await NSWorkspace.shared.recycle([url])
                count += 1
            } catch {
                print("Failed to trash \(url.path): \(error)")
            }
        }
        return count
    }
}
