import AppKit
import SwiftUI

/// Zone de dépôt AppKit couvrant toute une étagère.
/// Garantit un drag-in fiable depuis Finder, Safari, Chrome, Aperçu, Notes, etc.
struct ShelfDropTargetView: NSViewRepresentable {
    let shelf: Shelf
    let engine: WebodropEngine

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        view.onTargetChanged = { targeted in
            shelf.isDropTargeted = targeted
        }
        view.onDropPasteboard = { pasteboard in
            engine.addPasteboard(pasteboard, to: shelf) > 0
        }
        return view
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.onTargetChanged = { targeted in
            shelf.isDropTargeted = targeted
        }
        nsView.onDropPasteboard = { pasteboard in
            engine.addPasteboard(pasteboard, to: shelf) > 0
        }
    }
}

final class DropReceiverNSView: NSView {
    var onTargetChanged: ((Bool) -> Void)?
    var onDropPasteboard: ((NSPasteboard) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("public.url"), .string, .png, .tiff])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Ne bloque jamais les clics sur les boutons SwiftUI dessous.
        nil
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        // Évite le drop d'une étagère sur elle-même.
        if let source = sender.draggingSource as? DragSourceNSView, source.window === self.window {
            return []
        }
        (window as? ShelfPanel)?.setEdgePeeked(true)
        onTargetChanged?(true)
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onTargetChanged?(false)
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        onTargetChanged?(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onTargetChanged?(false)
        return onDropPasteboard?(sender.draggingPasteboard) ?? false
    }
}

/// Zone transparente posée sur la pile (ou sur une ligne) pour lancer un vrai drag-out AppKit
/// (`NSDraggingSession`) multi-fichiers vers Finder, Mail, Slack, navigateur, etc.
struct ShelfDragSourceView: NSViewRepresentable {
    let items: [ShelfItem]
    let onDragCompleted: (NSDragOperation) -> Void
    var onSingleClick: (() -> Void)? = nil

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.items = items
        view.onDragCompleted = onDragCompleted
        view.onSingleClick = onSingleClick
        return view
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.items = items
        nsView.onDragCompleted = onDragCompleted
        nsView.onSingleClick = onSingleClick
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    var items: [ShelfItem] = []
    var onDragCompleted: ((NSDragOperation) -> Void)?
    var onSingleClick: (() -> Void)?

    private var mouseDownPoint: NSPoint?
    private var didStartDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDrag, !items.isEmpty, let start = mouseDownPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        let distance = hypot(current.x - start.x, current.y - start.y)
        guard distance > 4 else { return }

        didStartDrag = true
        beginMultiItemDrag(with: event, origin: current)
    }

    override func mouseUp(with event: NSEvent) {
        if !didStartDrag {
            onSingleClick?()
        }
        mouseDownPoint = nil
        didStartDrag = false
    }

    private func beginMultiItemDrag(with event: NSEvent, origin: NSPoint) {
        let draggingItems: [NSDraggingItem] = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.fileURL as NSURL)
            let thumb = item.thumbnail ?? NSWorkspace.shared.icon(forFile: item.fileURL.path)
            let size = NSSize(width: 56, height: 56)
            let offset = CGFloat(min(index, 4)) * 4
            let frame = NSRect(
                x: origin.x - size.width * 0.5 + offset,
                y: origin.y - size.height * 0.5 - offset,
                width: size.width,
                height: size.height
            )
            draggingItem.setDraggingFrame(frame, contents: thumb)
            return draggingItem
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.draggingFormation = .pile
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link] : [.copy]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragCompleted?(operation)
    }
}

/// Bouton AppKit discret permettant d'ancrer `NSSharingServicePicker` (AirDrop, Mail, Messages…)
/// exactement sous l'icône Partager.
struct SharePickerButton: NSViewRepresentable {
    let urls: [URL]
    let disabled: Bool

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Partager")
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.toolTip = "Partager (AirDrop, Mail, Messages…)"
        button.target = context.coordinator
        button.action = #selector(Coordinator.share(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.urls = urls
        nsView.isEnabled = !disabled && !urls.isEmpty
        nsView.alphaValue = nsView.isEnabled ? 1.0 : 0.35
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(urls: urls)
    }

    final class Coordinator: NSObject {
        var urls: [URL]
        init(urls: [URL]) { self.urls = urls }

        @MainActor @objc func share(_ sender: NSButton) {
            guard !urls.isEmpty else { return }
            let picker = NSSharingServicePicker(items: urls)
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

/// Poignée AppKit native qui déplace fluidement le `NSPanel` sans bordure via `window.performDrag(with:)`,
/// puis déclenche l'aimantation éventuelle au bord gauche/droit de l'écran à la fin du déplacement.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }

    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

final class WindowDragNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let panel = window as? ShelfPanel else {
            window?.performDrag(with: event)
            return
        }
        // Si l'étagère était repliée sur un bord, on la déploie d'abord pour la déplacer confortablement.
        if panel.shelf.dockedEdge != nil && !panel.shelf.isEdgePeeked {
            panel.setEdgePeeked(true)
        }
        panel.performDrag(with: event)
        panel.handleWindowDragFinished()
    }
}
