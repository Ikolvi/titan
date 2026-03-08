# MCP Integration Guide — Titan Blueprint Server

**Package:** `titan_colossus` · **Server:** `blueprint_mcp_server` · **Protocol:** MCP 2024-11-05

Titan provides a Model Context Protocol (MCP) server that gives AI assistants real-time access to your running Flutter app. The server enables AI-driven testing, screen observation, navigation graph analysis, and automated test generation — all through a standardized protocol that works across IDEs.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [IDE Setup](#ide-setup)
  - [VS Code (GitHub Copilot)](#vs-code-github-copilot)
  - [Cursor](#cursor)
  - [Android Studio / IntelliJ IDEA](#android-studio--intellij-idea)
  - [Windsurf](#windsurf)
  - [Zed](#zed)
  - [Claude Desktop](#claude-desktop)
  - [Continue.dev (VS Code / JetBrains)](#continuedev)
  - [Cline (VS Code)](#cline)
- [App Configuration](#app-configuration)
- [Server CLI Options](#server-cli-options)
- [Tool Reference](#tool-reference)
  - [Screen Observation (Scry)](#screen-observation-scry)
  - [Blueprint Analysis](#blueprint-analysis)
  - [Campaign Management](#campaign-management)
  - [Relay Bridge](#relay-bridge)
- [Usage Examples](#usage-examples)
- [Physical Device & Emulator Setup](#physical-device--emulator-setup)
- [Troubleshooting](#troubleshooting)

---

## Overview

The **Titan Blueprint MCP Server** (`titan-blueprint`) is a stdio-based JSON-RPC 2.0 server that exposes 20 tools to AI assistants. It connects to your running Flutter app through the **Relay** HTTP bridge (port 8642) and reads static blueprint data from `.titan/blueprint.json`.

### Architecture

```
┌──────────────┐    stdio/JSON-RPC    ┌─────────────────────────┐
│   AI Agent   │◄────────────────────►│  Blueprint MCP Server   │
│  (Copilot,   │                      │  (dart process)         │
│   Cursor,    │                      │                         │
│   Claude)    │                      │  Reads .titan/*.json    │
└──────────────┘                      │  Connects to Relay HTTP │
                                      └───────────┬─────────────┘
                                                  │ HTTP (localhost:8642)
                                      ┌───────────▼─────────────┐
                                      │  Running Flutter App    │
                                      │  with ColossusPlugin    │
                                      │  (enableRelay: true)    │
                                      └─────────────────────────┘
```

### Two Modes of Operation

1. **Static mode** — Read pre-exported blueprint data (`.titan/blueprint.json`). Works without a running app. Tools: `get_terrain`, `get_stratagems`, `get_ai_prompt`, `get_dead_ends`, `get_unreliable_routes`, `get_route_patterns`.

2. **Live mode** — Connect to a running app via the Relay HTTP bridge. Required for real-time screen observation and action execution. Tools: `scry`, `scry_act`, `scry_diff`, `execute_campaign`, `relay_status`, `relay_terrain`, `generate_auth_stratagem`, `generate_campaign`, `audit_screen`.

---

## Prerequisites

1. **Dart SDK** ≥ 3.10.3 (or Flutter ≥ 3.10.0)
2. **titan_colossus** package in your app's dependencies
3. **FVM** (recommended) — all examples use `fvm dart` / `fvm flutter`
4. Your Flutter app configured with `ColossusPlugin(enableRelay: true)` for live mode

### Verify Dart is available

```bash
# With FVM
fvm dart --version

# Without FVM
dart --version
```

Note the path to your `dart` executable. You'll need it for IDE configuration:

```bash
# FVM path (common)
which fvm    # e.g., /Users/you/.pub-cache/bin/fvm
# Dart through FVM
fvm which dart    # e.g., /Users/you/fvm/versions/stable/bin/dart

# Direct system Dart
which dart    # e.g., /usr/local/bin/dart
```

---

## Quick Start

### 1. Add ColossusPlugin to your app

```dart
import 'package:titan_colossus/titan_colossus.dart';

runApp(
  Beacon(
    pillars: [/* your pillars */],
    plugins: [
      ColossusPlugin(
        enableRelay: true,                    // Enable HTTP bridge for AI testing
        blueprintExportDirectory: '.titan',   // Export blueprint data here
      ),
    ],
    child: MaterialApp.router(/* ... */),
  ),
);
```

### 2. Configure your IDE (see IDE Setup below)

### 3. Launch your app

```bash
cd your_project
fvm flutter run -d macos    # or any device
```

### 4. Wait for Relay to initialize (~12 seconds after launch)

### 5. Ask your AI assistant to observe the screen

> "Use the scry tool to tell me what's on screen"

---

## IDE Setup

### VS Code (GitHub Copilot)

VS Code supports MCP servers natively through GitHub Copilot Chat.

#### Option A: Workspace settings (recommended)

Create or edit `.vscode/settings.json` in your project root:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "${workspaceFolder}/packages/titan_colossus"
    }
  }
}
```

#### Option B: User settings (global)

Open VS Code Settings (`Cmd+,` / `Ctrl+,`) → search for "mcp" → edit `settings.json`:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "command": "/Users/you/fvm/versions/stable/bin/dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

#### Option C: With FVM wrapper

If `dart` isn't on your PATH but `fvm` is:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "command": "fvm",
      "args": [
        "dart",
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "${workspaceFolder}/packages/titan_colossus"
    }
  }
}
```

#### Option D: With CLI overrides

For custom relay host/port (e.g., physical device on the network):

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server",
        "--relay-host", "192.168.1.100",
        "--relay-port", "8642",
        "--blueprint-path", ".titan/blueprint.json"
      ],
      "cwd": "${workspaceFolder}/packages/titan_colossus"
    }
  }
}
```

#### Verification

1. Open the Copilot Chat panel
2. Click the **Tools** icon (🔧) in the chat input area
3. You should see `titan-blueprint` listed with 20 tools
4. Type: *"Use relay_status to check if my app's relay is running"*

---

### Cursor

Cursor supports MCP servers through its AI configuration.

#### Option A: Project-level configuration (recommended)

Create `.cursor/mcp.json` in your project root:

```json
{
  "mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

> **Important:** Cursor requires **absolute paths** for `cwd`. Replace `/absolute/path/to/your/project` with the actual path to your workspace.

#### Option B: Global configuration

Create or edit `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "titan-blueprint": {
      "command": "/Users/you/fvm/versions/stable/bin/dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

#### Verification

1. Open Cursor Settings → Features → MCP
2. You should see `titan-blueprint` listed and enabled
3. In chat, type: *"Use scry to observe the current screen"*

---

### Android Studio / IntelliJ IDEA

JetBrains IDEs support MCP through the **AI Assistant** plugin (2025.1+) or through third-party extensions.

#### Option A: Built-in AI Assistant (2025.1+)

JetBrains IDEs 2025.1+ include native MCP support in the AI Assistant.

1. Open **Settings** → **Tools** → **AI Assistant** → **MCP Servers**
2. Click **Add** (+)
3. Configure:
   - **Name:** `titan-blueprint`
   - **Command:** `dart` (or full path: `/Users/you/fvm/versions/stable/bin/dart`)
   - **Arguments:** `run titan_colossus:blueprint_mcp_server`
   - **Working Directory:** `/path/to/project/packages/titan_colossus`
4. Click **OK** → **Apply**

Or edit the MCP configuration file directly. Create `.idea/mcp.json` in your project:

```json
{
  "servers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "$PROJECT_DIR$/packages/titan_colossus"
    }
  }
}
```

#### Option B: Through Continue.dev plugin

See the [Continue.dev section](#continuedev) below.

#### Verification

1. Open the AI Assistant panel
2. Check that `titan-blueprint` appears in available tools
3. Ask: *"Check the relay status of my running app"*

---

### Windsurf

Windsurf (by Codeium) supports MCP servers through its configuration.

Create or edit `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

Or use the project-level config at `.windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

#### Verification

Open Windsurf Cascade and ask: *"Use the scry tool to see what's on the app screen"*

---

### Zed

Zed editor supports MCP through its settings file.

Edit `~/.config/zed/settings.json` (or the project-level `.zed/settings.json`):

```json
{
  "context_servers": {
    "titan-blueprint": {
      "command": {
        "path": "dart",
        "args": [
          "run",
          "titan_colossus:blueprint_mcp_server"
        ],
        "env": {}
      },
      "settings": {}
    }
  }
}
```

> **Note:** Zed requires `dart` to be on your PATH, or use the absolute path.

---

### Claude Desktop

Claude Desktop supports MCP servers through its configuration file.

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

#### Verification

1. Restart Claude Desktop
2. Look for the 🔌 icon in the chat bar — click to see connected MCP servers
3. Ask: *"Use relay_status to check if the app is running"*

---

### Continue.dev

[Continue.dev](https://continue.dev) is an open-source AI code assistant that works in VS Code and JetBrains IDEs.

Edit `.continue/config.json` in your project root (or `~/.continue/config.json` for global):

```json
{
  "experimental": {
    "modelContextProtocolServers": [
      {
        "transport": {
          "type": "stdio",
          "command": "dart",
          "args": [
            "run",
            "titan_colossus:blueprint_mcp_server"
          ],
          "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
        }
      }
    ]
  }
}
```

---

### Cline

[Cline](https://github.com/cline/cline) (formerly Claude Dev) is a VS Code extension that supports MCP.

1. Open the Cline sidebar in VS Code
2. Click the **MCP Servers** icon (🔌)
3. Click **Configure MCP Servers**
4. Add to the configuration:

```json
{
  "mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run",
        "titan_colossus:blueprint_mcp_server"
      ],
      "cwd": "/absolute/path/to/your/project/packages/titan_colossus"
    }
  }
}
```

5. Click **Save** and restart the MCP server

---

## App Configuration

### Minimal Setup (Live Mode)

```dart
ColossusPlugin(
  enableRelay: true,    // Required for all live MCP tooling
)
```

### Full Setup (Live + Blueprint Export)

```dart
ColossusPlugin(
  enableRelay: true,
  blueprintExportDirectory: '.titan',   // Auto-export blueprint on app shutdown
  enableLensTab: true,                   // Debug overlay with Blueprint tab
  enableChronicle: true,                 // Performance logging
  getCurrentRoute: () {
    try {
      return Atlas.current.path;
    } catch (_) {
      return null;
    }
  },
)
```

### What happens on app startup

1. `Colossus.init()` initializes monitors (Pulse, Stride, Vessel)
2. `Relay.start()` binds an HTTP server on port **8642**
3. The Relay takes approximately **12 seconds** to fully initialize
4. Shade recording becomes available for gesture capture
5. Scry becomes available for screen observation

### Blueprint auto-export

When `blueprintExportDirectory` is set, Colossus automatically exports blueprint data on app shutdown:

- `.titan/blueprint.json` — Full navigation graph + stratagems
- `.titan/blueprint-prompt.md` — AI-ready summary document

The MCP server reads these files for static analysis tools (`get_terrain`, `get_stratagems`, etc.).

---

## Server CLI Options

| Option | Default | Description |
|--------|---------|-------------|
| `--blueprint-path` | `.titan/blueprint.json` | Path to the blueprint JSON file |
| `--relay-host` | `127.0.0.1` | Relay HTTP server hostname |
| `--relay-port` | `8642` | Relay HTTP server port |
| `--relay-token` | *(none)* | Optional auth token for Relay requests |

### Running manually (for testing)

```bash
cd packages/titan_colossus
fvm dart run titan_colossus:blueprint_mcp_server

# With custom options
fvm dart run titan_colossus:blueprint_mcp_server \
  --relay-host 192.168.1.50 \
  --relay-port 8642 \
  --blueprint-path /path/to/.titan/blueprint.json
```

---

## Tool Reference

The server exposes **20 tools** organized into four categories.

### Screen Observation (Scry)

These tools require a running app with `ColossusPlugin(enableRelay: true)`.

| Tool | Description |
|------|-------------|
| **`scry`** | Observe the current screen. Returns structured view of all visible elements with 18 intelligence capabilities: spatial layout, reachability, scroll inventory, overlay detection, toggle states, tab order, target stability scoring, multiplicity, ancestor context, form validation, element grouping, landmarks, visual prominence, value type inference, action impact prediction, and layout pattern detection. |
| **`scry_act`** | Execute one or more actions and return the resulting screen state. Supports: `tap`, `enterText`, `clearText`, `scroll`, `back`, `longPress`, `doubleTap`, `swipe`, `navigate`, `waitForElement`, `waitForElementGone`, `pressKey`, `submitField`, `toggleSwitch`, `toggleCheckbox`, `selectDropdown`. Pass a single action or an `actions` array. |
| **`scry_diff`** | Compare current screen state against the last observation. Shows appeared/disappeared/changed elements, route changes, overlay changes, and form status updates. |

#### `scry` parameters

*(none — just call it)*

#### `scry_act` parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | `string` | Yes (single) | Action type (tap, enterText, etc.) |
| `label` | `string` | Depends | Target element label (for tap, enterText, etc.) |
| `value` | `string` | Depends | Text value (for enterText) |
| `key` | `string` | No | Key identifier for precise targeting |
| `direction` | `string` | No | Scroll/swipe direction (up, down, left, right) |
| `route` | `string` | No | Route path (for navigate action) |
| `actions` | `array` | Yes (multi) | Array of action objects for multi-action |

#### `scry_diff` parameters

*(none — auto-compares against last observation)*

### Blueprint Analysis

These tools work with static blueprint data from `.titan/blueprint.json`. No running app required.

| Tool | Description |
|------|-------------|
| **`get_terrain`** | Returns the navigation graph (Outposts + Marches) with visit counts, dead-end detection, and reliability scores. Formats: `json`, `mermaid`, `ai_map` (default). |
| **`get_stratagems`** | Returns auto-generated edge-case test plans from the Gauntlet. Optionally filter by route pattern. |
| **`get_ai_prompt`** | Returns a complete AI-ready testing context document. |
| **`get_dead_ends`** | Returns screens with no outgoing transitions (potential bugs). |
| **`get_unreliable_routes`** | Returns transitions with low reliability or few observations. |
| **`get_route_patterns`** | Returns all known parameterized routes (e.g., `/quest/:id`). |
| **`get_full_context`** | Returns everything in one call: terrain, dead ends, unreliable routes, stratagems, campaign template, and debrief. |

### Campaign Management

| Tool | Description |
|------|-------------|
| **`get_campaign_template`** | Returns the Campaign JSON schema and instructions. |
| **`save_campaign`** | Save a Campaign JSON to `.titan/campaign.json`. |
| **`execute_campaign`** | Execute a Campaign on the running app via Relay. |
| **`get_debrief`** | Returns the debrief from previous Campaign results. |
| **`generate_gauntlet`** | Generate Stratagems for a specific route. Params: `route` (required), `intensity` (`quick`/`standard`/`thorough`). |
| **`generate_auth_stratagem`** | Auto-generate an auth stratagem from the live screen. |
| **`generate_campaign`** | Auto-generate a complete Campaign from the live screen. |
| **`audit_screen`** | Detect data-binding bugs via sign-out/re-login cycle. |

### Relay Bridge

| Tool | Description |
|------|-------------|
| **`relay_status`** | Check whether the Relay is running in the app. |
| **`relay_terrain`** | Get live Terrain from the running app (latest state). |

---

## Usage Examples

### Basic screen observation

Ask your AI assistant:

> "Use scry to tell me what's on the current screen"

The AI will call the `scry` tool and receive a structured Markdown report:

```markdown
# Current Screen
**Type**: login | **Layout**: form | 12 glyphs

## 📝 Text Fields (2)
- **Hero Name** (TextField, value: "")
- **Password** (TextField, value: "")

## 🔘 Buttons (1)
- **Enter the Questboard** (FilledButton)

## 📋 Form Status
- **Fields**: 0/2 filled
- **Empty**: "Hero Name", "Password"
```

### Navigate and interact

> "Sign in with username 'Kael' and password 'titan123'"

The AI will:
1. Call `scry` to observe the login screen
2. Call `scry_act` with `enterText` for the Hero Name field
3. Call `scry_act` with `enterText` for the Password field
4. Call `scry_act` with `tap` on "Enter the Questboard"
5. Use `scry_diff` to verify the screen changed

### Run automated tests

> "Generate and execute a test campaign for the login flow"

The AI will:
1. Call `generate_campaign` to create a Campaign from the current screen
2. Call `execute_campaign` to run it against the app
3. Call `get_debrief` to analyze results

### Analyze navigation structure

> "Show me any dead ends or unreliable routes in my app"

The AI will:
1. Call `get_dead_ends` to find screens with no exit
2. Call `get_unreliable_routes` to find flaky transitions

---

## Physical Device & Emulator Setup

### Same machine (desktop, simulator, emulator)

Default configuration works out of the box. The Relay binds to `localhost:8642`.

### iOS Simulator

No extra configuration needed — the simulator shares the host's network.

```json
{
  "command": "dart",
  "args": ["run", "titan_colossus:blueprint_mcp_server"],
  "cwd": "packages/titan_colossus"
}
```

### Android Emulator

The Android emulator uses `10.0.2.2` to reach the host machine's `localhost`. However, since the **MCP server runs on the host** and connects to the Relay, the default `127.0.0.1:8642` works — the Relay is bound inside the emulator but accessible through port forwarding.

Set up port forwarding:

```bash
adb forward tcp:8642 tcp:8642
```

Then use default configuration (no `--relay-host` override needed).

### Physical Device (same network)

When the app runs on a physical device, configure the Relay host to the device's IP:

```bash
# Find your device's IP address
# iOS: Settings → Wi-Fi → (i) button
# Android: Settings → Network → Wi-Fi → Connected network
```

Configure the MCP server:

```json
{
  "command": "dart",
  "args": [
    "run", "titan_colossus:blueprint_mcp_server",
    "--relay-host", "192.168.1.50",
    "--relay-port", "8642"
  ],
  "cwd": "packages/titan_colossus"
}
```

### Web (not supported)

The Relay uses `dart:io` HTTP server, which is not available on web platforms. For web apps, use the Lens debug overlay to manually paste Campaign JSON, or export blueprint data for static analysis.

---

## Troubleshooting

### MCP server not showing up in IDE

| Symptom | Fix |
|---------|-----|
| Server not listed | Restart IDE after adding configuration |
| "command not found: dart" | Use absolute path to dart: `/Users/you/fvm/versions/stable/bin/dart` |
| Server crashes immediately | Run manually in terminal to see error: `cd packages/titan_colossus && dart run titan_colossus:blueprint_mcp_server` |
| Wrong cwd | Ensure `cwd` points to `packages/titan_colossus` (where `pubspec.yaml` is) |

### Relay connection issues

| Symptom | Fix |
|---------|-----|
| "Relay not available" | Ensure `ColossusPlugin(enableRelay: true)` is in your app |
| Connection refused | Wait ~12 seconds after app launch for Relay to bind port 8642 |
| Port already in use | Kill stale processes: `lsof -i :8642` then `kill <PID>` |
| Stale data from old session | Kill old app process holding port 8642, relaunch app |
| Scry returns same data repeatedly | Check `lsof -i :8642` — the PID should match your running app |

### Blueprint data issues

| Symptom | Fix |
|---------|-----|
| "No blueprint data found" | Set `blueprintExportDirectory: '.titan'` in ColossusPlugin, run app, and let it shutdown cleanly |
| Empty terrain | Record Shade sessions first — Scout analyzes sessions to build Terrain |
| Stale blueprint data | Restart app or manually trigger export from Lens Blueprint tab |

### Common errors

**"Unknown method" on hot restart:**
After a hot restart, the Dart Tooling Daemon connection may break. Stop the app and relaunch instead of hot-restarting.

**Relay uptime doesn't match app launch time:**
A previous app instance is still holding port 8642. Kill it:
```bash
lsof -i :8642    # Find the PID
kill <PID>        # Kill it
# Relaunch your app
```

**"dart: command not found" in MCP server:**
Use the full path to the Dart executable:
```json
"command": "/Users/you/fvm/versions/stable/bin/dart"
```

**Timeout waiting for Relay:**
The Relay needs ~12 seconds to initialize after app launch. If using the MCP tools immediately after launching, call `relay_status` first to verify the Relay is ready.

---

## Security Considerations

- The Relay HTTP server listens on `localhost` by default — it's not exposed to the network
- On physical devices, the Relay binds to all interfaces (`0.0.0.0`) — use `--relay-token` for authentication
- The MCP server communicates via stdio (standard input/output) — no network ports opened by the server itself
- Blueprint data (`.titan/` directory) contains your app's navigation structure — add `.titan/` to `.gitignore` if the structure is sensitive
- The `audit_screen` tool performs sign-out/re-login cycles — only use in development environments

---

## Next Steps

- [Colossus Monitoring Guide](14-colossus-monitoring.md) — Full performance monitoring documentation
- [Testing Guide](07-testing.md) — Titan testing patterns
- [Story: The Bridge Extends](story/chapter-56-the-bridge-extends.md) — Narrative on Blueprint export
- [Story: The Relay Speaks](story/chapter-57-the-relay-speaks.md) — Narrative on Relay HTTP bridge
- [Story: The Scry Pierces](story/chapter-58-the-scry-pierces.md) — Narrative on Scry AI agent interface
