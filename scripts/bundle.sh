#!/bin/sh
# Builds "Keyboard Cleaner.app" into ./build.
# Signs with the first "Apple Development" identity if present (keeps the
# Accessibility permission across rebuilds); falls back to ad-hoc signing.
set -eu
cd "$(dirname "$0")/.."

APP="build/Keyboard Cleaner.app"
VERSION="${VERSION:-$(cat VERSION)}"

# UNIVERSAL=1 builds for Apple Silicon + Intel.
ARCH_ARGS=""
[ "${UNIVERSAL:-0}" = 1 ] && ARCH_ARGS="--arch arm64 --arch x86_64"
swift build -c release --product KeyboardCleaner $ARCH_ARGS
BIN="$(swift build -c release --show-bin-path $ARCH_ARGS)/KeyboardCleaner"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/KeyboardCleaner"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

# Icon
if [ ! -f build/AppIcon.icns ] || [ scripts/make-icon.swift -nt build/AppIcon.icns ]; then
    ICONSET=build/AppIcon.iconset
    rm -rf "$ICONSET" && mkdir -p "$ICONSET"
    swift scripts/make-icon.swift build/icon-1024.png
    for s in 16 32 128 256 512; do
        sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        d=$((s * 2))
        sips -z $d $d build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -p codesigning -v 2>/dev/null \
    | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)}"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (v$VERSION, signed: ${IDENTITY:-ad-hoc})"
