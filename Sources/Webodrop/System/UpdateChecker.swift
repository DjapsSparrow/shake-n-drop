import AppKit
import Foundation
import SwiftUI
import WebodropKit

/// Vérifie et installe automatiquement les mises à jour de Shake'n'Drop depuis GitHub Releases.
@Observable
final class UpdateChecker {
    struct ReleaseInfo: Sendable {
        let version: String
        let tagName: String
        let notes: String
        let downloadURL: URL
    }

    struct ReleaseEntry: Identifiable, Sendable {
        let id: String
        let version: String
        let notes: String
        let formattedDate: String

        var bulletLines: [String] {
            let lines = notes
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { line in
                    if line.hasPrefix("- ") || line.hasPrefix("• ") || line.hasPrefix("* ") {
                        return String(line.dropFirst(2))
                    }
                    return line
                }
            return lines.isEmpty ? ["Améliorations générales et corrections."] : lines
        }
    }

    nonisolated static let repoSlug = "DjapsSparrow/shake-n-drop"

    private(set) var isChecking: Bool = false
    private(set) var isInstalling: Bool = false
    private(set) var availableUpdate: ReleaseInfo?
    private(set) var statusText: String = ""
    @ObservationIgnored private var updateWindow: NSWindow?

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    private let lastCheckKey = "shakendrop.lastUpdateCheck"

    func scheduleBackgroundCheckIfNeeded() {
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let elapsed = Date.now.timeIntervalSince1970 - lastCheck
        // Vérification silencieuse au maximum une fois toutes les 12 heures.
        guard elapsed > 12 * 3600 else { return }

        Task {
            try? await Task.sleep(for: .seconds(5))
            await checkForUpdates(interactive: false)
        }
    }

    func checkForUpdates(interactive: Bool) async {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        statusText = "Recherche…"
        defer { isChecking = false }

        do {
            let release = try await Self.fetchLatestRelease()
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastCheckKey)

            if VersionCompare.isNewer(release.version, than: currentVersion) {
                availableUpdate = release
                statusText = "Mise à jour v\(release.version) disponible"
                if interactive {
                    promptToInstall(release)
                }
            } else {
                availableUpdate = nil
                statusText = "À jour (v\(currentVersion))"
                if interactive {
                    showInfoAlert(
                        title: "Shake'n'Drop est à jour",
                        message: "Vous utilisez la dernière version (v\(currentVersion))."
                    )
                }
            }
        } catch {
            statusText = "Impossible de vérifier"
            if interactive {
                showInfoAlert(
                    title: "Vérification impossible",
                    message: "Impossible de contacter GitHub Releases pour le moment (\(error.localizedDescription))."
                )
            }
        }
    }

    func promptToInstall(_ release: ReleaseInfo) {
        if let existing = updateWindow {
            existing.close()
            updateWindow = nil
        }

        var windowRef: NSWindow?
        let view = UpdatePromptView(release: release, updater: self) {
            windowRef?.close()
        }
        .themed()

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Mise à jour — Shake'n'Drop"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        windowRef = window
        updateWindow = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func downloadAndInstall(_ release: ReleaseInfo) async {
        guard !isInstalling else { return }
        isInstalling = true
        statusText = "Téléchargement de v\(release.version)…"

        do {
            let targetAppURL = Bundle.main.bundleURL.pathExtension == "app"
                ? Bundle.main.bundleURL
                : URL(fileURLWithPath: "/Applications/Shake'n'Drop.app")
            let currentPID = ProcessInfo.processInfo.processIdentifier

            let extractedApp = try await Self.downloadAndExtract(from: release.downloadURL)
            statusText = "Installation…"
            try Self.scheduleReplaceAndRelaunch(
                newAppURL: extractedApp,
                targetAppURL: targetAppURL,
                pid: currentPID
            )
            NSApp.terminate(nil)
        } catch {
            isInstalling = false
            statusText = "Échec de l'installation"
            showInfoAlert(
                title: "Échec de la mise à jour",
                message: "La mise à jour n'a pas pu être installée : \(error.localizedDescription)"
            )
        }
    }

    private func showInfoAlert(title: String, message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Réseau & Extraction (nonisolated)

    nonisolated static func fetchAllReleases() async throws -> [ReleaseEntry] {
        let url = URL(string: "https://api.github.com/repos/\(repoSlug)/releases?per_page=50")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ShakeNDrop-Updater", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "ShakeNDrop.Update", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Réponse HTTP \(http.statusCode)"
            ])
        }

        struct GHReleaseItem: Decodable {
            let tag_name: String
            let body: String?
            let published_at: String?
        }

        let decoded = try JSONDecoder().decode([GHReleaseItem].self, from: data)
        let iso = ISO8601DateFormatter()
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "fr_FR")
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none

        return decoded.map { item in
            let cleanVersion = item.tag_name.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
            let formattedDate: String
            if let rawDate = item.published_at, let date = iso.date(from: rawDate) {
                formattedDate = displayFormatter.string(from: date)
            } else {
                formattedDate = ""
            }
            return ReleaseEntry(
                id: item.tag_name,
                version: cleanVersion,
                notes: item.body ?? "",
                formattedDate: formattedDate
            )
        }
    }

    nonisolated private static func fetchLatestRelease() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ShakeNDrop-Updater", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "ShakeNDrop.Update", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Réponse HTTP \(http.statusCode)"
            ])
        }

        struct GHAsset: Decodable {
            let name: String
            let browser_download_url: String
        }
        struct GHRelease: Decodable {
            let tag_name: String
            let body: String?
            let assets: [GHAsset]
        }

        let decoded = try JSONDecoder().decode(GHRelease.self, from: data)
        guard let zipAsset = decoded.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }),
              let downloadURL = URL(string: zipAsset.browser_download_url) else {
            throw NSError(domain: "ShakeNDrop.Update", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Aucune archive .zip trouvée dans la release GitHub."
            ])
        }

        let cleanVersion = decoded.tag_name.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
        return ReleaseInfo(
            version: cleanVersion,
            tagName: decoded.tag_name,
            notes: decoded.body ?? "",
            downloadURL: downloadURL
        )
    }

    nonisolated private static func downloadAndExtract(from url: URL) async throws -> URL {
        let (tempZip, _) = try await URLSession.shared.download(from: url)
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appending(path: "ShakeNDrop-Update-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-xk", tempZip.path, staging.path]
        try proc.run()
        proc.waitUntilExit()
        try? fm.removeItem(at: tempZip)

        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "ShakeNDrop.Update", code: Int(proc.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Impossible de décompresser l'archive."
            ])
        }

        let contents = try fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "ShakeNDrop.Update", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Application .app introuvable dans l'archive."
            ])
        }
        return appURL
    }

    nonisolated private static func scheduleReplaceAndRelaunch(newAppURL: URL, targetAppURL: URL, pid: Int32) throws {
        let stagingDir = newAppURL.deletingLastPathComponent().path
        let script = """
        #!/bin/sh
        PID=\(pid)
        for i in $(seq 1 30); do
          kill -0 "$PID" 2>/dev/null || break
          sleep 0.1
        done
        rm -rf "$1"
        mv "$2" "$1"
        xattr -cr "$1" 2>/dev/null || true
        open "$1"
        rm -rf "$3"
        """
        let scriptURL = FileManager.default.temporaryDirectory.appending(path: "shakendrop-apply-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = [scriptURL.path, targetAppURL.path, newAppURL.path, stagingDir]
        try proc.run()
    }
}
