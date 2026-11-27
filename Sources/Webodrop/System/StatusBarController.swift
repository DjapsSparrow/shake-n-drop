import AppKit
import Foundation
import WebodropKit

/// Contrôleur de l'icône de la barre de menu (`NSStatusItem`).
/// Supporte :
/// - Clic gauche/droit : menu natif rapide (Nouvelle étagère, étagères actives, Tout fermer, Réglages, Quitter)
/// - Drag & drop direct sur l'icône : crée instantanément une étagère remplie juste sous la barre de menu.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private weak var engine: WebodropEngine?
    private let menu = NSMenu()
    private var dropView: StatusBarDropView?

    init(engine: WebodropEngine) {
        self.engine = engine
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            let image = Self.makeMenuBarIcon()
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.toolTip = "Shake'n'Drop — Glissez des fichiers ici ou cliquez"

            let overlay = StatusBarDropView(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.onDropPasteboard = { [weak self] pasteboard in
                self?.handleDropOnMenuBar(pasteboard) ?? false
            }
            button.addSubview(overlay)
            self.dropView = overlay
        }

        refresh()
    }

    func refresh() {
        guard let button = statusItem.button, let engine else { return }
        let totalItems = engine.shelves.reduce(0) { $0 + $1.items.count }
        button.title = totalItems > 0 ? " \(totalItems)" : ""
    }

    private func handleDropOnMenuBar(_ pasteboard: NSPasteboard) -> Bool {
        guard let engine else { return false }
        let items = engine.extractItems(from: pasteboard)
        guard !items.isEmpty else { return false }
        let point = statusItem.button?.window?.frame.origin ?? NSEvent.mouseLocation
        let dropAnchor = NSPoint(x: point.x, y: point.y - 24)
        engine.summonShelf(near: dropAnchor, reuseEmpty: false, initialItems: items)
        return true
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let engine else { return }

        let newItem = NSMenuItem(
            title: "Nouvelle étagère",
            action: #selector(createShelf),
            keyEquivalent: Self.menuKeyEquivalent(for: engine.shortcut.keyCode)
        )
        newItem.keyEquivalentModifierMask = Self.menuModifierMask(for: engine.shortcut.modifiers)
        newItem.image = NSImage(systemSymbolName: "plus.square.on.square", accessibilityDescription: nil)
        newItem.target = self
        menu.addItem(newItem)

        if !engine.shelves.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: "Étagères actives (\(engine.shelves.count))", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for (index, shelf) in engine.shelves.enumerated() {
                let label = "Étagère \(index + 1) — \(shelf.summaryTitle)"
                let item = NSMenuItem(title: label, action: #selector(bringShelfForward(_:)), keyEquivalent: "")
                item.image = NSImage(systemSymbolName: "square.stack", accessibilityDescription: nil)
                item.target = self
                item.representedObject = shelf.id
                menu.addItem(item)
            }

            let toggleHide = NSMenuItem(
                title: engine.shelvesHidden ? "Afficher les étagères" : "Masquer les étagères",
                action: #selector(toggleHideShelves),
                keyEquivalent: ""
            )
            toggleHide.image = NSImage(systemSymbolName: engine.shelvesHidden ? "eye" : "eye.slash", accessibilityDescription: nil)
            toggleHide.target = self
            menu.addItem(toggleHide)

            let closeAll = NSMenuItem(title: "Tout fermer", action: #selector(closeAllShelves), keyEquivalent: "")
            closeAll.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
            closeAll.target = self
            menu.addItem(closeAll)
        }

        menu.addItem(.separator())

        let shakeToggle = NSMenuItem(
            title: "Secouer pour ouvrir",
            action: #selector(toggleShake),
            keyEquivalent: ""
        )
        shakeToggle.image = NSImage(systemSymbolName: "hand.wave", accessibilityDescription: nil)
        shakeToggle.target = self
        shakeToggle.state = engine.shakeEnabled ? .on : .off
        menu.addItem(shakeToggle)

        menu.addItem(.separator())

        if let update = engine.updater.availableUpdate {
            let updateItem = NSMenuItem(
                title: "Mettre à jour vers v\(update.version)…",
                action: #selector(checkForUpdates),
                keyEquivalent: ""
            )
            updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            updateItem.target = self
            menu.addItem(updateItem)
        }

        let settings = NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ",")
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settings.target = self
        menu.addItem(settings)

        let feedbackMenu = NSMenu()
        let suggestIdea = NSMenuItem(title: "Suggérer une idée…", action: #selector(sendIdea), keyEquivalent: "")
        suggestIdea.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil)
        suggestIdea.target = self
        feedbackMenu.addItem(suggestIdea)
        let reportBug = NSMenuItem(title: "Signaler un bug…", action: #selector(reportBug), keyEquivalent: "")
        reportBug.image = NSImage(systemSymbolName: "ladybug", accessibilityDescription: nil)
        reportBug.target = self
        feedbackMenu.addItem(reportBug)

        let feedbackItem = NSMenuItem(title: "Idée ou bug ?", action: nil, keyEquivalent: "")
        feedbackItem.image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right", accessibilityDescription: nil)
        feedbackItem.submenu = feedbackMenu
        menu.addItem(feedbackItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quitter Shake'n'Drop", action: #selector(quitApp), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func createShelf() {
        engine?.summonShelfNearCursor(reuseEmpty: false)
    }

    @objc private func bringShelfForward(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let panel = engine?.panels[id] else { return }
        panel.orderFrontRegardless()
    }

    @objc private func toggleHideShelves() {
        engine?.toggleHideAllShelves()
    }

    @objc private func closeAllShelves() {
        engine?.closeAllShelves()
    }

    @objc private func toggleShake() {
        engine?.shakeEnabled.toggle()
    }

    @objc private func openSettings() {
        engine?.openSettings()
    }

    @objc private func openOnboarding() {
        engine?.openOnboarding()
    }

    @objc private func sendIdea() {
        engine?.openFeedback(initialKind: .idea)
    }

    @objc private func reportBug() {
        engine?.openFeedback(initialKind: .bug)
    }

    @objc private func checkForUpdates() {
        guard let updater = engine?.updater else { return }
        if let available = updater.availableUpdate {
            updater.promptToInstall(available)
        } else {
            Task {
                await updater.checkForUpdates(interactive: true)
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func menuKeyEquivalent(for keyCode: UInt32) -> String {
        switch keyCode {
        case 2: "d"
        case 1: "s"
        case 49: " "
        default: ""
        }
    }

    private static func menuModifierMask(for carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if (carbonModifiers & 2048) != 0 { flags.insert(.option) }
        if (carbonModifiers & 512) != 0 { flags.insert(.shift) }
        if (carbonModifiers & 4096) != 0 { flags.insert(.control) }
        if (carbonModifiers & 256) != 0 { flags.insert(.command) }
        return flags
    }

    /// Dessine le picto monochrome template 18×18 assorti à l'icône Liquid Glass de Shake'n'Drop :
    /// contour fin aéré + pile de cartes en éventail + berceau d'étagère net.
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)

            // 1. Cartes arrière en éventail (légères, bien séparées du berceau)
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(1.25)

            ctx.saveGState()
            ctx.translateBy(x: 6.4, y: 5.8)
            ctx.rotate(by: -15 * .pi / 180)
            ctx.addPath(CGPath(roundedRect: CGRect(x: -2.6, y: -3.0, width: 5.2, height: 5.6), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
            ctx.strokePath()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.translateBy(x: 11.6, y: 5.8)
            ctx.rotate(by: 15 * .pi / 180)
            ctx.addPath(CGPath(roundedRect: CGRect(x: -2.6, y: -3.0, width: 5.2, height: 5.6), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
            ctx.strokePath()
            ctx.restoreGState()
            ctx.restoreGState()

            // 2. Carte centrale nette (remplissage doux + contour propre)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
            let centerCard = CGPath(roundedRect: CGRect(x: 5.7, y: 2.0, width: 6.6, height: 6.0), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil)
            ctx.addPath(centerCard)
            ctx.fillPath()

            // 3. Berceau d'étagère en U arrondi en bas (aéré avec un espace net de 1.8 pt)
            ctx.setFillColor(NSColor.black.cgColor)
            let tray = CGMutablePath()
            tray.move(to: CGPoint(x: 2.9, y: 9.8))
            tray.addLine(to: CGPoint(x: 5.8, y: 9.8))
            tray.addCurve(
                to: CGPoint(x: 9.0, y: 12.1),
                control1: CGPoint(x: 6.6, y: 9.8),
                control2: CGPoint(x: 7.4, y: 12.1)
            )
            tray.addCurve(
                to: CGPoint(x: 12.2, y: 9.8),
                control1: CGPoint(x: 10.6, y: 12.1),
                control2: CGPoint(x: 11.4, y: 9.8)
            )
            tray.addLine(to: CGPoint(x: 15.1, y: 9.8))
            tray.addQuadCurve(to: CGPoint(x: 16.0, y: 10.7), control: CGPoint(x: 16.0, y: 9.8))
            tray.addLine(to: CGPoint(x: 16.0, y: 13.6))
            tray.addQuadCurve(to: CGPoint(x: 13.6, y: 16.0), control: CGPoint(x: 16.0, y: 16.0))
            tray.addLine(to: CGPoint(x: 4.4, y: 16.0))
            tray.addQuadCurve(to: CGPoint(x: 2.0, y: 13.6), control: CGPoint(x: 2.0, y: 16.0))
            tray.addLine(to: CGPoint(x: 2.0, y: 10.7))
            tray.addQuadCurve(to: CGPoint(x: 2.9, y: 9.8), control: CGPoint(x: 2.0, y: 9.8))
            tray.closeSubpath()
            ctx.addPath(tray)
            ctx.fillPath()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Shake'n'Drop"
        return image
    }
}

/// Vue transparente superposée au bouton de barre de menu pour accepter le drag & drop.
private final class StatusBarDropView: NSView {
    var onDropPasteboard: ((NSPasteboard) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("public.url"), .string, .png, .tiff])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Laisse passer tous les clics normaux au bouton sous-jacent.
        nil
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDropPasteboard?(sender.draggingPasteboard) ?? false
    }
}
