#!/bin/zsh
# Génère /tmp/ShakeNDrop.dmg contenant Shake'n'Drop.app, un raccourci Applications
# et un mini-guide HTML illustré (ouvert sans blocage Gatekeeper).
set -euo pipefail

app_src="/Applications/Shake'n'Drop.app"
dmg_out="/tmp/ShakeNDrop.dmg"
staging=$(mktemp -d /tmp/shakendrop-dmg.XXXXXX)
trap 'rm -rf "$staging"' EXIT

if [[ ! -d "$app_src" ]]; then
  echo "Erreur: $app_src introuvable. Lancez ./build.sh d'abord."
  exit 1
fi

cp -R "$app_src" "$staging/Shake'n'Drop.app"
ln -s /Applications "$staging/Applications"

cat > "$staging/Lisez-moi — Installation.html" <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Installer Shake'n'Drop sur macOS</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      max-width: 640px;
      margin: 40px auto;
      padding: 0 24px;
      line-height: 1.55;
      background: Canvas;
      color: CanvasText;
    }
    h1 { font-size: 28px; margin-bottom: 6px; letter-spacing: -0.02em; }
    .subtitle { opacity: 0.72; margin-top: 0; margin-bottom: 28px; }
    .step {
      border: 1px solid color-mix(in srgb, CanvasText 14%, transparent);
      border-radius: 16px;
      padding: 18px 20px;
      margin-bottom: 16px;
      background: color-mix(in srgb, CanvasText 3%, transparent);
    }
    .step h2 { font-size: 16px; margin: 0 0 6px; display: flex; align-items: center; gap: 10px; }
    .badge {
      display: inline-flex; align-items: center; justify-content: center;
      width: 24px; height: 24px; border-radius: 999px;
      background: #5445EE; color: #fff; font-size: 13px; font-weight: 700;
    }
    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 13px;
      padding: 2px 6px;
      border-radius: 6px;
      background: color-mix(in srgb, CanvasText 8%, transparent);
    }
    .footer { margin-top: 28px; font-size: 13px; opacity: 0.75; }
    a { color: #5445EE; }
  </style>
</head>
<body>
  <h1>Installer Shake'n'Drop</h1>
  <p class="subtitle">Vos étagères flottantes macOS — gratuit, léger et 100 % natif.</p>

  <div class="step">
    <h2><span class="badge">1</span> Glisser dans Applications</h2>
    <p>Glissez <strong>Shake'n'Drop.app</strong> sur le dossier <strong>Applications</strong> dans la fenêtre du DMG, puis ouvrez-la depuis Applications.</p>
  </div>

  <div class="step">
    <h2><span class="badge">2</span> Autoriser la première ouverture (Gatekeeper)</h2>
    <p>Shake'n'Drop est une app indépendante non notarisée par Apple. Si macOS affiche une alerte à la première ouverture :</p>
    <p>Ouvrez <strong>Réglages Système → Confidentialité et sécurité</strong>, descendez tout en bas et cliquez sur <strong>Ouvrir quand même</strong> (demandé une seule fois).</p>
  </div>

  <div class="step">
    <h2><span class="badge">3</span> Activer le Shake-to-trigger (optionnel)</h2>
    <p>Pour secouer la souris depuis n'importe quelle app, autorisez Shake'n'Drop dans <strong>Réglages Système → Confidentialité et sécurité → Accessibilité</strong>. Le raccourci <code>⌥⇧D</code> et la barre de menu fonctionnent déjà sans aucune autorisation.</p>
  </div>

  <p class="footer">
    Une idée d'amélioration ou un bug ? Écrivez-nous à <a href="mailto:support@webomatik.fr?subject=%5BShake'n'Drop%5D%20Retour">support@webomatik.fr</a>.
  </p>
</body>
</html>
EOF

rm -f "$dmg_out"
hdiutil create -volname "Shake'n'Drop" -srcfolder "$staging" -ov -format UDZO "$dmg_out" >/dev/null
echo "wrote $dmg_out"
