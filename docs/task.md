# Backlog — Shake'n'Drop

## ✅ V1 Livrée (`v1.0.20` — GitHub Releases)
- [x] Moteur multi-étagères flottantes Liquid Glass (`ShelfPanel`, `ShelfView`, `ShelfDragBridge`)
- [x] Déclencheurs : Shake-to-trigger (filtré sur vrai drag `.drag`), Raccourci global `⌥⇧D` (Carbon), Barre de menu avec drop direct
- [x] Raccourcis URL `.webloc` tous navigateurs (titre de page, favicon, ouverture au clic)
- [x] Actions : Quick Look (`Espace`), AirDrop / Partage natif, Compression ZIP, Copier, Révéler dans le Finder
- [x] Repli sur le bord gauche/droit en languette `40×96` via bouton dédié `⇤`/`⇥`
- [x] Compatibilité macOS 14 Sonoma, macOS 15 Sequoia et macOS 26/27+
- [x] Icône Liquid Glass sur-mesure (*Curseur qui vibre*) + picto barre de menu 18×18 assorti
- [x] Auto-updater GitHub Releases + fenêtre native de nouveautés + Historique des versions (`ChangelogView`)
- [x] Parcours d'installation 2 étapes intégré (copie `/Applications` + Dock) + DMG épuré
- [x] Formulaire natif Idée / Bug intégré (`WKWebView` + GitHub Pages + Web3Forms → `support@webomatik.fr`)
- [x] Zéro permission Accessibilité requise

## 🔜 Pistes V2 (selon retours utilisateurs)
- [ ] Actions rapides locales sur images (redimensionner, convertir WebP/PNG/JPG, OCR Vision)
- [ ] Upload Cloud direct (Infomaniak S3 / lien public)
- [ ] Zone Encoche (Notch) & touche modificatrice pendant le drag
- [ ] Compte Apple Developer (Developer ID + notarisation) ou build dédié Mac App Store (`#if !APPSTORE`)
- [ ] Version Windows (C#/.NET 8 via GitHub Actions) quand un testeur Windows sera disponible
