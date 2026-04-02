# KeepGoing — Design Spec

**Date:** 2026-04-02
**Status:** Approved

## Problem

When running multiple Claude Code sessions across terminal windows, it's easy to miss when Claude finishes a task and is waiting for input. You switch to a browser or another app and forget to come back.

## Solution

KeepGoing is a lightweight macOS agent app that displays a floating HUD notification when Claude Code needs your attention. Clicking the HUD brings the specific terminal window to the front.

## Architecture

### Components

1. **HTTP Listener** — local server on `localhost:7433` that receives POST requests from Claude Code's `Notification` hook
2. **HUD Renderer** — a floating SwiftUI window that appears top-center of the screen
3. **Session Tracker** — maps Claude sessions to terminal windows via window title matching
4. **Terminal Focus** — AppleScript/Accessibility bridge that brings specific terminal windows to front
5. **CLI** — `keepgoing install` / `keepgoing uninstall` for setup and teardown

### Lifecycle

- Launches at login via Login Items (launchd)
- Sits idle with zero UI until a hook fires
- On POST: shows HUD with session context
- On click: focuses the correct terminal window, dismisses that HUD row
- Auto-dismisses if user returns to the terminal on their own
- Zero CPU when no notifications are active

## Claude Code Integration

One hook entry in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "curl -s -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @-"
      }]
    }]
  }
}
```

The hook receives context as JSON on stdin (includes `session_id`, `cwd`, `hook_event_name`, etc.). Piping directly to `curl -d @-` forwards the full payload to KeepGoing's server.

## HUD Design

### Appearance

- Rounded pill shape, ~300px wide, ~50px tall
- Semi-transparent dark background with vibrancy (NSVisualEffectView)
- Positioned top-center of the main display, ~80px below menu bar
- Subtle slide-down animation on appear, fade-out on dismiss
- Content: project folder name + "Claude is waiting"
- Example: `keepgoing — Claude is waiting`

### Stacking

- Multiple sessions stack vertically, most recent on top
- Each entry is its own clickable row with project name
- Clicking one row dismisses it; remaining rows reflow upward

### Dismiss Behavior

- **Click:** focuses that terminal window, dismisses that row
- **Auto-dismiss:** if user manually switches to the correct terminal and that Claude session receives input, that row auto-dismisses
- **No timeout:** stays until acted on

### Window Properties

- `NSWindow.Level.floating` (above normal windows, below screen saver)
- `canBecomeKey = false` (does not steal focus)
- Ignores mouse-moved events except click
- Not visible in Mission Control or Expose

## Terminal Window Focusing

### Detection Strategy

When a notification arrives with `session_id` and `cwd`:

1. Enumerate open windows in Ghostty and Terminal.app via Accessibility API / AppleScript
2. Match by window title — both terminals include cwd or session name in title. Claude Code sets terminal title to include the session name.
3. Store mapping: `{ session_id, cwd, app_bundle_id, window_id }`

### Focus Action

On click, use AppleScript to activate the terminal app and bring the specific window to front by window ID.

### Fallback Chain

1. Match by window title containing session name or cwd
2. If no match, match by cwd alone
3. If still no match, just activate the terminal app (best effort)

### Auto-Dismiss Detection

- Poll every 2-3 seconds: is the frontmost app a terminal? Does the frontmost window title match a tracked session?
- If yes, dismiss that row from the HUD
- Stop polling when HUD is empty (zero CPU idle)

### Supported Terminals

- Ghostty (primary)
- Terminal.app (secondary)
- Extensible via bundle ID + window title convention

## Installation & Distribution

### For Users

- GitHub Releases: pre-built universal binary (arm64 + x86_64) as `.zip`
- `keepgoing install` command that:
  1. Copies `KeepGoing.app` to `~/Applications/`
  2. Registers as a Login Item
  3. Patches `~/.claude/settings.json` to add the Notification hook (merges with existing hooks)
  4. Prompts for Accessibility permission
  5. Launches the app
- `keepgoing uninstall` — removes Login Item, removes hook, deletes app

### For Developers

- Clone repo, `swift build` via Swift Package Manager
- No Xcode project file — just `Package.swift`

## Project Structure

```
keepgoing/
├── Package.swift
├── Sources/
│   ├── KeepGoing/              # macOS agent app
│   │   ├── App.swift           # NSApplication setup (LSUIElement, no dock icon)
│   │   ├── HUDWindow.swift     # Floating window + SwiftUI view
│   │   ├── Server.swift        # Local HTTP listener on :7433
│   │   ├── SessionTracker.swift    # Maps sessions to terminal windows
│   │   └── TerminalFocus.swift     # AppleScript/Accessibility bridge
│   └── keepgoing-cli/          # CLI for install/uninstall
│       └── main.swift
├── Resources/
│   └── Info.plist              # LSUIElement = true
├── README.md
└── LICENSE
```

## Configuration

Zero-config by default. Port `7433`, no settings file. Override via environment variable `KEEPGOING_PORT` or launch argument `--port` if needed.

## Tech Stack

- Swift 5.9+
- SwiftUI (HUD views)
- AppKit (NSWindow management)
- Swift Package Manager (build system)
- Network.framework (`NWListener`) for HTTP server (zero external dependencies)
- AppleScript / Accessibility API for terminal window control

## Non-Goals

- No menubar icon or dock icon
- No notification center integration (the HUD IS the notification)
- No support for non-macOS platforms
- No Claude Code plugin/extension — hooks are sufficient
- No persistent state or database
