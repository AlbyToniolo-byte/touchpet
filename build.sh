#!/bin/sh
# Compila "TouchPet.app" (con icona) nella cartella corrente. `./build.sh install` la copia anche in Applicazioni e la avvia.
set -e
cd "$(dirname "$0")"
APP="TouchPet.app"
# private.h dichiara le funzioni private della Touch Bar, DFRFoundation è la libreria di sistema che le contiene
FLAGS="-import-objc-header private.h -F /System/Library/PrivateFrameworks -framework DFRFoundation"
TMP=$(mktemp -d)

swiftc main.swift $FLAGS -o "$TMP/selftest" && "$TMP/selftest" --selftest # build di debug: gli assert sono attivi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift $FLAGS -o "$APP/Contents/MacOS/TouchPet"

# icona: l'app disegna un PNG 1024x1024, poi lo riduciamo a tutte le misure richieste da macOS
mkdir "$TMP/AppIcon.iconset"
"$APP/Contents/MacOS/TouchPet" --icon "$TMP/icon.png"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>TouchPet</string>
  <key>CFBundleExecutable</key><string>TouchPet</string>
  <key>CFBundleIdentifier</key><string>local.touchpet</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
EOF

codesign --force --sign - "$APP" # firma locale: necessaria sui Mac Apple Silicon
rm -rf "$TMP"

if [ "$1" = "install" ]; then # l'avvio all'accesso punta a questa copia: deve stare in un posto fisso
  pkill -x TouchPet || true
  rm -rf "/Applications/$APP"
  ditto "$APP" "/Applications/$APP"
  open "/Applications/$APP"
  echo "Installata e avviata: /Applications/$APP"
else
  echo "Fatto: open \"$APP\""
fi
