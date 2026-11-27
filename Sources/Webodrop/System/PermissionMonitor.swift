import AppKit
import ApplicationServices
import Foundation

/// Surveille l'état de l'autorisation Accessibilité (utile si macOS restreint le suivi global de souris).
@Observable
final class PermissionMonitor {
    private(set) var accessibilityGranted: Bool = AXIsProcessTrusted()
    @ObservationIgnored private var timer: Timer?

    func startMonitoring() {
        refresh()
        timer?.invalidate()
        let interval: TimeInterval = accessibilityGranted ? 20.0 : 2.0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted {
            accessibilityGranted = granted
            startMonitoring()
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
