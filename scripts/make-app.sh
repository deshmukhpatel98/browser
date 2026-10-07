#!/bin/bash
# Builds the Mac app and wraps it as build/Browser.app.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/Browser.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/BrowserMac "$APP/Contents/MacOS/Browser"

# The icon is drawn by the app itself, so the logo lives in one place.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET" "$APP/Contents/Resources"
.build/release/BrowserMac --export-icon build/icon.png
for size in 16 32 128 256 512; do
  sips -z $size $size build/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) build/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Browser</string>
  <key>CFBundleIdentifier</key><string>com.deveshpatel.browser</string>
  <key>CFBundleExecutable</key><string>Browser</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
# Sign with the Apple developer identity on this Mac when there is one.
# RELEASE=1 signs for sharing with other people and makes build/Browser.zip.
if [ "${RELEASE:-}" = 1 ]; then
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  rm -f build/Browser.zip
  ditto -c -k --keepParent "$APP" build/Browser.zip
else
  IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)
  codesign --force --sign "${IDENTITY:--}" "$APP"
fi
echo "Built $APP"
