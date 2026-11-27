import AppKit
import Foundation
import WebodropKit

/// Surveille les glissements et clics système pour :
/// 1. Détecter le geste "Shake-to-trigger" (secouer le curseur pendant un drag)
/// 2. Détecter la fin d'un drag (`.leftMouseUp`) et les clics en dehors des étagères (`.leftMouseDown` / `.rightMouseDown`)
final class ShakeMonitor {
    var isEnabled: Bool = true
    var sensitivity: ShakeSensitivity = .medium {
        didSet { detector.sensitivity = sensitivity }
    }
    var onShakeDetected: ((NSPoint) -> Void)?
    var onGlobalMouseUp: (() -> Void)?
    var onGlobalClick: ((NSPoint) -> Void)?

    private var detector = ShakeDetector(sensitivity: .medium)
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp, .leftMouseDown, .rightMouseDown]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated {
                self?.handle(type: type, isGlobal: true)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated {
                self?.handle(type: type, isGlobal: false)
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

    private func handle(type: NSEvent.EventType, isGlobal: Bool) {
        switch type {
        case .leftMouseUp:
            detector.reset()
            onGlobalMouseUp?()

        case .leftMouseDown, .rightMouseDown:
            if isGlobal {
                onGlobalClick?(NSEvent.mouseLocation)
            }

        case .leftMouseDragged:
            guard isEnabled else { return }
            let location = NSEvent.mouseLocation
            let sample = CursorSample(
                x: Double(location.x),
                y: Double(location.y),
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            if detector.record(sample) {
                onShakeDetected?(location)
            }

        default:
            break
        }
    }
}
