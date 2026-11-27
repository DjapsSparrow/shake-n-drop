#!/bin/zsh
# Construit Shake'n'Drop en Release, crée ShakeNDrop.zip et publie la GitHub Release.
# Usage : ./tools/release.sh 1.0.0 "Notes de version"
set -euo pipefail
here=${0:A:h:h}
version="${1:-}"
notes="${2:-Nouvelle version de Shake'n'Drop}"

if [[ -z "$version" ]]; then
  echo "Usage: ./tools/release.sh <version> [notes]"
  echo "Exemple: ./tools/release.sh 1.0.1 \"Correction du shake\""
  exit 1
fi

# 1. Met à jour CFBundleShortVersionString dans Info.plist.in
sed -i '' -E "s|<key>CFBundleShortVersionString</key><string>[^<]+</string>|<key>CFBundleShortVersionString</key><string>${version}</string>|" "$here/Info.plist.in"

# 2. Tests unitaires + build release + selftest
cd "$here"
swift test --scratch-path "$HOME/Library/Developer/Webodrop/test-build"
./build.sh
"/Applications/Shake'n'Drop.app/Contents/MacOS/Webodrop" --selftest

# 3. Archive propre macOS (.zip avec ressources préservées)
zip_path="/tmp/ShakeNDrop.zip"
rm -f "$zip_path"
ditto -c -k --sequesterRsrc --keepParent "/Applications/Shake'n'Drop.app" "$zip_path"

# 4. Commit de la version si Info.plist.in a changé + push
if ! git diff --quiet Info.plist.in; then
  git add Info.plist.in
  git commit -m "chore(release): bump version to v${version}"
fi
git push origin main

# 5. Création (ou mise à jour) de la GitHub Release
tag="v${version}"
if gh release view "$tag" >/dev/null 2>&1; then
  gh release upload "$tag" "$zip_path" --clobber
  gh release edit "$tag" --notes "$notes"
else
  gh release create "$tag" "$zip_path" --title "Shake'n'Drop ${tag}" --notes "$notes"
fi

echo "✅ Release ${tag} publiée sur GitHub !"
