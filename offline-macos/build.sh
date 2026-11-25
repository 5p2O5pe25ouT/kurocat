#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
destination="$PWD/dist/KuroCat Offline.app"
if [[ -e "$destination" ]]; then
  echo "Output already exists: $destination" >&2
  exit 1
fi
stage=$(mktemp -d "$PWD/dist/offline-build.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/KuroCat Offline.app"
resources="$app/Contents/Resources"
mkdir -p "$resources/web" "$app/Contents/MacOS" "$stage/three"
# Only the renderer dependency from the upstream lockfile is needed.
archive="${KUROCAT_THREE_ARCHIVE:-$stage/three.tgz}"
if [[ -z "${KUROCAT_THREE_ARCHIVE:-}" ]]; then
  url=$(node -p "require('./package-lock.json').packages['node_modules/three'].resolved")
  curl --fail --location --proto '=https' --proto-redir '=https' -o "$archive" "$url"
fi
node - "$archive" <<'JS'
const { createHash } = require('node:crypto');
const { readFileSync } = require('node:fs');
const expected = require('./package-lock.json').packages['node_modules/three'].integrity;
const actual = 'sha512-' + createHash('sha512').update(readFileSync(process.argv[2])).digest('base64');
if (actual !== expected) throw Error('Three.js archive integrity mismatch');
JS
tar xzf "$archive" -C "$stage/three" --strip-components=1
bun run offline-macos/bundle.ts "$stage/three" "$resources/web"
cp offline-macos/index.html "$resources/web/"
cp offline-macos/Info.plist "$app/Contents/"
cp src-tauri/icons/icon.icns "$resources/"
cp LICENSE "$resources/KuroCat-LICENSE.txt"
cp "$stage/three/LICENSE" "$resources/Three-LICENSE.txt"
arch=$(uname -m)
swiftc -O -target "$arch-apple-macos14.0" offline-macos/{Pet,PetPanel,TypingPad,main}.swift -o "$app/Contents/MacOS/KuroCatOffline"
codesign --force --sign - --entitlements offline-macos/entitlements.plist "$app"
codesign --verify --strict "$app"
mv "$app" "$destination"
echo "$destination"
