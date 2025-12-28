# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quick Panel is a macOS application built with SwiftUI. It targets macOS 26.2+ and uses the modern SwiftUI app lifecycle.

## Project Structure

```
Quick Panel/
├── Quick Panel.xcodeproj/     # Xcode project configuration
└── Quick Panel/               # Main source directory
    ├── Quick_PanelApp.swift   # App entry point (@main)
    ├── ContentView.swift      # Root view
    └── Assets.xcassets/       # Image and color assets
```

## Build Commands

### Building the App
```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build
```

### Running the App
Open the project in Xcode and run:
```bash
open "Quick Panel/Quick Panel.xcodeproj"
```
Then press Cmd+R to build and run.

Alternatively, build and run from command line:
```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug
# App will be built to: build/Debug/Quick Panel.app
open "build/Debug/Quick Panel.app"
```

### Cleaning Build
```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" clean
```

## Project Configuration

- **Bundle Identifier**: `com.benxin.Quick-Panel`
- **Target Platform**: macOS 26.2+
- **Swift Version**: Latest (Xcode 26.2)
- **App Sandbox**: Enabled
- **Previews**: Enabled for SwiftUI development

## Architecture

This is a standard SwiftUI app following Apple's recommended structure:
- `Quick_PanelApp.swift` contains the `@main` entry point with a `WindowGroup` scene
- `ContentView.swift` is the root view that gets displayed in the window
- The app uses SwiftUI's declarative syntax for UI and SwiftUI previews for rapid development

## Development Notes

- SwiftUI previews are available - use `#Preview` macro in any view file
- The app uses App Sandbox with read-only access to user-selected files
- No external dependencies or package managers are currently configured
