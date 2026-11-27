import AppKit
import SwiftUI

/// Parcours d'installation guidé en 2 étapes au premier lancement (aucune autorisation requise) :
/// 1. Installation automatique dans `/Applications` (+ ajout optionnel au Dock) avec animation "Bien installé !"
/// 2. Prise en main rapide + lancement de la première étagère
struct OnboardingView: View {
    @Environment(WebodropEngine.self) private var engine
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case install = 0
        case ready = 1
    }

    @State private var step: Step
    @State private var addToDock: Bool = true
    @State private var isInstalling: Bool = false
    @State private var justInstalled: Bool = false
    @State private var installError: String?
    @State private var showDoneCheck: Bool = false

    private static var isAlreadyInApplications: Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        return path.hasPrefix("/Applications/")
    }

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _step = State(initialValue: Self.isAlreadyInApplications ? .ready : .install)
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
                .padding(.top, Space.lg)
                .padding(.horizontal, Space.xl)

            Group {
                switch step {
                case .install:
                    installStepView
                case .ready:
                    readyStepView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Space.xl)
            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: step)
        }
        .frame(width: 480, height: 380)
    }

    private var progressHeader: some View {
        HStack(spacing: Space.sm) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Palette.accent : Color.primary.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Étape 1 : Installation dans /Applications

    private var installStepView: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            ZStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .scaleEffect(justInstalled ? 0.92 : 1.0)

                if justInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white, .green)
                        .offset(x: 30, y: 28)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: justInstalled)

            VStack(spacing: Space.xs) {
                Text(justInstalled ? "Bien installé !" : "Installer Shake'n'Drop")
                    .font(.title2.weight(.bold))

                Text(justInstalled
                     ? "Shake'n'Drop est maintenant dans votre dossier Applications."
                     : "Nous allons copier Shake'n'Drop dans votre dossier Applications pour qu'elle reste disponible à tout moment.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !justInstalled {
                Toggle("Ajouter l'icône dans le Dock", isOn: $addToDock)
                    .toggleStyle(.checkbox)
                    .font(.callout)
            }

            if let installError {
                Label(installError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            HStack {
                if !justInstalled {
                    Button("Passer") {
                        step = .ready
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if justInstalled {
                    Button("Continuer") {
                        step = .ready
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        runInstallToApplications()
                    } label: {
                        if isInstalling {
                            HStack(spacing: Space.sm) {
                                ProgressView().controlSize(.small)
                                Text("Installation…")
                            }
                        } else {
                            Text("Installer dans Applications")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isInstalling)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    // MARK: - Étape 2 : Prêt !

    private var readyStepView: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.14))
                    .frame(width: 84, height: 84)
                    .scaleEffect(showDoneCheck ? 1.0 : 0.6)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.green)
                    .scaleEffect(showDoneCheck ? 1.0 : 0.4)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.62), value: showDoneCheck)

            VStack(spacing: Space.xs) {
                Text("Shake'n'Drop est prêt !")
                    .font(.title2.weight(.bold))

                Text("Secouez le curseur en glissant un fichier ou un lien, utilisez \(engine.shortcut.displayLabel), ou glissez directement sur l'icône en haut.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Space.md) {
                tipBadge(symbol: "hand.wave.fill", label: "Secouer")
                tipBadge(symbol: "command", label: engine.shortcut.displayLabel)
                tipBadge(symbol: "sidebar.right", label: "Aimant bords")
            }

            Spacer(minLength: 0)

            HStack {
                Button("Idée ou bug ?") {
                    engine.openFeedback(initialKind: .idea)
                }
                .buttonStyle(.link)
                .font(.caption)

                Spacer()

                Button("Ouvrir ma première étagère") {
                    engine.markOnboardingCompleted()
                    onFinish()
                    engine.summonShelfNearCursor(reuseEmpty: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.08)) {
                showDoneCheck = true
            }
        }
    }

    private func tipBadge(symbol: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 96, height: 54)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: - Copie réelle dans /Applications + ajout optionnel au Dock

    private func runInstallToApplications() {
        isInstalling = true
        installError = nil
        let sourceURL = Bundle.main.bundleURL
        let destURL = URL(fileURLWithPath: "/Applications/Shake'n'Drop.app")
        let shouldAddToDock = addToDock

        Task {
            do {
                try await Self.copyAppToApplications(from: sourceURL, to: destURL, addToDock: shouldAddToDock)
                isInstalling = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    justInstalled = true
                }
            } catch {
                isInstalling = false
                installError = "Impossible de copier automatiquement (\(error.localizedDescription)). Glissez-la dans Applications."
            }
        }
    }

    nonisolated private static func copyAppToApplications(from source: URL, to dest: URL, addToDock: Bool) async throws {
        let fm = FileManager.default
        if source.standardizedFileURL.path != dest.standardizedFileURL.path {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: source, to: dest)
        }

        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-cr", dest.path]
        try? xattr.run()
        xattr.waitUntilExit()

        if addToDock {
            let check = Process()
            check.executableURL = URL(fileURLWithPath: "/bin/sh")
            check.arguments = [
                "-c",
                """
                if ! defaults read com.apple.dock persistent-apps | grep -q "Shake'n'Drop"; then
                  defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Shake'n'Drop.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
                  killall Dock
                fi
                """,
            ]
            try? check.run()
            check.waitUntilExit()
        }
    }
}
