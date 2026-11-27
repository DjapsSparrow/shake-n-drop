import SwiftUI
import WebodropKit

struct SettingsView: View {
    @Environment(WebodropEngine.self) private var engine

    var body: some View {
        @Bindable var engine = engine
        TabView(selection: $engine.settingsTab) {
            generalTab
                .tag(SettingsTab.general)
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.symbol) }

            shortcutTab
                .tag(SettingsTab.shortcut)
                .tabItem { Label(SettingsTab.shortcut.title, systemImage: SettingsTab.shortcut.symbol) }

            appearanceTab
                .tag(SettingsTab.appearance)
                .tabItem { Label(SettingsTab.appearance.title, systemImage: SettingsTab.appearance.symbol) }
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var generalTab: some View {
        @Bindable var engine = engine
        return Form {
            Section("Déclenchement (Shake-to-trigger)") {
                Toggle("Secouer le curseur pendant un glisser-déposer", isOn: $engine.shakeEnabled)
                Picker("Sensibilité de la secousse", selection: $engine.shakeSensitivity) {
                    ForEach(ShakeSensitivity.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                .disabled(!engine.shakeEnabled)
            }

            Section("Comportement des étagères") {
                Toggle("Fermer automatiquement l'étagère après dépôt", isOn: $engine.autoCloseAfterDragOut)
                Toggle("Afficher l'icône dans le Dock", isOn: $engine.showInDock)
                Toggle("Lancer Webodrop à l'ouverture de session", isOn: Binding(
                    get: { engine.launchAtLogin },
                    set: { engine.setLaunchAtLogin($0) }
                ))
            }

            Section("Autorisation Système (Accessibilité)") {
                HStack {
                    Label(
                        engine.permissions.accessibilityGranted ? "Autorisée" : "Recommandée pour le Shake global",
                        systemImage: engine.permissions.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(engine.permissions.accessibilityGranted ? .green : .orange)
                    Spacer()
                    if !engine.permissions.accessibilityGranted {
                        Button("Ouvrir Réglages Système") {
                            engine.permissions.openAccessibilitySettings()
                        }
                    }
                }
                Text("Permet de détecter la secousse du curseur depuis toutes vos applications. Le raccourci global et la barre de menu fonctionnent sans aucune autorisation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            engine.permissions.refresh()
        }
    }

    private var shortcutTab: some View {
        @Bindable var engine = engine
        return Form {
            Section("Raccourci clavier global") {
                Picker("Combinaison", selection: $engine.shortcut) {
                    ForEach(ShortcutConfig.presets, id: \.displayLabel) { preset in
                        Text(preset.displayLabel).tag(preset)
                    }
                }

                LabeledContent("Statut") {
                    Label(
                        engine.hotkeyStatusMessage,
                        systemImage: engine.hotkeyRegistered ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(engine.hotkeyRegistered ? .green : .red)
                }
            }

            Section("Test rapide") {
                HStack {
                    Text("Ouvrir une étagère flottante maintenant")
                    Spacer()
                    Button("Nouvelle étagère") {
                        engine.summonShelfNearCursor(reuseEmpty: false)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        @Bindable var engine = engine
        return Form {
            Section("Format") {
                Toggle("Étagères compactes", isOn: $engine.compactMode)
            }
            AppearanceSettings()
        }
        .formStyle(.grouped)
    }
}
