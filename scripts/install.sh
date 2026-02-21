#!/bin/bash
set -e

APP_NAME="Ponyo"
BUNDLE_ID="com.ponyo.app"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Building ${APP_NAME}..."
swift build -c release --package-path "${PROJECT_DIR}"

echo "Creating app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

cp "${PROJECT_DIR}/.build/release/${APP_NAME}" "${MACOS}/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Ponyo</string>
    <key>CFBundleIdentifier</key>
    <string>com.ponyo.app</string>
    <key>CFBundleName</key>
    <string>Ponyo</string>
    <key>CFBundleDisplayName</key>
    <string>Ponyo</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
PLIST

# Generate app icon from PNG if available
ICON_PNG="${PROJECT_DIR}/Resources/AppIcon.png"
if [ -f "${ICON_PNG}" ]; then
    echo "Generating app icon from ${ICON_PNG}..."
    ICONSET="${PROJECT_DIR}/Resources/AppIcon.iconset"
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"

    # Ensure source is real PNG format (handles JPEG with .png extension)
    ICON_REAL_PNG="${PROJECT_DIR}/Resources/.AppIcon_converted.png"
    sips -s format png "${ICON_PNG}" --out "${ICON_REAL_PNG}" >/dev/null 2>&1

    sips -s format png -z 16 16     "${ICON_REAL_PNG}" --out "${ICONSET}/icon_16x16.png"      >/dev/null 2>&1
    sips -s format png -z 32 32     "${ICON_REAL_PNG}" --out "${ICONSET}/icon_16x16@2x.png"   >/dev/null 2>&1
    sips -s format png -z 32 32     "${ICON_REAL_PNG}" --out "${ICONSET}/icon_32x32.png"      >/dev/null 2>&1
    sips -s format png -z 64 64     "${ICON_REAL_PNG}" --out "${ICONSET}/icon_32x32@2x.png"   >/dev/null 2>&1
    sips -s format png -z 128 128   "${ICON_REAL_PNG}" --out "${ICONSET}/icon_128x128.png"    >/dev/null 2>&1
    sips -s format png -z 256 256   "${ICON_REAL_PNG}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null 2>&1
    sips -s format png -z 256 256   "${ICON_REAL_PNG}" --out "${ICONSET}/icon_256x256.png"    >/dev/null 2>&1
    sips -s format png -z 512 512   "${ICON_REAL_PNG}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null 2>&1
    sips -s format png -z 512 512   "${ICON_REAL_PNG}" --out "${ICONSET}/icon_512x512.png"    >/dev/null 2>&1
    sips -s format png -z 1024 1024 "${ICON_REAL_PNG}" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null 2>&1
    rm -f "${ICON_REAL_PNG}"

    iconutil --convert icns "${ICONSET}" --output "${RESOURCES}/AppIcon.icns"
    rm -rf "${ICONSET}"
    echo "App icon installed."
else
    echo "No AppIcon.png found in Resources/. Skipping icon generation."
fi

echo "Codesigning..."
codesign --force --sign - --entitlements "${PROJECT_DIR}/Ponyo.entitlements" "${MACOS}/${APP_NAME}"
codesign --force --sign - "${APP_DIR}"

echo "Done! Installed to ${APP_DIR}"
echo "Opening ${APP_NAME}..."
open "${APP_DIR}"
