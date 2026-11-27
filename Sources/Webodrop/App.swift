import AppKit
import SwiftUI

// Webodrop — Mini-app macOS native d'étagères flottantes façon Dropover.
//   Webodrop                        lance l'app barre de menu
//   APP_SNAPSHOT=<dir> Webodrop     capture les étagères (vide, pile, liste) et Réglages en Light & Dark puis quitte
//   Webodrop --selftest             exécute l'auto-test interne et quitte avec 0 ou 1

@main
struct WebodropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(WebodropEngine.shared)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = WebodropEngine.shared
        engine.start()

        if SelfTest.requested {
            SelfTest.run(engine: engine)
            return
        }

        if Snapshot.requested {
            Snapshot.run(engine: engine)
            return
        }

        // Au tout premier lancement, affiche le parcours d'installation ; ensuite démarre discrètement en barre de menu.
        if !engine.hasCompletedOnboarding {
            engine.openOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Application barre de menu : reste active en arrière-plan même sans étagère ouverte.
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WebodropEngine.shared.summonShelfNearCursor(reuseEmpty: true)
        }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let engine = WebodropEngine.shared
        for url in urls {
            guard let scheme = url.scheme?.lowercased(), scheme == "shakendrop" || scheme == "webodrop" else { continue }
            let action = url.lastPathComponent.lowercased()
            switch action {
            case "new-shelf", "new":
                engine.summonShelfNearCursor(reuseEmpty: false)
            case "close-all", "clear":
                engine.closeAllShelves()
            case "settings":
                engine.openSettings()
            default:
                break
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        WebodropEngine.shared.shakeMonitor.stop()
        WebodropEngine.shared.hotkey.unregister()
        if SelfTest.requested {
            exit(SelfTest.exitCode)
        }
    }
}
