#!/bin/zsh
# Builds Siqaman.app and installs it to /Applications (or $DEST). Needs only Command Line Tools + `brew install sevenzip`.
set -euo pipefail
cd "${0:A:h}"
DEST="${DEST:-/Applications}"
VERSION="$(cat VERSION)"
SEVENZ="$(readlink -f "$(command -v 7zz)")" || { echo "7zz missing: brew install sevenzip"; exit 1; }
APP=build/Siqaman.app

rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macos15 -swift-version 5 -enable-bare-slash-regex -parse-as-library \
  Sources/Siqaman/*.swift -o "$APP/Contents/MacOS/Siqaman"
cp "$SEVENZ" "$APP/Contents/MacOS/7zz"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

# Icon: mask the artwork, then fan out to an .icns
swiftc -O scripts/icon.swift -o build/icontool
build/icontool Resources/icon-source.png build/icon-1024.png
ICONSET=build/AppIcon.iconset && rm -rf $ICONSET && mkdir $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon-1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"   # ad-hoc: fine for this Mac

[[ "${1:-}" == "--no-install" ]] && { echo "Built $APP"; exit 0; }
pkill -x Siqaman 2>/dev/null || true
rm -rf "$DEST/Siqaman.app" && cp -R "$APP" "$DEST/"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST/Siqaman.app"
/System/Library/CoreServices/pbs -flush && /System/Library/CoreServices/pbs -update
echo "Installed $DEST/Siqaman.app — right-click files in Finder → Services → Compress/Extract with Siqaman"
