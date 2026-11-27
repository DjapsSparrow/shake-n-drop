import Foundation
import Testing
@testable import WebodropKit

@Test func shakeDetectorTriggersOnRapidHorizontalShake() {
    var detector = ShakeDetector(sensitivity: .medium, cooldown: 1.0)
    // Simule un va-et-vient rapide gauche-droite sur ~0.35s
    let points: [(Double, Double)] = [
        (100, 0.00),
        (140, 0.05),
        (95, 0.10),
        (145, 0.15),
        (90, 0.20),
        (150, 0.25),
        (85, 0.30),
    ]
    var triggered = false
    for (x, t) in points {
        if detector.record(CursorSample(x: x, y: 200, timestamp: t)) {
            triggered = true
            break
        }
    }
    #expect(triggered)
}

@Test func shakeDetectorIgnoresStraightDrag() {
    var detector = ShakeDetector(sensitivity: .high, cooldown: 1.0)
    var triggered = false
    for i in 0..<20 {
        let t = Double(i) * 0.03
        let x = 100.0 + Double(i) * 25.0
        if detector.record(CursorSample(x: x, y: 200, timestamp: t)) {
            triggered = true
        }
    }
    #expect(!triggered)
}

@Test func shakeDetectorRespectsCooldown() {
    var detector = ShakeDetector(sensitivity: .high, cooldown: 1.0)
    let firstWave: [(Double, Double)] = [
        (100, 0.00), (140, 0.05), (90, 0.10), (140, 0.15), (90, 0.20), (140, 0.25)
    ]
    let firstTriggered = firstWave.contains { detector.record(CursorSample(x: $0.0, y: 0, timestamp: $0.1)) }
    #expect(firstTriggered)

    // Immédiatement après (t = 0.40..0.65), le cooldown doit bloquer
    let secondWave: [(Double, Double)] = [
        (100, 0.40), (140, 0.45), (90, 0.50), (140, 0.55), (90, 0.60), (140, 0.65)
    ]
    let secondTriggered = secondWave.contains { detector.record(CursorSample(x: $0.0, y: 0, timestamp: $0.1)) }
    #expect(!secondTriggered)
}

@Test func shelfFormattingHandlesCountsAndFilenames() {
    #expect(ShelfFormatting.itemCountLabel(0) == "Étagère vide")
    #expect(ShelfFormatting.itemCountLabel(1) == "1 élément")
    #expect(ShelfFormatting.itemCountLabel(5) == "5 éléments")

    let clean = ShelfFormatting.sanitizedFilename(from: "  Rapport: Q4/2026? \nDeuxième ligne", extension: "txt")
    #expect(clean == "Rapport Q4 2026 .txt" || clean.hasSuffix(".txt"))
    #expect(!clean.contains("/"))
    #expect(!clean.contains(":"))

    let empty = ShelfFormatting.sanitizedFilename(from: "   \n  ", fallback: "Note", extension: "txt")
    #expect(empty == "Note.txt")
}

@Test func shortcutPresetsContainDefault() {
    #expect(ShortcutConfig.presets.contains(ShortcutConfig.defaultShelf))
}
