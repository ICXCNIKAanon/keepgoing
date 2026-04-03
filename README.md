# KeepGoing

A native Swift macOS app that notifies you when Claude Code needs input.

When Claude Code finishes a task and is waiting, a floating pill appears at the top of your screen showing the session name. Click it to bring the right terminal window forward. When you're away from the computer, it can send a push notification to your phone via Telegram.

## Features

- Floating pill HUD appears top-center when Claude Code needs input
- Shows the session name (e.g., "nucleus — Claude is waiting")
- Multiple sessions stack as separate pills
- Click a pill to focus the correct Ghostty or Terminal.app window
- Auto-dismisses when you switch to the right terminal
- Optional Telegram push notifications when you're away from your desk
- Starts on login automatically after install
- Zero configuration required — just install and go
- No dependencies — pure Swift, uses macOS Accessibility API

## Requirements

- macOS 14 or later
- Swift 6.0 or later
- Accessibility permission (prompted on first run)

## Install

```bash
git clone https://github.com/ICXCNIKAanon/keepgoing.git
cd keepgoing
swift build -c release
bash scripts/bundle.sh
.build/release/keepgoing-cli install
```

`install` copies the app to `/Applications`, registers the Claude Code notification hook, and adds KeepGoing to your Login Items.

Grant Accessibility permission when macOS prompts you. Without it, window focus will not work.

## Telegram (optional)

To receive push notifications when you're away from your computer:

```bash
.build/release/keepgoing-cli telegram setup
```

Follow the prompts to connect a Telegram bot. Once configured:

```bash
.build/release/keepgoing-cli telegram enable
.build/release/keepgoing-cli telegram test
```

## CLI Reference

```
keepgoing-cli install              Install app, hook, and login item
keepgoing-cli uninstall            Remove everything
keepgoing-cli status               Check if the daemon is running

keepgoing-cli telegram setup       Connect a Telegram bot
keepgoing-cli telegram enable      Turn on Telegram notifications
keepgoing-cli telegram disable     Turn off Telegram notifications
keepgoing-cli telegram test        Send a test message
keepgoing-cli telegram status      Show current Telegram config
```

## How It Works

KeepGoing uses Claude Code's built-in Notification hook. When a session needs input, Claude Code sends a POST to `localhost:7433`. The daemon receives it, looks up the session name from Claude's local transcript files, and shows a HUD pill via SwiftUI.

When you click a pill, KeepGoing uses the macOS Accessibility API (`AXUIElement`) to raise and focus the correct terminal window. The pill auto-dismisses as soon as you switch to the right terminal.

Telegram notifications are sent directly via the Telegram Bot API using `URLSession` — no third-party SDK required.

**Stack:** Swift 6.0, SwiftUI, AppKit, Network.framework (`NWListener`), ApplicationServices (`AXUIElement`), Foundation (`URLSession`)

## Known Limitations

- When clicking a pill to focus a terminal window, macOS brings all windows of that application forward, not just the target window. The correct window is on top, but other windows from the same app will also appear. This is a macOS constraint — per-window focus without raising the whole app is not supported through the public Accessibility API.
- Supported terminals: Ghostty, Terminal.app. iTerm2 and others are not tested.

## Uninstall

```bash
.build/release/keepgoing-cli uninstall
```

This removes the app, the Claude Code hook, and the Login Item entry.
