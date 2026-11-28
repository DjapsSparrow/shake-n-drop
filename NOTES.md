# NOTES — Shake'n'Drop (macOS Swift 6 Natif)

## PHASE 1: ÉTAT ACTUEL & CONTEXTE OPÉRATIONNEL (VIVANT)
- **Statut :** ✅ **v1.0.20** publiée sur GitHub Releases (`https://github.com/DjapsSparrow/shake-n-drop/releases/latest`)
- **Repo & Pages :** `DjapsSparrow/shake-n-drop` | Formulaire feedback live : `https://djapssparrow.github.io/shake-n-drop/feedback.html`
- **Stack :** Swift 6.4 (`defaultIsolation(MainActor.self)`), SwiftUI, AppKit, Carbon HotKey, QuickLook, WebKit (`WKWebView`). Compatible **macOS 14.0+**.
- **Brief :** [`docs/BRIEF.md`](docs/BRIEF.md) | **Backlog :** [`docs/task.md`](docs/task.md) | **Journal :** [`docs/journal/INDEX.md`](docs/journal/INDEX.md)

### Architecture & Fonctionnalités actives
- **Déclencheurs (0 permission système requise) :**
  - *Shake-to-trigger* : `ShakeMonitor` + `ShakeDetector` filtré sur vrai drag (`NSPasteboard(name: .drag)`), ignore les déplacements de fenêtres.
  - *Raccourci global* : `⌥⇧D` (Carbon `RegisterEventHotKey`, presets dans Réglages).
  - *Barre de menu* : `NSStatusItem` (picto 18×18 *Curseur qui vibre*), drop direct sur l'icône, menu épuré avec SF Symbols alignés.
- **Étagères flottantes (`ShelfPanel` / `ShelfView` / `ShelfDragBridge`) :**
  - Déplaçables via `performDrag(with:)`, auto-fermeture des étagères vides au clic extérieur, repli auto de la liste en pile.
  - Bouton intelligent `⇤`/`⇥` dans l'en-tête pour ranger en languette Liquid Glass `40×96` sur le bord le plus proche (survol pour déployer, clic pour détacher).
  - Support complet fichiers, dossiers, images, textes et URLs `.webloc` (titre de page + favicon + ouverture au clic).
  - Quick Look (`Espace`), AirDrop/Partage, ZIP (`/usr/bin/ditto`), Copier, Révéler Finder.
- **Distribution & Support :**
  - Auto-updater GitHub Releases (`UpdateChecker` + `UpdatePromptView` + `ChangelogView`).
  - Parcours d'installation 2 étapes intégré (`OnboardingView` : copie `/Applications` + Dock).
  - Formulaire Idée / Bug intégré (`FeedbackView` + `docs/feedback.html` via Web3Forms → `support@webomatik.fr`).
  - Release 1-commande : `./tools/release.sh <version> "<notes>" [--no-install]`.

### 🚫 Arbitrages & Pistes Écartées (Ne pas reproposer)
- **Pas de fichier "Lisez-moi" dans le DMG** → tout le parcours d'installation est intégré dans l'app.
- **Pas d'aimantation automatique au drag sur les bords** → conflit avec macOS Window Tiling ; utiliser le bouton `⇤`/`⇥`.
- **Pas de demande d'Accessibilité** → le Shake souris natif fonctionne sans aucune permission.
- **Pas de dropzone ouverte au reboot / après MAJ** → démarrage discret en barre de menu.
- **Pas de version localement écrasée lors des releases de test** → utiliser `--no-install` pour tester l'auto-updater.
- **Pas de version Windows pour l'instant** → en attente d'un testeur Windows.

### Validation
- `swift test` : 6/6 passés (`WebodropKitTests`).
- `--selftest` : 6/6 checks PASS.
- GitHub Releases : `v1.0.20` (`ShakeNDrop.dmg` + `ShakeNDrop.zip`) en ligne.
