# Webodrop

Mini-application macOS native (Swift 6, SwiftUI, AppKit) qui fait surgir des étagères flottantes temporaires pour collecter, prévisualiser, combiner et glisser-déposer des fichiers, images, liens et textes entre n'importe quelles applications — exactement comme Dropover.

## Remplace
Dropover (app payante) et les allers-retours pénibles entre fenêtres Finder, navigateurs et messageries.

## Missions principales (V1)
1. **Déclencher une étagère instantanément** : secouer le curseur pendant un glisser-déposer (*Shake-to-trigger*), raccourci clavier global (`⌥⇧D`), ou glisser/cliquer sur l'icône de la barre de menu.
2. **Collecter & empiler sans perdre le focus** : plusieurs étagères flottantes *always-on-top* (`.nonactivatingPanel`), visibles sur tous les bureaux/Spaces, acceptant fichiers, dossiers, images, URLs et extraits de texte, affichés en pile de vignettes (Stack) ou en liste détaillée.
3. **Agir & redéposer en un geste** : glisser-déposer groupé (toute l'étagère d'un coup) ou individuel, Quick Look natif (`Espace`), compression ZIP en 1 clic, partage natif (AirDrop, Mail, Messages), copie (fichiers/texte/chemins), révéler dans le Finder et auto-fermeture optionnelle après dépôt.

## Données
- `Shelf` : identifiant, titre optionnel, position écran, liste d'éléments (`ShelfItem`), état (pile / étendu / épinglé).
- `ShelfItem` : identifiant, type (fichier/dossier, image temporaire, URL, texte), URL locale ou contenu, nom d'affichage, taille, miniature (QuickLook / NSWorkspace).
- Réglages (`@AppStorage`) : sensibilité du shake, activation du shake, raccourci global, auto-fermeture après drag-out, lancement à l'ouverture de session, taille des étagères.

## Forme
Application **barre de menu** (`LSUIElement = YES`, pas d'icône dans le Dock par défaut, optionnable) + panneaux flottants translucides (`NSPanel` Liquid Glass / HUD natif macOS 26/27) + fenêtre Réglages native. 100 % locale, hors-ligne, zéro compte, < 20 Mo RAM, 0 % CPU au repos.

## Intégrations Système macOS
- Détecteur de secousse souris pendant le drag (`NSEvent.addGlobalMonitorForEvents` `.leftMouseDragged` + détection changement de direction rapide)
- Raccourci global sans permission (`Carbon RegisterEventHotKey`)
- `NSStatusItem` (barre de menu) avec zone de drop directe + menu natif
- `QLPreviewPanel` (Quick Look natif)
- `NSSharingServicePicker` (AirDrop & partage système)
- `SMAppService.mainApp` (lancement au démarrage)
- Schéma d'URL `webodrop://action/<name>` pour tests et automatisation

## Référence
Dropover (`https://dropoverapp.com/`)

## Direction Visuelle
100 % natif macOS 26/27 (Liquid Glass / matériaux translucides adaptatifs Clair & Sombre, SF Pro, SF Symbols natifs, grille 4/8pt, zéro hex rigide).

## Hors périmètre V1 (V2+)
- Upload Cloud (Infomaniak S3, Dropbox, Google Drive, liens publics)
- Zone Encoche (Notch) & touche modificatrice pendant le drag
- Conversion/redimensionnement d'images & OCR Vision
