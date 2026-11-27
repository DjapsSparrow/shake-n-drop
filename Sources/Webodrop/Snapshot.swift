import AppKit
import IOKit.pwr_mgt
import SwiftUI
import WebodropKit

/// Mode capture automatisée pour vérifier l'interface en Light & Dark.
/// Usage : APP_SNAPSHOT=/tmp/webodrop-shots ~/Applications/Webodrop.app/Contents/MacOS/Webodrop
enum Snapshot {
    static var requested: Bool {
        !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
    }

    static func run(engine: WebodropEngine) {
        guard let dir = ProcessInfo.processInfo.environment["APP_SNAPSHOT"], !dir.isEmpty else { return }

        Task {
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Snapshots" as CFString,
                &awake
            )

            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

            let screenCenter = NSScreen.main.map {
                NSPoint(x: $0.visibleFrame.midX - 110, y: $0.visibleFrame.midY)
            } ?? NSPoint(x: 400, y: 400)

            // 1. Étagère vide
            let emptyShelf = engine.summonShelf(near: screenCenter)
            guard let panel = engine.panels[emptyShelf.id] else {
                NSApp.terminate(nil)
                return
            }

            try? await Task.sleep(for: .seconds(0.6))
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                try? await Task.sleep(for: .seconds(0.5))
                capture(to: "\(dir)/shelf-empty-\(mode).png", window: panel)
            }

            // 2. Étagère remplie (Mode Pile)
            let sampleItems = makeSampleItems()
            emptyShelf.items = sampleItems
            panel.updateSize(for: emptyShelf, compact: engine.compactMode)
            try? await Task.sleep(for: .seconds(0.6))

            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                try? await Task.sleep(for: .seconds(0.5))
                capture(to: "\(dir)/shelf-stack-\(mode).png", window: panel)
            }

            // 3. Étagère remplie (Mode Liste étendue)
            emptyShelf.isExpanded = true
            panel.updateSize(for: emptyShelf, compact: engine.compactMode)
            try? await Task.sleep(for: .seconds(0.6))

            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                try? await Task.sleep(for: .seconds(0.5))
                capture(to: "\(dir)/shelf-list-\(mode).png", window: panel)
            }

            print("SNAPSHOT done \(dir)")
            NSApp.terminate(nil)
        }
    }

    private static func makeSampleItems() -> [ShelfItem] {
        let tmp = FileManager.default.temporaryDirectory
        return [
            ShelfItem(
                kind: .image,
                fileURL: tmp.appending(path: "Maquette-Hero.png"),
                title: "Maquette-Hero.png",
                byteSize: 2_450_000,
                isTemporaryFile: false,
                thumbnail: NSImage(systemSymbolName: "photo.fill", accessibilityDescription: nil)
            ),
            ShelfItem(
                kind: .file,
                fileURL: tmp.appending(path: "Devis-Webomatik-2026.pdf"),
                title: "Devis-Webomatik-2026.pdf",
                byteSize: 842_000,
                isTemporaryFile: false,
                thumbnail: NSImage(systemSymbolName: "doc.richtext.fill", accessibilityDescription: nil)
            ),
            ShelfItem(
                kind: .url,
                fileURL: tmp.appending(path: "dropoverapp.com.webloc"),
                originalWebURL: URL(string: "https://dropoverapp.com"),
                title: "dropoverapp.com",
                byteSize: 512,
                isTemporaryFile: false,
                thumbnail: NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: nil)
            ),
        ]
    }

    private static func capture(to path: String, window: NSWindow) {
        NSApp.activate()
        window.orderFrontRegardless()
        try? FileManager.default.removeItem(atPath: path)
        for _ in 1...2 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback)")
        }
    }
}
