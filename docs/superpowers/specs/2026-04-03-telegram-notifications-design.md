# KeepGoing Telegram Notifications — Design Spec

**Date:** 2026-04-03
**Status:** Approved

## Problem

The HUD only works when you're at your computer. If you walk away, you miss Claude Code notifications entirely.

## Solution

Add optional Telegram push notifications alongside the existing HUD. Users bring their own bot (created via @BotFather in 30 seconds). Config toggles let users enable/disable HUD and Telegram independently.

## Architecture

When a Claude Code Notification hook fires:
1. KeepGoing receives the POST on :7433 (existing)
2. Adds to SessionStore → HUD shows (if enabled)
3. Sends Telegram message via Bot API (if enabled)

Both paths fire in parallel. Telegram is a simple HTTPS POST to `https://api.telegram.org/bot<token>/sendMessage` using Foundation `URLSession`. No new dependencies.

## Config

File: `~/.keepgoing/config.json`

```json
{
  "hud": { "enabled": true },
  "telegram": {
    "enabled": true,
    "botToken": "123456:ABC-DEF...",
    "chatId": "789012345"
  }
}
```

- If the file doesn't exist, defaults to `hud.enabled = true`, `telegram.enabled = false`
- Config is read fresh on each notification (simple, no caching needed for a file this small)
- CLI commands modify the file; changes take effect on the next notification

## Telegram Setup Flow

`keepgoing-cli telegram setup` interactive flow:

1. Print instructions: "Open Telegram, message @BotFather, send /newbot, pick a name"
2. Prompt: "Paste your bot token:"
3. Validate token format (digits:alphanumeric)
4. Print: "Now send /start to your new bot in Telegram"
5. Poll `getUpdates` API for up to 60 seconds to detect the user's chat_id
6. Write botToken + chatId to `~/.keepgoing/config.json`
7. Send a test message: "KeepGoing connected! You'll get notifications here when Claude needs input."
8. Print success

`keepgoing-cli telegram disable` — sets `telegram.enabled = false`
`keepgoing-cli telegram enable` — sets `telegram.enabled = true`
`keepgoing-cli telegram test` — sends a test message

## Telegram Message Format

```
Claude is waiting — <projectName>
```

Simple, one line. No markdown, no buttons. Just enough to know which project needs attention.

## Files Changed

- Create: `Sources/KeepGoingCore/Config.swift` — Codable model, read/write `~/.keepgoing/config.json`
- Create: `Sources/KeepGoingCore/TelegramNotifier.swift` — `sendMessage` via URLSession POST
- Modify: `Sources/KeepGoing/main.swift` — load config, pass to server callback, fire Telegram alongside SessionStore
- Modify: `Sources/keepgoing-cli/CLI.swift` — add `telegram` subcommand with setup/enable/disable/test

## Non-Goals

- No hosted bot or shared infrastructure
- No rich messages, buttons, or inline keyboards
- No notification grouping or rate limiting (v1)
- No config hot-reload (app reads config per-notification, which is good enough)
