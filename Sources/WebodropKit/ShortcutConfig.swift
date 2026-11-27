import Foundation

/// Configuration d'un raccourci clavier global Carbon.
public struct ShortcutConfig: Sendable, Equatable, Hashable, Codable {
    /// KeyCode virtuel Carbon (ex: 2 = 'D' sur ANSI).
    public var keyCode: UInt32
    /// Masque de modificateurs Carbon (`optionKey`, `shiftKey`, `cmdKey`, `controlKey`).
    public var modifiers: UInt32
    /// Libellé lisible affiché dans l'interface (ex: "⌥⇧D").
    public var displayLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, displayLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayLabel = displayLabel
    }

    /// Raccourci par défaut : Option + Maj + D (`kVK_ANSI_D = 2`, `optionKey = 2048`, `shiftKey = 512`).
    public static let defaultShelf = ShortcutConfig(
        keyCode: 2,
        modifiers: 2048 | 512,
        displayLabel: "⌥⇧D"
    )

    /// Presets pratiques proposés dans les Réglages.
    public static let presets: [ShortcutConfig] = [
        ShortcutConfig(keyCode: 2, modifiers: 2048 | 512, displayLabel: "⌥⇧D"),
        ShortcutConfig(keyCode: 49, modifiers: 2048 | 512, displayLabel: "⌥⇧Espace"),
        ShortcutConfig(keyCode: 2, modifiers: 4096 | 2048, displayLabel: "⌃⌥D"),
        ShortcutConfig(keyCode: 1, modifiers: 2048 | 512, displayLabel: "⌥⇧S"),
    ]
}
