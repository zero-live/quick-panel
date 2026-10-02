#!/bin/bash

set -euo pipefail

ICON_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd "$ICON_DIR/../.." && pwd)
APPICON_DIR="$REPO_DIR/Quick Panel/Quick Panel/Assets.xcassets/AppIcon.appiconset"
SOURCE_PATH="$ICON_DIR/app-icon-source.png"

# Export only: preserve the generated symbol and alpha while resizing.
sips -z 1024 1024 "$SOURCE_PATH" --out "$ICON_DIR/app-icon-1024.png" >/dev/null

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_DIR/app-icon-1024.png" \
        --out "$APPICON_DIR/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$ICON_DIR/app-icon-1024.png" \
        --out "$APPICON_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

cp "$ICON_DIR/app-icon-1024.png" "$REPO_DIR/logo/Quick Panel.png"
echo "✅ 已导出 macOS AppIcon 全部尺寸与项目 Logo。"
