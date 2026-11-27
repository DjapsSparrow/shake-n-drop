#!/bin/zsh
# Construit Shake'n'Drop en Release, génère ShakeNDrop.dmg + ShakeNDrop.zip
# et publie la GitHub Release.
# Usage : ./tools/release.sh 1.0.1 "Notes de version"
set -euo pipefail
here=${0:A:h:h}
version="${1:-}"
notes="${2:-Nouvelle version de Shake'n'Drop}"

if [[ -z "$version" ]]; then
  echo "Usage: ./tools/release.sh <version> [notes]"
  echo "Exemple: ./tools/release.sh 1.0.1 \"Guide d'accueil et feedback\""
  exit 1
fi

# 1. Met à jour CFBundleShortVersionString dans Info.plist.in
sed -i '' -E "s|<key>CFBundleShortVersionString</key><string>[^<]+</string>|<key>CFBundleShortVersionString</key><string>${version}</string>|" "$here/Info.plist.in"

# 2. Tests unitaires + build release + selftest
cd "$here"
swift test --scratch-path "$HOME/Library/Developer/Webodrop/test-build"
./build.sh
"/Applications/Shake'n'Drop.app/Contents/MacOS/Webodrop" --selftest

# 3. Archive .zip (pour l'auto-updater) + image .dmg (pour l'installation humaine avec tuto)
zip_path="/tmp/ShakeNDrop.zip"
dmg_path="/tmp/ShakeNDrop.dmg"
rm -f "$zip_path" "$dmg_path"
ditto -c -k --sequesterRsrc --keepParent "/Applications/Shake'n'Drop.app" "$zip_path"
"$here/tools/make_dmg.sh"

# 4. Commit de la version si Info.plist.in a changé + push
if ! git diff --quiet Info.plist.in; then
  git add Info.plist.in
  git commit -m "chore(release): bump version to v${version}"
fi
git push origin main

# 5. Création (ou mise à jour) de la GitHub Release avec .dmg et .zip
tag="v${version}"
if gh release view "$tag" >/dev/null 2>&1; then
  gh release upload "$tag" "$dmg_path" "$zip_path" --clobber
  gh release edit "$tag" --notes "$notes"
else
  gh release create "$tag" "$dmg_path" "$zip_path" --title "Shake'n'Drop ${tag}" --notes "$notes"
fi

echo "✅ Release ${tag} publiée sur GitHub (ShakeNDrop.dmg + ShakeNDrop.zip) !"
