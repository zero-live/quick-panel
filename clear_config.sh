#!/bin/bash

# Clear Quick Panel configuration
# This will remove all saved data and reset the app to default state

CONFIG_DIR="$HOME/Library/Application Support/Quick Panel"
FILES_TO_CLEAR=(
    "$CONFIG_DIR/config.json"
    "$CONFIG_DIR/settings.json"
    "$CONFIG_DIR/groups.json"
    "$CONFIG_DIR/pagecounts.json"
)

echo "🗑️  Quick Panel Configuration Cleaner"
echo "===================================="
echo ""

existing_files=()
for file in "${FILES_TO_CLEAR[@]}"; do
    if [ -f "$file" ]; then
        existing_files+=("$file")
    fi
done

if [ ${#existing_files[@]} -gt 0 ]; then
    echo "📁 Found configuration files:"
    for file in "${existing_files[@]}"; do
        echo "   - $file"
    done
    echo ""
    read -p "Are you sure you want to delete all saved data and reset the app? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in "${existing_files[@]}"; do
            rm "$file"
        done
        echo "✅ Configuration cleared successfully!"
        echo "💡 Items, settings, page groups, and page counts will be recreated with defaults on next launch."
    else
        echo "❌ Operation cancelled."
    fi
else
    echo "📭 No configuration files found. The app is already using default state."
fi

echo ""
echo "Done."
