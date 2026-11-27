import AppKit
import Quartz
import SwiftUI

/// Panneau flottant non-activant (always-on-top) hébergeant une étagère Webodrop.
/// Supporte Quick Look natif (`Espace`) via `QLPreviewPanelDataSource`.
final class ShelfPanel: NSPanel, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let shelf: Shelf
    private weak var engine: WebodropEngine?
    private var quickLookIndex: Int = 0

    init(shelf: Shelf, engine: WebodropEngine, compact: Bool) {
        self.shelf = shelf
        self.engine = engine
        let initialSize = Self.targetSize(for: shelf, compact: compact)

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow

        let rootView = ShelfView(shelf: shelf, engine: engine)
            .themed()
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: initialSize)
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        if shelf.items.isEmpty {
            engine?.closeShelf(shelf)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Touche Espace (keyCode 49) : bascule Quick Look natif sur les éléments de l'étagère.
        if event.keyCode == 49, !shelf.items.isEmpty {
            toggleQuickLook()
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Placement & Redimensionnement

    static func targetSize(for shelf: Shelf, compact: Bool) -> NSSize {
        let baseWidth: CGFloat = compact ? 188 : 212
        if shelf.items.isEmpty {
            return NSSize(width: baseWidth, height: compact ? 176 : 196)
        }
        if shelf.isExpanded {
            let rowCount = min(max(shelf.items.count, 1), 6)
            let listHeight = CGFloat(rowCount) * 44 + 124
            return NSSize(width: max(baseWidth + 56, 268), height: min(max(listHeight, 232), 420))
        }
        return NSSize(width: baseWidth, height: compact ? 204 : 224)
    }

    func updateSize(for shelf: Shelf, compact: Bool) {
        let newSize = Self.targetSize(for: shelf, compact: compact)
        guard frame.size != newSize else { return }
        // Garde le bord supérieur fixe lors du déploiement vers le bas.
        let topY = frame.maxY
        let newOrigin = NSPoint(x: frame.origin.x, y: topY - newSize.height)
        let targetRect = clampedToScreen(NSRect(origin: newOrigin, size: newSize))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(targetRect, display: true)
        }
        contentView?.frame = NSRect(origin: .zero, size: newSize)
    }

    func position(near cursorPoint: NSPoint, offsetIndex: Int = 0) {
        let size = frame.size
        // Place l'étagère légèrement à droite et centrée verticalement par rapport au curseur.
        let cascade = CGFloat(offsetIndex % 5) * 24
        let rawOrigin = NSPoint(
            x: cursorPoint.x + 28 + cascade,
            y: cursorPoint.y - size.height * 0.5 - cascade
        )
        let rect = clampedToScreen(NSRect(origin: rawOrigin, size: size))
        setFrame(rect, display: true)
    }

    private func clampedToScreen(_ rect: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return rect }
        let margin: CGFloat = 12
        var origin = rect.origin
        origin.x = min(max(origin.x, visible.minX + margin), visible.maxX - rect.width - margin)
        origin.y = min(max(origin.y, visible.minY + margin), visible.maxY - rect.height - margin)
        return NSRect(origin: origin, size: rect.size)
    }

    // MARK: - Quick Look natif (QLPreviewPanel)

    func showQuickLook(startingAt index: Int = 0) {
        guard !shelf.items.isEmpty else { return }
        quickLookIndex = min(max(index, 0), shelf.items.count - 1)
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        guard let ql = QLPreviewPanel.shared() else { return }
        ql.updateController()
        ql.currentPreviewItemIndex = quickLookIndex
        ql.reloadData()
        ql.makeKeyAndOrderFront(nil)
    }

    func toggleQuickLook() {
        guard let ql = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), ql.isVisible {
            ql.orderOut(nil)
        } else {
            showQuickLook(startingAt: 0)
        }
    }

    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated {
            !shelf.items.isEmpty
        }
    }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = self
            panel.delegate = self
        }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
        }
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            shelf.items.count
        }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        let url: URL? = MainActor.assumeIsolated {
            guard shelf.items.indices.contains(index) else { return nil }
            return shelf.items[index].fileURL
        }
        return url as NSURL?
    }
}
