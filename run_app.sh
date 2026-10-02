#!/bin/bash

set -u

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_PATH="Quick Panel/Quick Panel.xcodeproj"
SCHEME="Quick Panel"
CONFIGURATION="Debug"
REQUIREMENTS_PATH="$PROJECT_DIR/Quick Panel/Quick_Panel_Debug.requirements"

extract_build_setting() {
    local key="$1"
    printf "%s\n" "$BUILD_SETTINGS" | awk -F' = ' -v key="$key" '$1 ~ "^[[:space:]]*" key "$" { print $2; exit }'
}

echo "🔨 Building Quick Panel..."
cd "$PROJECT_DIR" || exit 1
xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" build

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo ""
    echo "🔍 Resolving build product..."

    BUILD_SETTINGS=$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null)
    TARGET_BUILD_DIR=$(extract_build_setting "TARGET_BUILD_DIR")
    FULL_PRODUCT_NAME=$(extract_build_setting "FULL_PRODUCT_NAME")
    PRODUCT_BUNDLE_IDENTIFIER=$(extract_build_setting "PRODUCT_BUNDLE_IDENTIFIER")

    APP_PATH="$TARGET_BUILD_DIR/$FULL_PRODUCT_NAME"

    if [ -z "$TARGET_BUILD_DIR" ] || [ -z "$FULL_PRODUCT_NAME" ] || [ ! -d "$APP_PATH" ]; then
        echo "❌ Could not resolve built app path"
        exit 1
    fi

    if [ -z "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
        echo "❌ Could not resolve product bundle identifier"
        exit 1
    fi

    echo "📍 App location: $APP_PATH"

    if [ "${QUICK_PANEL_SKIP_STABLE_ADHOC_SIGN:-0}" != "1" ]; then
        CONFIGURATION="$CONFIGURATION" \
            TARGET_BUILD_DIR="$TARGET_BUILD_DIR" \
            FULL_PRODUCT_NAME="$FULL_PRODUCT_NAME" \
            QUICK_PANEL_REQUIREMENTS_PATH="$REQUIREMENTS_PATH" \
            "$PROJECT_DIR/sign_debug_app.sh" || exit 1
    else
        echo "⚠️  Ad-hoc signing left unchanged; Accessibility permission may reset after rebuilds."
    fi

    echo ""
    echo "🚀 Launching Quick Panel..."

    # Kill any existing app instance before launching the freshly built product.
    pkill -x "Quick Panel" 2>/dev/null

    # Launch the app
    open "$APP_PATH"

    echo ""
    echo "✨ Quick Panel is now running!"
    echo "📋 Try clicking your middle mouse button"
    echo ""
    echo "💡 To see logs, run: log stream --predicate 'process == \"Quick Panel\"' --level debug"
else
    echo "❌ Build failed"
    exit 1
fi
