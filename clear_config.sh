#!/bin/bash

# Clear Quick Panel configuration
# This will remove all saved items and reset the panel to empty state

CONFIG_DIR="$HOME/Library/Application Support/Quick Panel"
CONFIG_FILE="$CONFIG_DIR/config.json"

echo "🗑️  Quick Panel Configuration Cleaner"
echo "===================================="
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo "📁 Found config file: $CONFIG_FILE"
    echo ""
    read -p "Are you sure you want to delete all saved items? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$CONFIG_FILE"
        echo "✅ Configuration cleared successfully!"
        echo "💡 The panel will be empty on next launch. You can add your own apps and websites."
    else
        echo "❌ Operation cancelled."
    fi
else
    echo "📭 No configuration file found. The panel is already empty."
fi

echo ""
echo "Done."
