import AppKit
import Foundation
import WebodropKit

/// Auto-test interne exécuté via `Webodrop --selftest`.
enum SelfTest {
    static let requested = CommandLine.arguments.contains("--selftest")
    static var exitCode: Int32 = 1

    static func run(engine: WebodropEngine) {
        Task {
            var passed = true
            func check(_ name: String, _ condition: Bool) {
                print("\(condition ? "PASS" : "FAIL"): \(name)")
                if !condition { passed = false }
            }

            // 1. Création d'étagère flottante
            let shelf = engine.summonShelfNearCursor(reuseEmpty: false)
            check("Création étagère flottante", engine.shelves.contains { $0.id == shelf.id })
            check("Panneau NSPanel associé", engine.panels[shelf.id] != nil)

            // 2. Ajout via pasteboard (texte)
            let pb = NSPasteboard.withUniqueName()
            pb.clearContents()
            pb.setString("Hello Webodrop!", forType: .string)
            let added = engine.addPasteboard(pb, to: shelf)
            check("Extraction texte depuis Pasteboard", added == 1 && shelf.items.count == 1)

            // 3. Déploiement liste
            engine.toggleExpanded(shelf)
            check("Basculer mode liste", shelf.isExpanded)

            // 4. Fermeture propre et nettoyage fichiers temporaires
            let tempURL = shelf.items.first?.fileURL
            engine.closeShelf(shelf)
            check("Fermeture étagère", engine.shelves.isEmpty && engine.panels.isEmpty)
            if let tempURL {
                check("Nettoyage fichier temporaire", !FileManager.default.fileExists(atPath: tempURL.path))
            }

            exitCode = passed ? 0 : 1
            NSApp.terminate(nil)
        }
    }
}
