import Foundation

/// Comparaison sémantique simple pour les versions GitHub Releases ("v1.2.0" vs "1.1.9").
public enum VersionCompare {
    public static func components(of raw: String) -> [Int] {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
            .split(separator: "-")
            .first
            .map(String.init) ?? ""
        return cleaned.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// Retourne `true` si `remote` est strictement plus récent que `current`.
    public static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = components(of: remote)
        let c = components(of: current)
        let maxLen = max(r.count, c.count)
        guard maxLen > 0 else { return false }
        for i in 0..<maxLen {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv {
                return rv > cv
            }
        }
        return false
    }
}
