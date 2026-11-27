# NOTES — Shake'n'Drop (ex-Webodrop, macOS Swift 6 Natif)

- **Statut :** ✅ V1 fonctionnelle, compilée en Release, testée, installée dans `/Applications/Shake'n'Drop.app` et épinglée au Dock.
- **Stack :** Swift 6.4 (strict concurrency, `defaultIsolation(MainActor.self)`), SwiftUI, AppKit (`NSPanel`, `NSStatusItem`, `NSDraggingSource`/`Destination`), Carbon (`RegisterEventHotKey`), QuickLook (`QLPreviewPanel` + `QLThumbnailGenerator`).
- **Brief :** [`docs/BRIEF.md`](docs/BRIEF.md)

## Fonctionnalités V1 livrées
- **Déclencheurs :**
  - *Shake-to-trigger* : `ShakeMonitor` + `ShakeDetector` (sensibilité Basse/Normale/Élevée, cooldown anti-rebond).
  - *Raccourci global* : `⌥⇧D` par défaut (Carbon `RegisterEventHotKey`, zéro permission, presets dans Réglages).
  - *Barre de menu* : `NSStatusItem` avec compteur d'éléments, menu natif ET zone de drop directe sur l'icône.
  - *Schéma URL* : `webodrop://action/new-shelf`, `webodrop://action/close-all`, `webodrop://action/settings`.
- **Étagères flottantes (`ShelfPanel` / `ShelfView`) :**
  - Multi-étagères *always-on-top* non-activantes, déplaçables via `performDrag(with:)`, visibles sur tous les Spaces, design Liquid Glass natif Light/Dark.
  - Auto-fermeture des étagères vides (non épinglées) au clic extérieur ou fin de drag sans dépôt + repli auto de la liste en pile au clic extérieur.
  - Aimantation / repli sur les bords gauche & droit de l'écran en languette discrète (ressort au survol ou au drag) + masquer/afficher toutes les étagères depuis la barre de menu.
  - Drag-in universel : fichiers, dossiers, images en mémoire, URLs web (`.webloc`), extraits de texte (`.txt`).
  - Mode Pile (Stack avec vignettes inclinées + badge) et Mode Liste étendue.
  - Drag-out groupé (toute la pile d'un coup via `NSDraggingSession`) ou individuel + auto-fermeture après dépôt (sauf si épinglée).
- **Mises à jour automatiques (`UpdateChecker`) :** Vérification via GitHub Releases (`DjapsSparrow/shake-n-drop`), téléchargement & remplacement automatique, script `./tools/release.sh <version> "<notes>"`.
- **Actions intégrées :** Quick Look (`Espace` ou clic), Partage natif (`NSSharingServicePicker` : AirDrop/Mail/Messages), Compression ZIP (`/usr/bin/ditto`), Copier, Révéler dans le Finder.

## Validation
- `swift test` : 5/5 tests passés (`WebodropKitTests`).
- `./build.sh` : Release arm64 compilé sans warning, installé dans `~/Applications/Webodrop.app`.
- `--selftest` : 6/6 checks PASS.
- `APP_SNAPSHOT` : 6 captures Light & Dark vérifiées visuellement.

## Prochaines pistes (V2)
- Certificat Apple Development pour conserver la permission Accessibilité entre les rebuilds.
- Upload Cloud (Infomaniak S3 / lien public direct).
- Zone Encoche (Notch) & actions rapides locales (conversion d'images, OCR Vision).
