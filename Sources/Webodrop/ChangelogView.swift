import SwiftUI

/// Fenêtre native affichant l'historique complet des versions publiées sur GitHub Releases
/// depuis la toute première version (v1.0.0).
struct ChangelogView: View {
    let updater: UpdateChecker
    let onClose: () -> Void

    @State private var releases: [UpdateChecker.ReleaseEntry] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.md) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Historique des versions")
                        .font(.title3.weight(.bold))
                    Text("Shake'n'Drop — Version installée : v\(updater.currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Space.lg)

            Divider()

            Group {
                if isLoading {
                    VStack(spacing: Space.sm) {
                        ProgressView()
                        Text("Chargement depuis GitHub…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: Space.sm) {
                        Image(systemName: "wifi.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Space.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Space.md) {
                            ForEach(releases) { entry in
                                releaseCard(entry)
                            }
                        }
                        .padding(Space.lg)
                    }
                }
            }

            Divider()

            HStack {
                if let url = URL(string: "https://github.com/\(UpdateChecker.repoSlug)/releases") {
                    Link("Voir sur GitHub", destination: url)
                        .font(.caption)
                }
                Spacer()
                Button("Fermer") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(Space.md)
        }
        .frame(width: 480, height: 500)
        .task {
            await loadReleases()
        }
    }

    private func releaseCard(_ entry: UpdateChecker.ReleaseEntry) -> some View {
        let isCurrent = entry.version == updater.currentVersion
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Text("v\(entry.version)")
                    .font(.callout.weight(.bold).monospacedDigit())
                    .foregroundStyle(isCurrent ? Palette.onAccent : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isCurrent ? Palette.accent : Color.primary.opacity(0.08))
                    )

                if isCurrent {
                    Text("Installée")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Spacer()

                if !entry.formattedDate.isEmpty {
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(entry.bulletLines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: Space.sm) {
                        Circle()
                            .fill(isCurrent ? Palette.accent : Color.secondary.opacity(0.6))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(isCurrent ? 0.06 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCurrent ? Palette.accent.opacity(0.45) : Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func loadReleases() async {
        isLoading = true
        errorMessage = nil
        do {
            releases = try await UpdateChecker.fetchAllReleases()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Impossible de charger l'historique (\(error.localizedDescription))."
        }
    }
}
