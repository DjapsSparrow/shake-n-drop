import AppKit
import Foundation
import WebodropKit

/// Surveille les glissements de souris système pour détecter le geste "Shake-to-trigger"
/// (secouer le curseur pendant un drag) façon Dropover.
final class ShakeMonitor {
    var isEnabled: Bool = true
    var sensitivity: ShakeSensitivity = .medium {
        didSet { detector.sensitivity = sensitivity }
    }
    var onShakeDetected: ((NSPoint) -> Void)?

    private var detector = ShakeDetector(sensitivity: .medium)
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard isEnabled else { return }

        if event.type == .leftMouseUp {
            detector.reset()
            return
        }

        let location = NSEvent.mouseLocation
        let sample = CursorSample(
            x: Double(location.x),
            y: Double(location.y),
            timestamp: ProcessInfo.processInfo.systemUptime
        )

        if detector.record(sample) {
            onShakeDetected?(location)
        }
    }
}
