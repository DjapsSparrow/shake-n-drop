import AppKit
import Quartz
import SwiftUI

/// Panneau flottant non-activant (always-on-top) hébergeant une étagère Webodrop.
/// Supporte Quick Look natif (`Espace`) via `QLPreviewPanelDataSource`.
final class ShelfPanel: NSPanel, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let shelf: Shelf
    private weak var engine: WebodropEngine?
    private var quickLookIndex: Int = 0
    private var collapseTask: Task<Void, Never>?

    private static let dockedPillSize = NSSize(width: 40, height: 96)
    private var isUserDraggingWindow: Bool = false
    private var moveObserver: NSObjectProtocol?

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

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateNearestEdge()
            }
        }
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
        if shelf.isDockedCollapsed {
            return dockedPillSize
        }
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
        let midY = frame.midY
        let targetRect: NSRect
        if let edge = shelf.dockedEdge {
            targetRect = dockedFrame(for: edge, size: newSize, peeked: shelf.isEdgePeeked || shelf.isDropTargeted, centerY: midY)
        } else {
            let topY = frame.maxY
            let newOrigin = NSPoint(x: frame.origin.x, y: topY - newSize.height)
            targetRect = clampedToScreen(NSRect(origin: newOrigin, size: newSize))
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(targetRect, display: true)
        }
        contentView?.frame = NSRect(origin: .zero, size: newSize)
    }

    /// Met à jour `shelf.nearestEdge` selon que l'étagère se trouve dans la moitié gauche ou droite de l'écran.
    func updateNearestEdge() {
        let currentScreen = screen ?? NSScreen.main
        guard let visible = currentScreen?.visibleFrame else { return }
        let edge: DockEdge = frame.midX < visible.midX ? .left : .right
        if shelf.nearestEdge != edge {
            shelf.nearestEdge = edge
        }
    }

    /// Bouton dédié dans l'en-tête : range l'étagère sur le bord le plus proche, ou la détache si déjà rangée.
    func toggleDockToNearestEdge() {
        if let edge = shelf.dockedEdge {
            undockFromEdge(from: edge)
        } else {
            updateNearestEdge()
            collapseTask?.cancel()
            shelf.dockedEdge = shelf.nearestEdge
            shelf.isEdgePeeked = false
            animateToDockedFrame()
        }
    }

    /// Appelé juste avant `performDrag(with:)` : détache l'étagère si elle était rangée sur un bord.
    func handleWindowDragStarted() {
        isUserDraggingWindow = true
        collapseTask?.cancel()
        if let edge = shelf.dockedEdge {
            let wasCollapsed = shelf.isDockedCollapsed
            shelf.dockedEdge = nil
            shelf.isEdgePeeked = false
            if wasCollapsed {
                let fullSize = Self.targetSize(for: shelf, compact: engine?.compactMode ?? false)
                let rect = dockedFrame(for: edge, size: fullSize, peeked: true, centerY: frame.midY)
                setFrame(rect, display: true)
                contentView?.frame = NSRect(origin: .zero, size: fullSize)
            }
        }
    }

    /// Appelé juste après `performDrag(with:)` : met simplement à jour le côté le plus proche (aucun collage auto).
    func handleWindowDragFinished() {
        isUserDraggingWindow = false
        updateNearestEdge()
    }

    /// Détache explicitement une étagère du bord (clic sur la languette ou sur le bouton de l'en-tête).
    func undockFromEdge(from edge: DockEdge) {
        isUserDraggingWindow = false
        collapseTask?.cancel()
        shelf.dockedEdge = nil
        shelf.isEdgePeeked = false

        let fullSize = Self.targetSize(for: shelf, compact: engine?.compactMode ?? false)
        let currentScreen = screen ?? NSScreen.main
        let visible = currentScreen?.visibleFrame ?? frame
        let targetX: CGFloat = edge == .left
            ? visible.minX + 36
            : visible.maxX - fullSize.width - 36
        let targetY = min(max(frame.midY - fullSize.height * 0.5, visible.minY + 12), visible.maxY - fullSize.height - 12)
        let target = NSRect(origin: NSPoint(x: targetX, y: targetY), size: fullSize)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
        }
        contentView?.frame = NSRect(origin: .zero, size: fullSize)
        updateNearestEdge()
    }

    /// Fait ressortir ou replier une étagère aimantée au bord d'écran au survol de la souris / d'un drag.
    func setEdgePeeked(_ peeked: Bool) {
        guard shelf.dockedEdge != nil, !isUserDraggingWindow else { return }
        collapseTask?.cancel()

        if peeked {
            if !shelf.isEdgePeeked {
                shelf.isEdgePeeked = true
                animateToDockedFrame()
            }
        } else {
            collapseTask = Task {
                try? await Task.sleep(for: .seconds(0.32))
                guard !Task.isCancelled else { return }
                guard self.shelf.dockedEdge != nil, !self.isUserDraggingWindow, !self.shelf.isDropTargeted else { return }
                if self.frame.contains(NSEvent.mouseLocation) { return }
                self.shelf.isEdgePeeked = false
                self.animateToDockedFrame()
            }
        }
    }

    private func animateToDockedFrame() {
        guard let edge = shelf.dockedEdge else { return }
        let targetSize = Self.targetSize(for: shelf, compact: engine?.compactMode ?? false)
        let target = dockedFrame(
            for: edge,
            size: targetSize,
            peeked: shelf.isEdgePeeked || shelf.isDropTargeted,
            centerY: frame.midY
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
        }
        contentView?.frame = NSRect(origin: .zero, size: targetSize)
    }

    private func dockedFrame(for edge: DockEdge, size: NSSize, peeked: Bool, centerY: CGFloat) -> NSRect {
        let currentScreen = screen ?? NSScreen.main
        guard let visible = currentScreen?.visibleFrame else {
            return NSRect(origin: frame.origin, size: size)
        }
        let margin: CGFloat = 12
        let clampedY = min(max(centerY - size.height * 0.5, visible.minY + margin), visible.maxY - size.height - margin)
        let x: CGFloat
        switch edge {
        case .left:
            x = peeked ? visible.minX + 8 : visible.minX
        case .right:
            x = peeked ? visible.maxX - size.width - 8 : visible.maxX - size.width
        }
        return NSRect(origin: NSPoint(x: x, y: clampedY), size: size)
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
        updateNearestEdge()
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
