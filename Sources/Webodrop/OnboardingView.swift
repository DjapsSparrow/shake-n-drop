import SwiftUI

/// Mini-guide affiché une seule fois au premier lancement (et réouvrable depuis la barre de menu).
struct OnboardingView: View {
    @Environment(WebodropEngine.self) private var engine
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.sm) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)

                Text("Bienvenue dans Shake'n'Drop")
                    .font(.title2.weight(.bold))

                Text("Vos étagères flottantes pour collecter, prévisualiser et déplacer vos fichiers entre n'importe quelles apps.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Space.md) {
                stepRow(
                    symbol: "hand.wave.fill",
                    title: "Secouez le curseur ou utilisez \(engine.shortcut.displayLabel)",
                    detail: "En glissant un fichier, secouez la souris pour faire surgir une étagère — ou glissez directement sur l'icône en haut."
                )
                stepRow(
                    symbol: "sidebar.right",
                    title: "Rangez sur les bords de l'écran",
                    detail: "Poussez une étagère contre le bord gauche ou droit pour la replier en languette discrète. Survolez-la pour la ressortir."
                )
                accessibilityRow
            }
            .padding(Space.md)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            HStack {
                Button("Suggérer une idée / Bug") {
                    engine.openFeedback(initialKind: .idea)
                }
                .buttonStyle(.link)
                .font(.caption)

                Spacer()

                Button("Commencer") {
                    engine.markOnboardingCompleted()
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xl)
        .frame(width: 460)
        .onAppear {
            engine.permissions.refresh()
        }
    }

    private func stepRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityRow: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: engine.permissions.accessibilityGranted ? "checkmark.shield.fill" : "lock.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(engine.permissions.accessibilityGranted ? .green : .orange)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Autoriser le Shake global (Accessibilité)")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    if engine.permissions.accessibilityGranted {
                        Text("Activé")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button("Autoriser") {
                            engine.permissions.openAccessibilitySettings()
                        }
                        .controlSize(.small)
                    }
                }
                Text("Recommandé pour détecter la secousse depuis le Finder et vos autres apps. Le raccourci \(engine.shortcut.displayLabel) fonctionne déjà sans autorisation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
