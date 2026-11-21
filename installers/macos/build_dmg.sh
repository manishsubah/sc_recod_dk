#!/usr/bin/env bash
# Builds installers/output/RecLite-<version>-macos.dmg (run on a Mac).
#
#   installers/macos/build_dmg.sh
#   FLUTTER=/path/to/flutter installers/macos/build_dmg.sh
#
# Needs Flutter 3.47.1 and Xcode. The app stays ad-hoc signed: never configure the
# company (12th Wonder) Apple team. Other Macs show a Gatekeeper warning until the
# app is signed with a Developer ID and notarised (see docs/PLAN.md, Phase 4).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
flutter="${FLUTTER:-flutter}"

version="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+.*/\1/p' "$root/pubspec.yaml")"
if [[ -z "$version" ]]; then
  echo 'pubspec.yaml has no "version: x.y.z+build" line.' >&2
  exit 1
fi
echo "RecLite $version"

if [[ "${1:-}" != "--skip-build" ]]; then
  (cd "$root" && "$flutter" build macos --release)
fi

app="$root/build/macos/Build/Products/Release/RecLite.app"
[[ -d "$app" ]] || { echo "No release build at $app" >&2; exit 1; }

output="$root/installers/output"
dmg="$output/RecLite-$version-macos.dmg"
mkdir -p "$output"
rm -f "$dmg"

# The window that opens shows RecLite, an Applications shortcut (drag to install) and
# the license agreement.
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
cp "$root/installers/LICENSE.txt" "$staging/License.txt"
ln -s /Applications "$staging/Applications"

hdiutil create -volname "RecLite $version" -srcfolder "$staging" -ov -format UDZO "$dmg"
echo "Done: $dmg ($(du -h "$dmg" | cut -f1))"
