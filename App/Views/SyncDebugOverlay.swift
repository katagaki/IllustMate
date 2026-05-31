#if DEBUG
import SwiftUI

struct SyncDebugOverlay: View {

    var monitor = SyncDebugMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 1.0) {
            Text("iCloud \(monitor.account) · sync \(monitor.enabled ? "ON" : "off")")
                .fontWeight(.bold)
            ForEach(Array(monitor.events.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .font(.system(size: 9.0, design: .monospaced))
        .foregroundStyle(.green)
        .padding(6.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6.0))
        .padding(.horizontal, 8.0)
        .allowsHitTesting(false)
    }
}
#endif
