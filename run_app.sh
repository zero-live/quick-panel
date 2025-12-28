#!/bin/bash

echo "🔨 Building Quick Panel..."
cd "/Users/benxin/Code/Quick Panel"
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo ""
    echo "🚀 Launching Quick Panel..."

    # Find the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Quick_Panel-*/Build/Products/Debug -name "Quick Panel.app" -type d | head -n 1)

    if [ -n "$APP_PATH" ]; then
        echo "📍 App location: $APP_PATH"

        # Kill any existing instance
        pkill -f "Quick Panel" 2>/dev/null

        # Launch the app
        open "$APP_PATH"

        echo ""
        echo "✨ Quick Panel is now running!"
        echo "📋 Try clicking your middle mouse button"
        echo ""
        echo "💡 To see logs, run: log stream --predicate 'process == \"Quick Panel\"' --level debug"
    else
        echo "❌ Could not find built app"
    fi
else
    echo "❌ Build failed"
fi
