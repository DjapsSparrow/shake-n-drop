import SwiftUI

/// Fenêtre native soignée affichant les nouveautés d'une mise à jour Shake'n'Drop
/// avec liste à puces, badge de version et barre de progression en direct.
struct UpdatePromptView: View {
    let release: UpdateChecker.ReleaseInfo
    let updater: UpdateChecker
    let onClose: () -> Void

    private var bulletLines: [String] {
        release.notes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                if line.hasPrefix("- ") || line.hasPrefix("• ") || line.hasPrefix("* ") {
                    return String(line.dropFirst(2))
                }
                return line
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            // En-tête
            HStack(spacing: Space.md) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mise à jour disponible")
                        .font(.title3.weight(.bold))

                    HStack(spacing: 6) {
                        Text("v\(updater.currentVersion)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        Text("v\(release.version)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Palette.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Palette.accent))
                    }
                }
                Spacer()
            }

            // Liste des nouveautés
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("NOUVEAUTÉS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                ScrollView {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        if bulletLines.isEmpty {
                            Text("Améliorations générales et corrections de stabilité.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(bulletLines.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: Space.sm) {
                                    Circle()
                                        .fill(Palette.accent)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(line)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 84, maxHeight: 168)
            }
            .padding(Space.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Progression ou boutons d'action
            if updater.isInstalling {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text(updater.statusText.isEmpty ? "Installation en cours…" : updater.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Button("Plus tard") {
                        onClose()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Installer et relancer") {
                        Task {
                            await updater.downloadAndInstall(release)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(Space.xl)
        .frame(width: 440)
    }
}
