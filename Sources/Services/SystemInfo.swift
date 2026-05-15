import Foundation
import Darwin

enum SystemInfo {
    struct DiskInfo {
        let total: Int64
        let free: Int64
        let used: Int64
        var usedPercentage: Double { Double(used) / Double(max(total, 1)) }
    }
    
    struct MemoryInfo {
        let total: UInt64
        let used: UInt64
        let free: UInt64
        var usedPercentage: Double { Double(used) / Double(max(total, 1)) }
    }
    
    struct CPUInfo {
        let usagePercentage: Double
        let coreCount: Int
    }
    
    static func diskInfo() -> DiskInfo? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else {
            return nil
        }
        guard let total = attrs[.systemSize] as? Int64,
              let free = attrs[.systemFreeSize] as? Int64 else {
            return nil
        }
        return DiskInfo(total: total, free: free, used: total - free)
    }
    
    static func memoryInfo() -> MemoryInfo? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { boundPtr in
                host_statistics64(host, HOST_VM_INFO64, boundPtr, &count)
            }
        }
        mach_port_deallocate(mach_task_self_, host)
        
        guard result == KERN_SUCCESS else { return nil }
        
        let pageSize = UInt64(getpagesize())
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let used = active + inactive + wired
        
        var totalMem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)
        
        return MemoryInfo(total: totalMem, used: used, free: free)
    }
    
    static func cpuInfo() -> CPUInfo? {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &loadInfo) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { boundPtr in
                host_statistics(host, HOST_CPU_LOAD_INFO, boundPtr, &count)
            }
        }
        mach_port_deallocate(mach_task_self_, host)
        
        guard result == KERN_SUCCESS else { return nil }
        
        let totalTicks = loadInfo.cpu_ticks.0 + loadInfo.cpu_ticks.1 + loadInfo.cpu_ticks.2 + loadInfo.cpu_ticks.3
        let idleTicks = loadInfo.cpu_ticks.3
        let usage = totalTicks > 0 ? Double(totalTicks - idleTicks) / Double(totalTicks) * 100 : 0
        
        var coreCount: Int32 = 0
        var coreSize = MemoryLayout<Int32>.size
        sysctlbyname("hw.ncpu", &coreCount, &coreSize, nil, 0)
        
        return CPUInfo(usagePercentage: min(max(usage, 0), 100), coreCount: Int(coreCount))
    }
}
