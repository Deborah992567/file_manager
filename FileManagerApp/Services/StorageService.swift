import Foundation
import Observation

/// Storage accounting for the device usage bar and the breakdown screen.
///
/// Walks the sandbox tree once and buckets every byte by `FileCategory`
/// (Documents / Media / Downloads / Other). Also surfaces device capacity
/// and free space so the storage bar can render a real percentage.
@MainActor
@Observable
final class StorageService {

    static let shared = StorageService()

    struct CategoryUsage: Identifiable {
        let category: FileCategory
        let size: Int64
        var id: FileCategory { category }
    }

    struct Snapshot: Identifiable {
        let id = UUID()
        let totalUsed: Int64
        let totalCapacity: Int64
        let free: Int64
        let breakdown: [CategoryUsage]
        let itemCount: Int

        var usedFraction: Double {
            guard totalCapacity > 0 else { return 0 }
            return min(1, Double(totalUsed) / Double(totalCapacity))
        }
    }

    /// Lightweight device-level usage for the home storage bar.
    struct DeviceUsage {
        let used: Int64
        let free: Int64
        let capacity: Int64
    }

    /// Device-level used/free view (home screen storage bar).
    var deviceUsage: DeviceUsage? {
        guard let capacity = deviceCapacity() else { return nil }
        let free = deviceFree()
        return DeviceUsage(used: max(0, capacity - free), free: free, capacity: capacity)
    }

    private let fm = FileManager.default

    /// Percent of sandbox capacity currently used (0…1).
    func usageFraction() -> Double {
        let capacity = deviceCapacity() ?? 0
        guard capacity > 0 else { return 0 }
        return min(1, Double(max(0, capacity - deviceFree())) / Double(capacity))
    }

    /// Device-level view (what iOS Settings shows for the whole device use).
    private func fileSystemValues() -> [FileAttributeKey: Any]? {
        try? fm.attributesOfFileSystem(forPath: fm.temporaryDirectory.path)
    }

    private func deviceCapacity() -> Int64? {
        guard let values = fileSystemValues() else { return nil }
        return (values[.systemSize] as? NSNumber)?.int64Value
    }

    private func deviceFree() -> Int64 {
        guard let values = fileSystemValues() else { return 0 }
        return (values[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }

    /// Full sandbox scan: totals + category buckets inside the app.
    func snapshot(for root: URL) -> Snapshot {
        let capacity = deviceCapacity() ?? 0
        var counts: [FileCategory: Int64] = [:]
        var itemCount = 0

        var stack = [root]
        while !stack.isEmpty {
            let dir = stack.removeLast()
            guard let list = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in list {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    stack.append(url)
                    continue
                }
                itemCount += 1
                let size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                let kind = FileKind.kind(forExtension: url.pathExtension)
                counts[kind.category, default: 0] += size
            }
        }

        let breakdown = FileCategory.allCases.map {
            CategoryUsage(category: $0, size: counts[$0] ?? 0)
        }
        let used = breakdown.reduce(Int64(0)) { $0 + $1.size }
        return Snapshot(
            totalUsed: used,
            totalCapacity: capacity,
            free: max(0, capacity - used),
            breakdown: breakdown,
            itemCount: itemCount
        )
    }

    /// Space occupied by a single file/folder (for per-item info).
    func size(of url: URL) -> Int64 {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDir else {
            return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        var total: Int64 = 0
        var stack = [url]
        while !stack.isEmpty {
            let dir = stack.removeLast()
            guard let list = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for child in list {
                if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
                    stack.append(child)
                } else {
                    total += Int64((try? child.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
            }
        }
        return total
    }
}