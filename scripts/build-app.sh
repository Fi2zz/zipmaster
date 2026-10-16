#!/usr/bin/env bash
# 组装一个本机可运行的 ZipMaster.app（ad-hoc 签名，用于自用/开发，不分发）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> swift build -c release"
swift build -c release

BIN=".build/release/ZipMaster"
APP="ZipMaster.app"
ENGINES_SRC="$ROOT/Sources/ZipMaster/Resources/Engines"

if [ ! -x "$BIN" ]; then
    echo "error: 未找到可执行 $BIN" >&2
    exit 1
fi

if [ ! -x "$ENGINES_SRC/7zz" ] || [ ! -x "$ENGINES_SRC/unrar" ]; then
    echo "warning: 引擎二进制缺失，请先运行 scripts/build-engines.sh（App 仍会构建，但压缩/解压不可用）" >&2
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/ZipMaster"

# 引擎二进制随包分发
if [ -d "$ENGINES_SRC" ]; then
    mkdir -p "$APP/Contents/Resources/Engines"
    for e in 7zz unrar; do
        if [ -f "$ENGINES_SRC/$e" ]; then
            cp "$ENGINES_SRC/$e" "$APP/Contents/Resources/Engines/$e"
            chmod +x "$APP/Contents/Resources/Engines/$e"
        fi
    done
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ZipMaster</string>
  <key>CFBundleDisplayName</key><string>ZipMaster</string>
  <key>CFBundleExecutable</key><string>ZipMaster</string>
  <key>CFBundleIdentifier</key><string>com.example.zipmaster</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
if [ -d "$APP/Contents/Resources/Engines" ]; then
    for f in "$APP/Contents/Resources/Engines/"*; do
        [ -f "$f" ] && codesign --force -s - "$f"
    done
fi
codesign --force -s - "$APP"

echo "==> built $(pwd)/$APP"
