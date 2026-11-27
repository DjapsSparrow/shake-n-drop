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
            title: "Nouvelle étagère (\(engine.shortcut.displayLabel))",
            action: #selector(createShelf),
            keyEquivalent: ""
        )
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
                item.target = self
                item.representedObject = shelf.id
                menu.addItem(item)
            }

            let toggleHide = NSMenuItem(
                title: engine.shelvesHidden ? "Afficher les étagères" : "Masquer toutes les étagères",
                action: #selector(toggleHideShelves),
                keyEquivalent: ""
            )
            toggleHide.target = self
            menu.addItem(toggleHide)

            let closeAll = NSMenuItem(title: "Fermer toutes les étagères", action: #selector(closeAllShelves), keyEquivalent: "")
            closeAll.target = self
            menu.addItem(closeAll)
        }

        menu.addItem(.separator())

        let shakeToggle = NSMenuItem(
            title: "Secouer pour ouvrir (Shake)",
            action: #selector(toggleShake),
            keyEquivalent: ""
        )
        shakeToggle.target = self
        shakeToggle.state = engine.shakeEnabled ? .on : .off
        menu.addItem(shakeToggle)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quitter Shake'n'Drop", action: #selector(quitApp), keyEquivalent: "q")
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

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Dessine le picto monochrome template 18×18 assorti à l'icône Liquid Glass de Shake'n'Drop :
    /// pile de cartes en éventail + berceau d'étagère en U arrondi.
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)

            // 1. Cartes arrière en éventail (opacité légère pour la profondeur en template)
            ctx.saveGState()
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)

            // Carte gauche inclinée (-15°)
            ctx.saveGState()
            ctx.translateBy(x: 6.8, y: 6.2)
            ctx.rotate(by: -15 * .pi / 180)
            let leftCard = CGPath(roundedRect: CGRect(x: -3.2, y: -3.4, width: 6.4, height: 6.8), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil)
            ctx.addPath(leftCard)
            ctx.fillPath()
            ctx.restoreGState()

            // Carte droite inclinée (+15°)
            ctx.saveGState()
            ctx.translateBy(x: 11.2, y: 6.2)
            ctx.rotate(by: 15 * .pi / 180)
            let rightCard = CGPath(roundedRect: CGRect(x: -3.2, y: -3.4, width: 6.4, height: 6.8), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil)
            ctx.addPath(rightCard)
            ctx.fillPath()
            ctx.restoreGState()
            ctx.restoreGState()

            // 2. Carte centrale principale
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.82).cgColor)
            let centerCard = CGPath(roundedRect: CGRect(x: 5.4, y: 2.0, width: 7.2, height: 6.8), cornerWidth: 1.6, cornerHeight: 1.6, transform: nil)
            ctx.addPath(centerCard)
            ctx.fillPath()

            // 3. Berceau d'étagère en U arrondi devant (silhouette identique à front.svg)
            ctx.setFillColor(NSColor.black.cgColor)
            let tray = CGMutablePath()
            tray.move(to: CGPoint(x: 3.0, y: 9.6))
            tray.addLine(to: CGPoint(x: 5.7, y: 9.6))
            tray.addCurve(
                to: CGPoint(x: 9.0, y: 12.1),
                control1: CGPoint(x: 6.6, y: 9.6),
                control2: CGPoint(x: 7.4, y: 12.1)
            )
            tray.addCurve(
                to: CGPoint(x: 12.3, y: 9.6),
                control1: CGPoint(x: 10.6, y: 12.1),
                control2: CGPoint(x: 11.4, y: 9.6)
            )
            tray.addLine(to: CGPoint(x: 15.0, y: 9.6))
            tray.addQuadCurve(to: CGPoint(x: 16.0, y: 10.6), control: CGPoint(x: 16.0, y: 9.6))
            tray.addLine(to: CGPoint(x: 16.0, y: 13.4))
            tray.addQuadCurve(to: CGPoint(x: 13.4, y: 16.0), control: CGPoint(x: 16.0, y: 16.0))
            tray.addLine(to: CGPoint(x: 4.6, y: 16.0))
            tray.addQuadCurve(to: CGPoint(x: 2.0, y: 13.4), control: CGPoint(x: 2.0, y: 16.0))
            tray.addLine(to: CGPoint(x: 2.0, y: 10.6))
            tray.addQuadCurve(to: CGPoint(x: 3.0, y: 9.6), control: CGPoint(x: 2.0, y: 9.6))
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
        registerForDraggedTypes([.fileURL, .URL, .string, .png, .tiff])
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
