# CLAUDE.md

This file provides a code-oriented summary of the current Quick Panel repository state.

## Project Overview

Quick Panel is a macOS quick-launch panel app implemented with SwiftUI and AppKit. It runs as a background accessory app with a menu bar entry, listens for middle-click input, and shows a floating panel near the cursor for launching apps or opening websites.

The current shipped implementation is not a plain SwiftUI `WindowGroup` app. It uses:

- `@NSApplicationDelegateAdaptor(AppDelegate.self)` as the real startup path
- `NSPanel` for the main floating panel
- dedicated `NSWindow` managers for settings, about, add-item, and edit-item windows
- singleton service objects for most shared functionality

## Current Version

- Marketing version: `1.3.0`
- Build number: `11`
- Bundle identifier: `com.benxin.Quick-Panel`
- Deployment target: `macOS 26.2`
- No third-party dependencies
- No test target

## Build Commands

### Build

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build
```

### Build and Run

```bash
./run_app.sh
```

### Clean

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" clean
```

### Logs

```bash
log stream --predicate 'process == "Quick Panel"' --level debug
```

## Effective App Flow

### Startup

`Quick_PanelApp.swift` intentionally suppresses the default SwiftUI window:

- app scene is `Settings { EmptyView() }`
- real initialization happens in `AppDelegate.applicationDidFinishLaunching`

`AppDelegate` currently does the following:

- prevents duplicate launch handling in-process
- checks for multiple running instances by bundle identifier
- closes the default window if any
- sets activation policy to `.accessory`
- loads settings
- creates the status bar item
- applies launch-at-login if enabled in saved settings
- initializes `PanelWindowManager`
- starts middle-click monitoring
- starts global hotkey monitoring
- performs a silent update check after 5 seconds

## Main UI Architecture

### Active Main Panel

The active main panel is `PanelView.swift`, hosted inside `PanelWindowManager`.

Current behavior:

- upper layer: common items
- lower layer: items filtered by current frontmost app bundle identifier
- both layers support independent page counts
- scroll wheel events are routed per layer
- empty slots open the add-item window
- items can be edited via context menu
- items can be reordered by drag-and-drop swapping
- page groups can be named per page

### Window Types

- `PanelWindowManager`: floating `NSPanel`
- `SettingsWindowManager`: settings window
- `AboutWindowManager`: about window
- `AddItemWindowManager`: add-item and edit-item windows

### Inactive / Legacy Views

- `ContentView.swift` is unused scaffold code
- `Views/NewPanelView.swift` is an older or experimental panel UI and is not the current runtime path

## Core Services

### Data and Settings

- `DataManager`
  - persists `config.json`, `groups.json`, `pagecounts.json`
  - owns `items`, `pageGroups`, and `pageCounts`
- `SettingsManager`
  - persists `settings.json`
  - validates grid, spacing, size, and opacity values
  - posts `.settingsDidChange`

### Launch and Integration

- `AppLauncher`
  - launches local apps
  - opens websites
  - supports optional `browserPath`, though the UI does not currently expose a browser picker
- `IconFetcher`
  - normalizes URLs
  - tries direct favicon URLs on the target site
  - falls back to parsing `<link rel="...icon...">`
  - contains ICO handling

### Input and System Hooks

- `MouseEventMonitor`
  - prefers `CGEvent.tapCreate`
  - falls back to `NSEvent.addGlobalMonitorForEvents`
- `HotkeyManager`
  - uses Carbon global hotkeys
  - persists key code, modifiers, and enabled state via `SettingsManager`
- `LoginItemManager`
  - uses `SMAppService.mainApp`
- `StatusBarManager`
  - owns the menu bar icon and menu
- `UpdateManager`
  - checks latest release from Gitee
  - can download and open a `.dmg`

## Models

- `ItemType`: `.application` or `.website`
- `PanelLayer`: `.upper` or `.lower`
- `PanelItem`
  - stores name, type, path, custom icon data, optional browser path, layer, optional bound app bundle ID, order
- `PageGroup`
  - stores per-layer page names
- `ContextAction`, `ActionType`, `AppPreset`, `PresetConfiguration`
  - exist in code, but are not the primary UI path used by the current main panel

## Current Settings Surface

`SettingsView.swift` currently exposes four tabs:

- `网格`
  - upper/lower columns
  - upper/lower rows
  - item spacing
- `外观`
  - panel opacity
- `管理`
  - browse and delete items
  - open add-item window
- `高级`
  - global hotkey
  - launch at login
  - reset settings
  - app version/build
  - update check

## Persistence Paths

All app data lives under:

```text
~/Library/Application Support/Quick Panel/
```

Current files:

- `config.json`
- `settings.json`
- `groups.json`
- `pagecounts.json`

## Notification Names in Use

Current cross-component notifications include:

- `.hidePanel`
- `.panelWillShow`
- `.scrollPreviousPage`
- `.scrollNextPage`
- `.settingsDidChange`

These are defined in multiple files, so check for duplicates before adding more notification extensions.

## Important Current Limitations

- No automated tests
- No search feature in the panel
- No import/export
- `PermissionManager.requestAccessibilityPermission()` exists but is not currently invoked during startup
- `browserPath` support is only partially surfaced
- `ContextDetector`, `ShortcutExecutor`, and preset action models are partially integrated or currently unused in the main product flow

## Editing Guidance

When modifying this repo:

- treat `PanelView.swift` and `PanelWindowManager.swift` as the active panel path
- do not assume `NewPanelView.swift` is live
- preserve the singleton service pattern already used across the app
- keep Chinese user-facing UI copy consistent with the existing app
- remember that the repo path contains spaces and shell commands must quote paths
