import Foundation

/// Type logique d'un élément posé sur une étagère Webodrop.
public enum ShelfItemKind: String, Sendable, Equatable, Codable {
    case file
    case folder
    case image
    case url
    case text

    public var symbolName: String {
        switch self {
        case .file: "doc.fill"
        case .folder: "folder.fill"
        case .image: "photo.fill"
        case .url: "link"
        case .text: "text.alignleft"
        }
    }
}

/// Utilitaires purs pour formater les résumés et noms d'étagères.
public enum ShelfFormatting {
    /// Résumé lisible du nombre d'éléments ("1 élément", "4 éléments").
    public static func itemCountLabel(_ count: Int) -> String {
        switch count {
        case 0: "Étagère vide"
        case 1: "1 élément"
        default: "\(count) éléments"
        }
    }

    /// Formate une taille en octets de façon compacte en français (ex: "2,4 Mo").
    public static func formattedByteSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Produit un nom de fichier sûr pour enregistrer un extrait de texte ou une image.
    public static func sanitizedFilename(from raw: String, fallback: String = "Extrait", extension ext: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? ""
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = trimmed
            .components(separatedBy: invalid)
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleaned.isEmpty ? fallback : String(cleaned.prefix(40))
        return "\(base).\(ext)"
    }
}
