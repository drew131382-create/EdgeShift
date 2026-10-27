#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
IDENTITY="${EDGESHIFT_SIGNING_IDENTITY:-}"
BUNDLE_ID="${EDGESHIFT_BUNDLE_ID:-com.edgeshift.app}"
if [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
    echo "Invalid EDGESHIFT_BUNDLE_ID." >&2
    exit 1
fi
if [[ -z "$IDENTITY" ]]; then
    identities=$(security find-identity -v -p codesigning | awk '/"Apple Development:/{print $2}')
    if [[ $(printf '%s\n' "$identities" | awk 'NF {n++} END {print n+0}') -eq 1 ]]; then
        IDENTITY="$identities"
    else
        echo "No unique Apple Development identity found. Set EDGESHIFT_SIGNING_IDENTITY to a signing identity, or explicitly use '-' for local ad-hoc builds." >&2
        exit 1
    fi
fi
swift build -c release
APP="$PWD/build/EdgeShift.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/EdgeShift "$APP/Contents/MacOS/EdgeShift"
# Remove local build paths and nonessential symbols before signing.
strip -S -x "$APP/Contents/MacOS/EdgeShift"
python3 - "$PWD/Assets/AppIcon.png" "$APP/Contents/Resources/AppIcon.icns" <<'PY'
import pathlib, subprocess, sys, tempfile
source, output = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix='edgeshift-icon-') as tmp:
    iconset = pathlib.Path(tmp) / 'AppIcon.iconset'
    iconset.mkdir()
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
            subprocess.run(['sips', '-z', str(size * scale), str(size * scale), source,
                            '--out', str(iconset / name)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', output], check=True)
PY
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>EdgeShift</string>
<key>CFBundleIdentifier</key><string>com.edgeshift.app</string>
<key>CFBundleName</key><string>EdgeShift</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.5</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
codesign --force --deep --sign "$IDENTITY" "$APP"
echo "Built $APP"
