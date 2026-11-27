import Foundation

/// Sensibilité du geste "Shake-to-trigger" (secouer le curseur pendant un drag).
public enum ShakeSensitivity: String, CaseIterable, Sendable, Identifiable {
    case low
    case medium
    case high

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .low: "Faible (secousse appuyée)"
        case .medium: "Normale"
        case .high: "Élevée (secousse légère)"
        }
    }

    /// Nombre d'inversions de direction requis dans la fenêtre temporelle.
    public var requiredReversals: Int {
        switch self {
        case .low: 5
        case .medium: 4
        case .high: 3
        }
    }

    /// Déplacement minimal (en points) pour compter un segment de secousse.
    public var minimumSegmentDistance: Double {
        switch self {
        case .low: 28
        case .medium: 18
        case .high: 12
        }
    }

    /// Fenêtre temporelle glissante (en secondes) pour détecter la secousse.
    public var timeWindow: TimeInterval {
        switch self {
        case .low: 0.48
        case .medium: 0.55
        case .high: 0.65
        }
    }
}

/// Échantillon de position du curseur.
public struct CursorSample: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let timestamp: TimeInterval

    public init(x: Double, y: Double, timestamp: TimeInterval) {
        self.x = x
        self.y = y
        self.timestamp = timestamp
    }
}

/// Détecteur pur (sans dépendance AppKit) de secousse de souris/trackpad.
/// Analyse les inversions rapides sur l'axe horizontal ou vertical dans une fenêtre glissante.
public struct ShakeDetector: Sendable {
    public var sensitivity: ShakeSensitivity
    public var cooldown: TimeInterval

    private var samples: [CursorSample] = []
    private var lastTriggerTime: TimeInterval = -.infinity

    public init(sensitivity: ShakeSensitivity = .medium, cooldown: TimeInterval = 0.9) {
        self.sensitivity = sensitivity
        self.cooldown = cooldown
    }

    /// Réinitialise l'historique (par exemple à la fin d'un drag).
    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
    }

    /// Enregistre une nouvelle position de curseur pendant un drag.
    /// Retourne `true` si une secousse franche vient d'être détectée.
    public mutating func record(_ sample: CursorSample) -> Bool {
        if sample.timestamp - lastTriggerTime < cooldown {
            return false
        }

        samples.append(sample)
        let cutoff = sample.timestamp - sensitivity.timeWindow
        if let firstValid = samples.firstIndex(where: { $0.timestamp >= cutoff }) {
            if firstValid > 0 {
                samples.removeFirst(firstValid)
            }
        }

        guard samples.count >= 4 else { return false }

        let xReversals = countReversals(values: samples.map(\.x), minDistance: sensitivity.minimumSegmentDistance)
        let yReversals = countReversals(values: samples.map(\.y), minDistance: sensitivity.minimumSegmentDistance)

        if max(xReversals, yReversals) >= sensitivity.requiredReversals {
            lastTriggerTime = sample.timestamp
            samples.removeAll(keepingCapacity: true)
            return true
        }

        return false
    }

    private func countReversals(values: [Double], minDistance: Double) -> Int {
        guard values.count >= 3 else { return 0 }
        var reversals = 0
        var anchor = values[0]
        var direction = 0 // -1 ou +1

        for value in values.dropFirst() {
            let delta = value - anchor
            if abs(delta) < minDistance {
                continue
            }
            let newDirection = delta > 0 ? 1 : -1
            if direction != 0 && newDirection != direction {
                reversals += 1
            }
            direction = newDirection
            anchor = value
        }
        return reversals
    }
}
