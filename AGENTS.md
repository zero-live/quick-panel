# AGENTS.md — Quick Panel

> macOS quick-launch panel app (Quicker-style). SwiftUI + AppKit hybrid. Triggered by middle-click, shows a floating panel with app/website shortcuts.

## Build & Run

```bash
# Build (Debug)
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build

# Build + Run (recommended)
./run_app.sh

# Clean
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" clean

# View logs
log stream --predicate 'process == "Quick Panel"' --level debug
```

Run unit tests with:

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug test
```

`Quick PanelTests` currently covers layout and panel-document serialization. No package managers (SPM, CocoaPods, Carthage) are in use — zero external dependencies.

## Project Layout

```
Quick Panel/Quick Panel/          ← Xcode project root
  Quick Panel/                    ← Source root
    Quick_PanelApp.swift          ← @main entry, uses NSApplicationDelegateAdaptor
    AppDelegate.swift             ← App lifecycle, wires up services
    ContentView.swift             ← Unused default view (kept as scaffold)
    PanelView.swift               ← Main panel UI (upper/lower grid, drag-drop, pagination)
    PanelWindowManager.swift      ← NSPanel creation, show/hide, scroll-wheel routing
    MouseEventMonitor.swift       ← Global middle-click via CGEvent (fallback: NSEvent)
    AppLauncher.swift             ← Launch apps / open URLs
    PermissionManager.swift       ← Accessibility permission check/request
    Models/
      PanelItem.swift             ← Core data model (Identifiable, Codable)
      ItemType.swift              ← .application | .website enum
      ContextAction.swift         ← Keyboard shortcut model + PresetConfiguration
      PageGroup.swift             ← Page group names per layer
    Views/
      AddItemView.swift           ← Add/Edit item forms
      SettingsView.swift          ← Settings tabs (grid, appearance, management, advanced)
      AboutView.swift             ← About window content
      NewPanelView.swift          ← Alternative panel layout (card-style, not currently active)
    Services/
      DataManager.swift           ← JSON persistence (~/Library/Application Support/Quick Panel/)
      SettingsManager.swift       ← App settings with validation
      IconFetcher.swift           ← Favicon fetching (direct + HTML parsing)
      ContextDetector.swift       ← Detects frontmost app for lower-layer context
      ShortcutExecutor.swift      ← CGEvent keyboard simulation, AppleScript, shell commands
      StatusBarManager.swift      ← Menu bar icon and menu
      LoginItemManager.swift      ← SMAppService launch-at-login
      AddItemWindowManager.swift  ← Manages add/edit NSWindow lifecycle
      SettingsWindowManager.swift ← Manages settings NSWindow
      AboutWindowManager.swift    ← Manages about NSWindow
```

## Architecture Patterns

### Singleton Services
All services use `static let shared` singletons with `private init()`. Follow this pattern:
```swift
class MyService {
    static let shared = MyService()
    private init() {}
}
```

### State Management
- Services that hold UI state are `ObservableObject` with `@Published` properties
- Views observe via `@ObservedObject var manager = SomeManager.shared`
- Cross-component communication uses `NotificationCenter` with typed `Notification.Name` extensions

### Window Management
- Each window type has a dedicated `*WindowManager` class
- Windows are `NSWindow`/`NSPanel` hosting SwiftUI views via `NSHostingController`
- The main panel is `NSPanel` with `.borderless` + `.nonactivatingPanel` style
- Windows track their own lifecycle via `NSWindow.willCloseNotification`

### Data Persistence
- JSON files in `~/Library/Application Support/Quick Panel/`
- Files: `panel.json` (items, groups and page counts), `settings.json` (app settings), `Icons/` (custom icons)
- Legacy `config.json`, `groups.json`, and `pagecounts.json` are migrated to `panel.json` on first launch and retained for manual recovery.
- Encoder uses `.prettyPrinted` and `.sortedKeys`

## Code Style

### File Headers
```swift
//
//  FileName.swift
//  Quick Panel
//
//  Created by AuthorName on YYYY/MM/DD.
//
```

### Imports
- Order: `Foundation`/`Cocoa` → `SwiftUI` → `AppKit` → other frameworks
- Import only what's needed (`Cocoa` for AppKit-heavy files, `SwiftUI` for views)

### Naming
- **Types**: `PascalCase` — `PanelItem`, `DataManager`, `ItemType`
- **Properties/Methods**: `camelCase` — `panelWindow`, `setupServices()`
- **Enums**: `PascalCase` type, `camelCase` cases — `enum PanelLayer { case upper, lower }`
- **Notification names**: `static let` on `Notification.Name` extension — `.hidePanel`, `.panelWillShow`
- **Constants**: No separate constants file; values inline or as computed properties

### MARK Comments
Use `// MARK: -` to organize sections within files:
```swift
// MARK: - Load/Save
// MARK: - CRUD Operations
// MARK: - Notification Extension
```

### Error Handling
- `print()` with emoji prefixes for logging: `✅` success, `❌` error, `⚠️` warning, `🔍` search, `📋` info
- User-facing errors via `NSAlert` with Chinese localized strings
- File operations use `try?` for non-critical paths, `do/catch` with logging for critical ones
- No custom error types; rely on system errors

### UI Conventions
- UI text is in **Chinese** (Simplified) — all labels, buttons, alerts
- SF Symbols for all icons (e.g., `"plus.circle"`, `"gear"`, `"globe"`)
- `.ultraThinMaterial` background for the floating panel
- Consistent item size: 70×90pt per grid cell, 48×48pt icons
- `.cornerRadius(12)` on panels and cards
- `.shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)` for elevation
- SwiftUI animations: `.spring(response: 0.3, dampingFraction: 0.7)` for layout changes

### SwiftUI View Structure
- `body` computed property at top
- Private helper methods below
- Extract reusable sub-views as separate structs in the same file (using `// MARK: -`)
- Use `@State` for local view state, `@ObservedObject` for shared state

### Models
- All models conform to `Identifiable, Codable`
- Use `UUID` for `id` fields, with default `UUID()` in init
- Enums backing raw `String` values for JSON compatibility

## Key Technical Details

- **Bundle ID**: `com.benxin.Quick-Panel`
- **Target**: macOS 26.2+
- **Entitlements**: App Sandbox (on), user-selected files (read-only), network client (for favicon fetching)
- **Accessibility**: Uses `AXIsProcessTrusted()` / `CGEvent.tapCreate` for global mouse monitoring
- **Activation policy**: `.accessory` (no dock icon, menu-bar only)
- **No test target** — manual testing only via `run_app.sh` or Xcode

## Common Pitfalls

1. **Paths with spaces**: The project path contains spaces (`Quick Panel`). Always quote paths in shell commands.
2. **Duplicate Notification.Name**: Extensions on `Notification.Name` are scattered across files. Check for existing names before adding new ones.
3. **Window management**: The panel uses `NSPanel` with `nonactivatingPanel` — do NOT call `makeKey()` on it (causes warnings).
4. **Sandbox + Accessibility**: The app requests accessibility permission at runtime; the entitlements file enables sandbox + network.
5. **PanelWindowManager.shared**: Accessed via `AppDelegate` cast, not a true static singleton. Be careful with initialization order.
