import Foundation
import Network

/// Whether the phone has a network path right now. Asked once, just before planning.
enum Connectivity {
    static func isOnline() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let once = Once()
            monitor.pathUpdateHandler = { path in
                guard once.claim() else { return }
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue(label: "ginkgo.connectivity"))
        }
    }
}

/// True the first time only, so a continuation is resumed exactly once.
final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
