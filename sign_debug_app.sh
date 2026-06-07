#!/bin/bash

set -u

CONFIGURATION_VALUE="${CONFIGURATION:-Debug}"

if [ "${ACTION:-build}" = "clean" ]; then
    exit 0
fi

if [ "$CONFIGURATION_VALUE" != "Debug" ]; then
    exit 0
fi

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FULL_PRODUCT_NAME:-}" ]; then
    APP_PATH="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"
elif [ $# -ge 1 ]; then
    APP_PATH="$1"
else
    echo "❌ Missing app path or TARGET_BUILD_DIR/FULL_PRODUCT_NAME." >&2
    exit 1
fi

if [ -n "${QUICK_PANEL_REQUIREMENTS_PATH:-}" ]; then
    REQUIREMENTS_PATH="$QUICK_PANEL_REQUIREMENTS_PATH"
elif [ -n "${PROJECT_DIR:-}" ]; then
    REQUIREMENTS_PATH="$PROJECT_DIR/Quick_Panel_Debug.requirements"
else
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    REQUIREMENTS_PATH="$SCRIPT_DIR/Quick Panel/Quick_Panel_Debug.requirements"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found: $APP_PATH" >&2
    exit 1
fi

if [ ! -f "$REQUIREMENTS_PATH" ]; then
    echo "❌ Requirements file not found: $REQUIREMENTS_PATH" >&2
    exit 1
fi

SIGNATURE=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 | awk -F= '/^Signature=/{print $2; exit }')

if [ "$SIGNATURE" != "adhoc" ]; then
    exit 0
fi

echo "🔐 Stabilizing Debug app code requirement..."

if codesign --force --sign - --preserve-metadata=entitlements --requirements "$REQUIREMENTS_PATH" "$APP_PATH" &&
    codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null; then
    echo "✅ Stable Debug requirement applied."
else
    echo "❌ Failed to apply stable Debug requirement." >&2
    exit 1
fi
