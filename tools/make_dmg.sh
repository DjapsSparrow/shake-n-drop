#!/bin/zsh
# Génère /tmp/ShakeNDrop.dmg propre contenant uniquement Shake'n'Drop.app
# et le raccourci Applications (le parcours d'installation guidé est directement intégré dans l'app).
set -euo pipefail

app_src="${APP_DEST:-/Applications/Shake'n'Drop.app}"
dmg_out="/tmp/ShakeNDrop.dmg"
staging=$(mktemp -d /tmp/shakendrop-dmg.XXXXXX)
trap 'rm -rf "$staging"' EXIT

if [[ ! -d "$app_src" ]]; then
  echo "Erreur: $app_src introuvable. Lancez ./build.sh d'abord."
  exit 1
fi

cp -R "$app_src" "$staging/Shake'n'Drop.app"
ln -s /Applications "$staging/Applications"

rm -f "$dmg_out"
hdiutil create -volname "Shake'n'Drop" -srcfolder "$staging" -ov -format UDZO "$dmg_out" >/dev/null
echo "wrote $dmg_out"
