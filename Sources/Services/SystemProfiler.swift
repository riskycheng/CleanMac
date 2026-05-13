import Foundation
import Darwin

actor SystemProfiler {
    static let shared = SystemProfiler()
    
    func diskSpaceInfo() -> (total: Int64, free: Int64, used: Int64) {
        let url = URL(fileURLWithPath: "/")
        do {
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            return (total, free, total - free)
        } catch {
            return (0, 0, 0)
        }
    }
    
    func memoryInfo() -> (total: UInt64, used: UInt64) {
        var memSize: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &len, nil, 0)
        
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (memSize, 0)
        }
        
        var pageSizeValue: vm_size_t = 0
        _ = withUnsafeMutablePointer(to: &pageSizeValue) {
            host_page_size(hostPort, $0)
        }
        
        let used = (UInt64(vmStats.active_count) + UInt64(vmStats.inactive_count) + UInt64(vmStats.wire_count)) * UInt64(pageSizeValue)
        
        return (memSize, used)
    }
    
    func bootTime() -> Date? {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        let result = sysctlbyname("kern.boottime", &tv, &size, nil, 0)
        guard result == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }
}
