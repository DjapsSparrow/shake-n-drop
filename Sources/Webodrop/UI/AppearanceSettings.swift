import SwiftUI

/// Réglages > Apparence : couleur d'accentuation des étagères Shake'n'Drop.
/// Les modes Clair et Sombre suivent automatiquement macOS.
struct AppearanceSettings: View {
    @Environment(WebodropEngine.self) private var engine
    @Bindable private var store = ThemeStore.shared

    var body: some View {
        Section("Couleur d'accentuation") {
            ShelfAccentPreview(compact: engine.compactMode)
                .padding(.vertical, Space.xs)

            LabeledContent("Couleur") {
                VStack(alignment: .trailing, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        ForEach(Theme.all) { theme in
                            AccentSwatch(theme: theme, selected: store.themeID == theme.id) {
                                store.themeID = theme.id
                            }
                        }
                    }
                    Text(localizedName(for: store.theme))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func localizedName(for theme: Theme) -> String {
        switch theme.id {
        case "system": "Système (macOS)"
        case "blue": "Bleu"
        case "indigo": "Indigo"
        case "violet": "Violet"
        case "pink": "Rose"
        case "red": "Rouge"
        case "orange": "Orange"
        case "yellow": "Jaune"
        case "mint": "Menthe"
        case "teal": "Turquoise"
        case "graphite": "Graphite"
        default: theme.name
        }
    }
}

/// Miniature statique d'une étagère Shake'n'Drop qui reflète en direct
/// la couleur d'accentuation choisie et le format compact/standard.
private struct ShelfAccentPreview: View {
    let compact: Bool

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: compact ? 6 : 8) {
                HStack {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                    Spacer()
                    Capsule()
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 24, height: 3)
                    Spacer()
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: compact ? 42 : 50, height: compact ? 42 : 50)
                        .overlay {
                            Image(systemName: "photo.fill")
                                .font(.system(size: compact ? 18 : 22))
                                .foregroundStyle(Palette.accent)
                        }
                        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)

                    Text("3")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Palette.accent))
                        .offset(x: 6, y: -5)
                }

                Text("3 éléments")
                    .font(.caption.weight(.semibold))
            }
            .padding(compact ? 10 : 12)
            .frame(width: compact ? 148 : 172)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.accent.opacity(0.7), lineWidth: 1.5)
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: compact)
            Spacer()
        }
        .padding(.vertical, Space.xs)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu d'une étagère Shake'n'Drop")
    }
}

/// Pastille de couleur d'accentuation.
private struct AccentSwatch: View {
    let theme: Theme
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            Circle()
                .fill(fill)
                .frame(width: 16, height: 16)
                .overlay {
                    if selected {
                        Circle().fill(theme.onAccent).frame(width: 6, height: 6)
                    }
                }
                .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var fill: AnyShapeStyle {
        if let tint = theme.tint {
            AnyShapeStyle(tint)
        } else {
            AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                          center: .center))
        }
    }
}
