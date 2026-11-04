#!/bin/zsh
# Builds Siqaman.app and installs it to /Applications (or $DEST). Needs only Command Line Tools.
set -euo pipefail
cd "${0:A:h}"
DEST="${DEST:-/Applications}"
VERSION="$(cat VERSION)"
APP=build/Siqaman.app

# Official 7-Zip build: Homebrew's 7zz ships without the RAR codec ("Unsupported Method" on every RAR file).
SEVENZ_VER=2604 SEVENZ_SHA=bee04358cbcbc7106273cee0e8d72916db2696c48067a3538c34d8cd6fd16578
SEVENZ=build/7zz-$SEVENZ_VER
if [[ ! -x $SEVENZ ]]; then
  mkdir -p build && curl -fsSL "https://www.7-zip.org/a/7z$SEVENZ_VER-mac.tar.xz" -o build/7z.tar.xz
  echo "$SEVENZ_SHA  build/7z.tar.xz" | shasum -a 256 -c - >/dev/null || { echo "7-Zip download checksum mismatch"; exit 1; }
  tar -xOf build/7z.tar.xz 7zz > $SEVENZ && chmod +x $SEVENZ && rm build/7z.tar.xz
fi
$SEVENZ i | grep -qE '^ +D +[0-9]+ +Rar5$' || { echo "bundled 7zz lacks the RAR codec"; exit 1; }

rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macos15 -swift-version 5 -enable-bare-slash-regex -parse-as-library \
  Sources/Siqaman/*.swift -o "$APP/Contents/MacOS/Siqaman"
cp "$SEVENZ" "$APP/Contents/MacOS/7zz"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/Fonts Resources/ertagakech-logo.svg "$APP/Contents/Resources/"

# Icon: drawn in code, then fanned out to an .icns
swiftc -O scripts/icon.swift -o build/icontool
build/icontool build/icon-1024.png
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
