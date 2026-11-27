import Carbon.HIToolbox
import Foundation
import WebodropKit

/// Enregistre un raccourci clavier global via Carbon `RegisterEventHotKey` (aucune permission requise).
final class GlobalHotkey {
    private static weak var activeInstance: GlobalHotkey?

    var onTriggered: (() -> Void)?
    private(set) var isRegistered: Bool = false
    private(set) var statusMessage: String = "Inactif"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init() {
        GlobalHotkey.activeInstance = self
    }

    func register(_ config: ShortcutConfig) {
        unregister()

        if eventHandlerRef == nil {
            var spec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                GlobalHotkey.carbonHandler,
                1,
                &spec,
                nil,
                &eventHandlerRef
            )
        }

        let id = EventHotKeyID(signature: OSType(0x57445250), id: 1) // 'WDRP'
        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            isRegistered = true
            statusMessage = "Actif (\(config.displayLabel))"
        } else {
            isRegistered = false
            statusMessage = "Conflit avec une autre app (code \(status))"
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        isRegistered = false
    }

    nonisolated private static let carbonHandler: EventHandlerUPP = { _, event, _ in
        var hk = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hk
        )
        if status == noErr, hk.id == 1 {
            Task { @MainActor in
                GlobalHotkey.activeInstance?.onTriggered?()
            }
        }
        return noErr
    }
}
