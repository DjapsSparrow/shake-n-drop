import AppKit
import Foundation
import QuickLookThumbnailing
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import WebodropKit

/// Un élément déposé sur une étagère Webodrop (fichier, dossier, image, lien ou texte).
@Observable
final class ShelfItem: Identifiable {
    let id: UUID
    let kind: ShelfItemKind
    let fileURL: URL
    let originalText: String?
    let originalWebURL: URL?
    let title: String
    let byteSize: Int64
    let isTemporaryFile: Bool
    var thumbnail: NSImage?

    init(
        id: UUID = UUID(),
        kind: ShelfItemKind,
        fileURL: URL,
        originalText: String? = nil,
        originalWebURL: URL? = nil,
        title: String,
        byteSize: Int64 = 0,
        isTemporaryFile: Bool = false,
        thumbnail: NSImage? = nil
    ) {
        self.id = id
        self.kind = kind
        self.fileURL = fileURL
        self.originalText = originalText
        self.originalWebURL = originalWebURL
        self.title = title
        self.byteSize = byteSize
        self.isTemporaryFile = isTemporaryFile
        self.thumbnail = thumbnail
    }

    var subtitle: String {
        switch kind {
        case .folder:
            return "Dossier"
        case .url:
            return originalWebURL?.host ?? "Lien web"
        case .text:
            return byteSize > 0 ? "Texte • \(ShelfFormatting.formattedByteSize(byteSize))" : "Extrait de texte"
        case .image:
            let size = ShelfFormatting.formattedByteSize(byteSize)
            return size.isEmpty ? "Image" : "Image • \(size)"
        case .file:
            let ext = fileURL.pathExtension.uppercased()
            let size = ShelfFormatting.formattedByteSize(byteSize)
            if !ext.isEmpty && !size.isEmpty { return "\(ext) • \(size)" }
            if !ext.isEmpty { return ext }
            return size.isEmpty ? "Fichier" : size
        }
    }
}

/// Bord d'écran sur lequel une étagère peut être aimantée/repliée.
enum DockEdge: String, Sendable {
    case left
    case right
}

/// Une étagère flottante temporaire.
@Observable
final class Shelf: Identifiable {
    let id: UUID
    var items: [ShelfItem] = []
    var isExpanded: Bool = false
    var isPinned: Bool = false
    var isDropTargeted: Bool = false
    var isBusy: Bool = false
    var statusMessage: String?
    var dockedEdge: DockEdge? = nil
    var isEdgePeeked: Bool = false
    var summonedByShake: Bool = false
    let createdAt: Date = .now

    init(id: UUID = UUID(), items: [ShelfItem] = [], summonedByShake: Bool = false) {
        self.id = id
        self.items = items
        self.summonedByShake = summonedByShake
    }

    /// True lorsque l'étagère est rangée en languette discrète contre le bord de l'écran.
    var isDockedCollapsed: Bool {
        dockedEdge != nil && !isEdgePeeked && !isDropTargeted
    }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + $1.byteSize }
    }

    var summaryTitle: String {
        if items.count == 1, let first = items.first {
            return first.title
        }
        return ShelfFormatting.itemCountLabel(items.count)
    }

    var summarySubtitle: String {
        if items.isEmpty {
            return "Glissez fichiers, images, liens ou textes"
        }
        if items.count == 1, let first = items.first {
            return first.subtitle
        }
        let sizeText = ShelfFormatting.formattedByteSize(totalBytes)
        return sizeText.isEmpty ? "Prêt à glisser en groupe" : sizeText
    }
}

/// Onglets de la fenêtre Réglages.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case shortcut
    case appearance

    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "Général"
        case .shortcut: "Raccourci"
        case .appearance: "Apparence"
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcut: "command"
        case .appearance: "paintbrush"
        }
    }
}

/// Moteur central de Webodrop : gère toutes les étagères, panneaux flottants, actions et réglages.
@Observable
final class WebodropEngine {
    static let shared = WebodropEngine()

    var shelves: [Shelf] = []
    var settingsTab: SettingsTab = .general

    // Réglages persistés
    var shakeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(shakeEnabled, forKey: Keys.shakeEnabled)
            shakeMonitor.isEnabled = shakeEnabled
        }
    }

    var shakeSensitivity: ShakeSensitivity {
        didSet {
            UserDefaults.standard.set(shakeSensitivity.rawValue, forKey: Keys.shakeSensitivity)
            shakeMonitor.sensitivity = shakeSensitivity
        }
    }

    var autoCloseAfterDragOut: Bool {
        didSet { UserDefaults.standard.set(autoCloseAfterDragOut, forKey: Keys.autoCloseAfterDragOut) }
    }

    var collapseListOnOutsideClick: Bool {
        didSet { UserDefaults.standard.set(collapseListOnOutsideClick, forKey: Keys.collapseListOnOutsideClick) }
    }

    var shelvesHidden: Bool = false

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: Keys.showInDock)
            applyActivationPolicy()
        }
    }

    var compactMode: Bool {
        didSet {
            UserDefaults.standard.set(compactMode, forKey: Keys.compactMode)
            for shelf in shelves {
                panels[shelf.id]?.updateSize(for: shelf, compact: compactMode)
            }
        }
    }

    var shortcut: ShortcutConfig {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: Keys.shortcut)
            }
            hotkey.register(shortcut)
        }
    }

    var hotkeyStatusMessage: String {
        hotkey.statusMessage
    }

    var hotkeyRegistered: Bool {
        hotkey.isRegistered
    }

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @ObservationIgnored var panels: [UUID: ShelfPanel] = [:]
    @ObservationIgnored private var settingsWindow: NSWindow?
    @ObservationIgnored private var onboardingWindow: NSWindow?
    @ObservationIgnored private var feedbackWindow: NSWindow?
    @ObservationIgnored let shakeMonitor = ShakeMonitor()
    @ObservationIgnored let hotkey = GlobalHotkey()
    @ObservationIgnored let permissions = PermissionMonitor()
    @ObservationIgnored let updater = UpdateChecker()
    @ObservationIgnored var statusBar: StatusBarController?

    private enum Keys {
        static let shakeEnabled = "webodrop.shakeEnabled"
        static let shakeSensitivity = "webodrop.shakeSensitivity"
        static let autoCloseAfterDragOut = "webodrop.autoCloseAfterDragOut"
        static let collapseListOnOutsideClick = "webodrop.collapseListOnOutsideClick"
        static let showInDock = "webodrop.showInDock"
        static let compactMode = "webodrop.compactMode"
        static let shortcut = "webodrop.shortcut"
        static let hasCompletedOnboarding = "shakendrop.hasCompletedOnboarding"
    }

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: Keys.hasCompletedOnboarding)
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.shakeEnabled: true,
            Keys.shakeSensitivity: ShakeSensitivity.medium.rawValue,
            Keys.autoCloseAfterDragOut: true,
            Keys.collapseListOnOutsideClick: true,
            Keys.showInDock: false,
            Keys.compactMode: false,
        ])

        self.shakeEnabled = defaults.bool(forKey: Keys.shakeEnabled)
        self.shakeSensitivity = ShakeSensitivity(rawValue: defaults.string(forKey: Keys.shakeSensitivity) ?? "") ?? .medium
        self.autoCloseAfterDragOut = defaults.bool(forKey: Keys.autoCloseAfterDragOut)
        self.collapseListOnOutsideClick = defaults.bool(forKey: Keys.collapseListOnOutsideClick)
        self.showInDock = defaults.bool(forKey: Keys.showInDock)
        self.compactMode = defaults.bool(forKey: Keys.compactMode)

        if let data = defaults.data(forKey: Keys.shortcut),
           let decoded = try? JSONDecoder().decode(ShortcutConfig.self, from: data) {
            self.shortcut = decoded
        } else {
            self.shortcut = .defaultShelf
        }
    }

    func start() {
        applyActivationPolicy()

        statusBar = StatusBarController(engine: self)

        shakeMonitor.sensitivity = shakeSensitivity
        shakeMonitor.isEnabled = shakeEnabled
        shakeMonitor.onShakeDetected = { [weak self] cursorPoint in
            self?.summonShelf(near: cursorPoint, reuseEmpty: true, summonedByShake: true)
        }
        shakeMonitor.onGlobalClick = { [weak self] screenPoint in
            self?.handleGlobalClick(at: screenPoint)
        }
        shakeMonitor.onGlobalMouseUp = { [weak self] in
            self?.handleGlobalMouseUp()
        }
        shakeMonitor.start()

        hotkey.onTriggered = { [weak self] in
            self?.summonShelfNearCursor(reuseEmpty: false)
        }
        hotkey.register(shortcut)

        permissions.startMonitoring()

        if !SelfTest.requested && !Snapshot.requested {
            updater.scheduleBackgroundCheckIfNeeded()
        }
    }

    func applyActivationPolicy() {
        let isSnapshot = !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
        if showInDock || isSnapshot {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // L'utilisateur peut aussi gérer l'état dans Réglages Système > Ouverture.
        }
    }

    func openSettings() {
        if let existing = settingsWindow {
            NSApp.activate()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = SettingsView()
            .environment(self)
            .themed()
        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Réglages — Shake'n'Drop"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func openOnboarding() {
        if let existing = onboardingWindow {
            NSApp.activate()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        var windowRef: NSWindow?
        let rootView = OnboardingView {
            windowRef?.close()
        }
        .environment(self)
        .themed()

        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Démarrer avec Shake'n'Drop"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        windowRef = window
        onboardingWindow = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func openFeedback(initialKind: FeedbackHelper.Kind = .idea) {
        if let existing = feedbackWindow {
            existing.close()
            feedbackWindow = nil
        }

        var windowRef: NSWindow?
        let rootView = FeedbackView(kind: initialKind) {
            windowRef?.close()
        }
        .environment(self)
        .themed()

        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.title = "Idée ou bug — Shake'n'Drop"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        windowRef = window
        feedbackWindow = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Gestion des étagères

    @discardableResult
    func summonShelfNearCursor(reuseEmpty: Bool = false) -> Shelf {
        summonShelf(near: NSEvent.mouseLocation, reuseEmpty: reuseEmpty)
    }

    @discardableResult
    func summonShelf(
        near screenPoint: NSPoint,
        reuseEmpty: Bool = false,
        initialItems: [ShelfItem] = [],
        summonedByShake: Bool = false
    ) -> Shelf {
        if shelvesHidden {
            setShelvesHidden(false)
        }

        // Si déclenché par shake et qu'une étagère vide existe déjà, on la ramène au curseur.
        if reuseEmpty, initialItems.isEmpty, let emptyShelf = shelves.first(where: { $0.items.isEmpty && !$0.isPinned }),
           let panel = panels[emptyShelf.id] {
            emptyShelf.dockedEdge = nil
            emptyShelf.isEdgePeeked = false
            emptyShelf.summonedByShake = summonedByShake
            panel.position(near: screenPoint)
            panel.orderFrontRegardless()
            return emptyShelf
        }

        let shelf = Shelf(items: initialItems, summonedByShake: summonedByShake)
        shelves.append(shelf)

        let panel = ShelfPanel(shelf: shelf, engine: self, compact: compactMode)
        panels[shelf.id] = panel
        panel.position(near: screenPoint, offsetIndex: shelves.count - 1)
        panel.orderFrontRegardless()

        for item in initialItems {
            loadThumbnail(for: item)
        }

        statusBar?.refresh()
        return shelf
    }

    func toggleHideAllShelves() {
        setShelvesHidden(!shelvesHidden)
    }

    func setShelvesHidden(_ hidden: Bool) {
        shelvesHidden = hidden
        for shelf in shelves {
            guard let panel = panels[shelf.id] else { continue }
            if hidden {
                panel.orderOut(nil)
            } else {
                panel.orderFrontRegardless()
            }
        }
        statusBar?.refresh()
    }

    /// Comportement exact de Dropover lorsqu'on clique dans une autre app :
    /// - Les étagères vides (non épinglées) se ferment automatiquement.
    /// - Les étagères étendues en Liste se replient en Pile (si activé dans Réglages).
    func handleGlobalClick(at screenPoint: NSPoint) {
        guard !shelvesHidden else { return }
        let now = Date.now

        for shelf in shelves {
            guard let panel = panels[shelf.id] else { continue }
            if panel.frame.contains(screenPoint) { continue }

            // Étagère vide : auto-fermeture après un court délai de grâce (0.45s après création)
            if shelf.items.isEmpty && !shelf.isPinned && now.timeIntervalSince(shelf.createdAt) > 0.45 {
                closeShelf(shelf)
                continue
            }

            // Étagère en liste détaillée : repli automatique en Pile
            if shelf.isExpanded && collapseListOnOutsideClick {
                shelf.isExpanded = false
                panel.updateSize(for: shelf, compact: compactMode)
            }
        }
    }

    /// Lorsqu'on relâche un drag dans une autre app sans rien avoir déposé sur une étagère invoquée par Shake :
    /// on lui laisse 1.5s de grâce, puis elle disparaît si elle est toujours vide.
    func handleGlobalMouseUp() {
        let candidates = shelves.filter { $0.items.isEmpty && !$0.isPinned && $0.summonedByShake }
        guard !candidates.isEmpty else { return }
        for shelf in candidates {
            let id = shelf.id
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard let current = self.shelves.first(where: { $0.id == id }),
                      current.items.isEmpty,
                      !current.isPinned,
                      !current.isDropTargeted else { return }
                if let panel = self.panels[id], panel.frame.contains(NSEvent.mouseLocation) {
                    return
                }
                self.closeShelf(current)
            }
        }
    }

    func closeShelf(_ shelf: Shelf) {
        if let panel = panels.removeValue(forKey: shelf.id) {
            panel.orderOut(nil)
            panel.close()
        }
        cleanupTemporaryFiles(for: shelf.items)
        shelves.removeAll { $0.id == shelf.id }
        statusBar?.refresh()
    }

    func closeAllShelves() {
        let all = shelves
        for shelf in all {
            closeShelf(shelf)
        }
    }

    func toggleExpanded(_ shelf: Shelf) {
        shelf.isExpanded.toggle()
        panels[shelf.id]?.updateSize(for: shelf, compact: compactMode)
    }

    // MARK: - Ajout / Suppression d'éléments

    @discardableResult
    func addPasteboard(_ pasteboard: NSPasteboard, to shelf: Shelf) -> Int {
        let newItems = extractItems(from: pasteboard)
        guard !newItems.isEmpty else { return 0 }

        var added = 0
        for item in newItems {
            let duplicate = shelf.items.contains { existing in
                !existing.isTemporaryFile && !item.isTemporaryFile && existing.fileURL == item.fileURL
            }
            if !duplicate {
                shelf.items.append(item)
                loadThumbnail(for: item)
                added += 1
            }
        }
        if added > 0 {
            panels[shelf.id]?.updateSize(for: shelf, compact: compactMode)
            statusBar?.refresh()
        }
        return added
    }

    func removeItem(_ item: ShelfItem, from shelf: Shelf) {
        shelf.items.removeAll { $0.id == item.id }
        if item.isTemporaryFile {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
        if shelf.items.isEmpty {
            shelf.isExpanded = false
        }
        panels[shelf.id]?.updateSize(for: shelf, compact: compactMode)
        statusBar?.refresh()
    }

    func handleDragOutCompleted(for shelf: Shelf, operation: NSDragOperation) {
        guard operation != [] else { return }
        if autoCloseAfterDragOut && !shelf.isPinned {
            closeShelf(shelf)
        }
    }

    // MARK: - Actions sur une étagère

    func copyItems(in shelf: Shelf) {
        guard !shelf.items.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        let urls = shelf.items.map { $0.fileURL as NSURL }
        pb.writeObjects(urls)
        flashStatus("Copié", on: shelf)
    }

    func revealInFinder(_ shelf: Shelf) {
        let urls = shelf.items.map(\.fileURL)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func zipShelf(_ shelf: Shelf) {
        guard !shelf.items.isEmpty, !shelf.isBusy else { return }
        shelf.isBusy = true
        shelf.statusMessage = "Compression…"
        let sourceURLs = shelf.items.map(\.fileURL)

        Task {
            do {
                let archiveURL = try await Self.createZipArchive(from: sourceURLs)
                let size = Self.fileByteSize(at: archiveURL)
                let zipItem = ShelfItem(
                    kind: .file,
                    fileURL: archiveURL,
                    title: archiveURL.lastPathComponent,
                    byteSize: size,
                    isTemporaryFile: true,
                    thumbnail: NSWorkspace.shared.icon(forFile: archiveURL.path)
                )
                shelf.items = [zipItem]
                shelf.isExpanded = false
                shelf.isBusy = false
                loadThumbnail(for: zipItem)
                panels[shelf.id]?.updateSize(for: shelf, compact: compactMode)
                flashStatus("Archive ZIP prête", on: shelf)
            } catch {
                shelf.isBusy = false
                flashStatus("Échec ZIP", on: shelf)
            }
        }
    }

    func shareShelf(_ shelf: Shelf, relativeTo view: NSView) {
        let urls = shelf.items.map(\.fileURL)
        guard !urls.isEmpty else { return }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    func openQuickLook(for shelf: Shelf, startingAt index: Int = 0) {
        guard !shelf.items.isEmpty, let panel = panels[shelf.id] else { return }
        panel.showQuickLook(startingAt: index)
    }

    func flashStatus(_ message: String, on shelf: Shelf) {
        shelf.statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if shelf.statusMessage == message {
                shelf.statusMessage = nil
            }
        }
    }

    // MARK: - Extraction Pasteboard & Miniatures

    func extractItems(from pasteboard: NSPasteboard) -> [ShelfItem] {
        var result: [ShelfItem] = []

        // 1. URLs de fichiers locaux
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            for url in urls {
                result.append(makeItem(fromFileURL: url))
            }
            return result
        }

        // 2. Images en mémoire (depuis navigateur, capture, Aperçu)
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let tempURL = saveTemporaryImage(image) {
            let size = Self.fileByteSize(at: tempURL)
            result.append(ShelfItem(
                kind: .image,
                fileURL: tempURL,
                title: tempURL.lastPathComponent,
                byteSize: size,
                isTemporaryFile: true,
                thumbnail: image
            ))
            return result
        }

        // 3. Lien web (http/https)
        if let urlString = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string),
           let webURL = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
           let scheme = webURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            if let weblocURL = saveTemporaryWebloc(url: webURL) {
                result.append(ShelfItem(
                    kind: .url,
                    fileURL: weblocURL,
                    originalWebURL: webURL,
                    title: webURL.host ?? webURL.absoluteString,
                    byteSize: Self.fileByteSize(at: weblocURL),
                    isTemporaryFile: true,
                    thumbnail: NSWorkspace.shared.icon(for: .internetLocation)
                ))
                return result
            }
        }

        // 4. Texte brut
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let textURL = saveTemporaryText(text) {
            result.append(ShelfItem(
                kind: .text,
                fileURL: textURL,
                originalText: text,
                title: textURL.lastPathComponent,
                byteSize: Self.fileByteSize(at: textURL),
                isTemporaryFile: true,
                thumbnail: NSWorkspace.shared.icon(for: .plainText)
            ))
            return result
        }

        return result
    }

    func makeItem(fromFileURL url: URL) -> ShelfItem {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentTypeKey])
        let isDir = values?.isDirectory ?? false
        let contentType = values?.contentType
        let kind: ShelfItemKind
        if isDir {
            kind = .folder
        } else if let contentType, contentType.conforms(to: .image) {
            kind = .image
        } else {
            kind = .file
        }
        let size = Int64(values?.fileSize ?? 0)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return ShelfItem(
            kind: kind,
            fileURL: url,
            title: url.lastPathComponent,
            byteSize: size,
            isTemporaryFile: false,
            thumbnail: icon
        )
    }

    func loadThumbnail(for item: ShelfItem) {
        let url = item.fileURL
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 128, height: 128),
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let nsImage = representation?.nsImage else { return }
            Task { @MainActor in
                item.thumbnail = nsImage
            }
        }
    }

    // MARK: - Fichiers temporaires & ZIP

    private func tempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "Webodrop", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveTemporaryImage(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let stamp = Int(Date.now.timeIntervalSince1970)
        let url = tempDirectory().appending(path: "Image-\(stamp)-\(UUID().uuidString.prefix(4)).png")
        do {
            try png.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func saveTemporaryText(_ text: String) -> URL? {
        let name = ShelfFormatting.sanitizedFilename(from: text, fallback: "Extrait", extension: "txt")
        let url = tempDirectory().appending(path: name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func saveTemporaryWebloc(url webURL: URL) -> URL? {
        let host = webURL.host ?? "Lien"
        let name = ShelfFormatting.sanitizedFilename(from: host, fallback: "Lien", extension: "webloc")
        let fileURL = tempDirectory().appending(path: name)
        let plist: [String: String] = ["URL": webURL.absoluteString]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private func cleanupTemporaryFiles(for items: [ShelfItem]) {
        for item in items where item.isTemporaryFile {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
    }

    private static func fileByteSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    nonisolated private static func createZipArchive(from urls: [URL]) async throws -> URL {
        let fm = FileManager.default
        let stagingDir = fm.temporaryDirectory.appending(path: "Webodrop-zip-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stagingDir) }

        for url in urls {
            var dest = stagingDir.appending(path: url.lastPathComponent)
            var counter = 2
            while fm.fileExists(atPath: dest.path) {
                let stem = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension
                let altName = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
                dest = stagingDir.appending(path: altName)
                counter += 1
            }
            try fm.copyItem(at: url, to: dest)
        }

        let outDir = fm.temporaryDirectory.appending(path: "Webodrop", directoryHint: .isDirectory)
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        let baseName = urls.count == 1
            ? urls[0].deletingPathExtension().lastPathComponent
            : "ShakeNDrop-\(urls.count)-elements"
        let archiveURL = outDir.appending(path: "\(baseName)-\(Int(Date.now.timeIntervalSince1970)).zip")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", stagingDir.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Webodrop.Zip", code: Int(process.terminationStatus))
        }
        return archiveURL
    }
}
