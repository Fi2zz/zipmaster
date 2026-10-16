#!/usr/bin/env bash
# 为本机（Apple Silicon）原生构建 arm64 引擎：7zz（7-Zip）与 unrar。
# 幂等：产物已存在则跳过对应步骤。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/Sources/ZipMaster/Resources/Engines"
mkdir -p "$OUT"

SEVENZIP_REPO="https://github.com/ip7z/7zip"
UNRAR_URL="https://www.rarlab.com/rar/unrarsrc-7.3.1.tar.gz"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

NCPU="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# --- 7-Zip → 7zz ---
if [ -x "$OUT/7zz" ]; then
    echo "==> 7zz 已存在，跳过"
else
    echo "==> 克隆并构建 7zz"
    git clone --depth 1 "$SEVENZIP_REPO" "$WORK/7zip"
    BUNDLE="$WORK/7zip/CPP/7zip/Bundles/Alone2"
    make -C "$BUNDLE" -f makefile.gcc -j"$NCPU"
    BIN7="$(find "$BUNDLE" -type f -name 7zz -perm -111 | head -1)"
    if [ -z "$BIN7" ]; then
        echo "error: 未找到构建出的 7zz" >&2
        exit 1
    fi
    cp "$BIN7" "$OUT/7zz"
    chmod +x "$OUT/7zz"
fi

# --- unrar ---
if [ -x "$OUT/unrar" ]; then
    echo "==> unrar 已存在，跳过"
else
    echo "==> 下载并构建 unrar"
    curl -fsSL "$UNRAR_URL" -o "$WORK/unrarsrc.tar.gz"
    tar -xzf "$WORK/unrarsrc.tar.gz" -C "$WORK"
    SRC="$(find "$WORK" -maxdepth 1 -type d -name 'unrar*' | head -1)"
    make -C "$SRC" -f makefile \
        CXXFLAGS="-O2 -D_FILE_OFFSET_BITS=64 -D_MACOSX" \
        -j"$NCPU"
    cp "$SRC/unrar" "$OUT/unrar"
    chmod +x "$OUT/unrar"
fi

echo "==> 引擎产物:"
ls -la "$OUT"
