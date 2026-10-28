#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
IDENTITY="${EDGESHIFT_SIGNING_IDENTITY:-}"
BUNDLE_ID="${EDGESHIFT_BUNDLE_ID:-com.edgeshift.app}"
RESET_INPUT_MONITORING="${EDGESHIFT_RESET_INPUT_MONITORING:-1}"
if [[ "$RESET_INPUT_MONITORING" != "0" && "$RESET_INPUT_MONITORING" != "1" ]]; then
    echo "EDGESHIFT_RESET_INPUT_MONITORING must be 0 or 1." >&2
    exit 1
fi
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
<key>CFBundleShortVersionString</key><string>0.1.8</string>
<key>CFBundleVersion</key><string>9</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
codesign --force --deep --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
if [[ "$RESET_INPUT_MONITORING" == "1" ]]; then
    echo "Resetting Input Monitoring authorization for $BUNDLE_ID (all copies with this bundle ID)."
    # A fresh bundle ID must be known to Launch Services before tccutil accepts it.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
    if ! tccutil reset ListenEvent "$BUNDLE_ID"; then
        echo "Input Monitoring reset failed; check macOS privacy settings." >&2
        exit 1
    fi
    echo "Start or restart the app to request authorization; approve it in System Settings."
else
    echo "Input Monitoring reset skipped."
fi
