import Darwin
import Foundation

/// Physical memory in use, as the memory strip shows it.
public struct MemoryStats: Sendable, Equatable {
    /// Installed physical memory, in bytes.
    public let total: Int64
    /// (active + wired + compressed) pages × page size, in bytes. Never more than `total`.
    public let used: Int64

    public init(total: Int64, used: Int64) {
        self.total = total
        self.used = used
    }

    /// Reads the current numbers from the kernel (`host_statistics64`), or nil if it fails.
    public static func current() -> MemoryStats? {
        let host = mach_host_self()
        // mach_host_self() hands out a send right each call; give it back.
        defer { mach_port_deallocate(mach_task_self_, host) }

        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }

        var info = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }

        let total = Int64(clamping: ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return nil }
        let pages = UInt64(info.active_count) + UInt64(info.wire_count)
            + UInt64(info.compressor_page_count)
        let used = Int64(clamping: pages &* UInt64(pageSize))
        return MemoryStats(total: total, used: min(used, total))
    }
}
