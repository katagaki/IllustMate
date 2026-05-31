#if DEBUG
import Foundation

@MainActor
@Observable
final class SyncDebugMonitor {

    static let shared = SyncDebugMonitor()

    var enabled: Bool = false
    var account: String = "—"
    private(set) var events: [String] = []

    func setAccount(_ value: String) {
        account = value
    }

    func log(_ message: String) {
        events.append("\(Self.formatter.string(from: Date())) \(message)")
        if events.count > 10 {
            events.removeFirst(events.count - 10)
        }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
#endif
