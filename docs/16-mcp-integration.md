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
  - [TLS / SSL](#tls--ssl)
  - [Authentication](#authentication)
- [Tool Reference](#tool-reference)
  - [Screen Observation (Scry)](#screen-observation-scry)
  - [Blueprint Analysis](#blueprint-analysis)
  - [Campaign Management](#campaign-management)
  - [Performance Monitoring](#performance-monitoring)
  - [Session & Recording](#session--recording)
  - [Error Detection](#error-detection)
  - [Relay Bridge](#relay-bridge)
  - [API Monitoring (Envoy)](#api-monitoring-envoy)
  - [Tremor Management](#tremor-management)
  - [App Introspection](#app-introspection)
  - [UI Control](#ui-control)
- [Usage Examples](#usage-examples)
- [Physical Device & Emulator Setup](#physical-device--emulator-setup)
- [Troubleshooting](#troubleshooting)

---

## Overview

The **Titan Blueprint MCP Server** (`titan-blueprint`) is a stdio-based JSON-RPC 2.0 server that exposes **48 tools** to AI assistants. It connects to your running Flutter app through the **Relay** HTTP bridge (port 8642) and reads static blueprint data from `.titan/blueprint.json`.

### Architecture

**Native** (Android, iOS, macOS, Windows, Linux):

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

**Web** (Chrome, Firefox, Edge):

```
┌──────────────┐    stdio/JSON-RPC    ┌─────────────────────────┐
│   AI Agent   │◄────────────────────►│  Blueprint MCP Server   │
│  (Copilot,   │                      │  (dart process)         │
│   Cursor,    │                      │                         │
│   Claude)    │                      │  Hosts WS relay server  │
└──────────────┘                      │  on --relay-ws-port     │
                                      └───────────▲─────────────┘
                                                  │ WebSocket (localhost:8643)
                                      ┌───────────┴─────────────┐
                                      │  Flutter Web App        │
                                      │  (browser tab)          │
                                      │  Connects TO MCP server │
                                      └─────────────────────────┘
```

On web, browsers cannot host HTTP servers. The connection direction is **reversed**: the web app connects to the MCP server's WebSocket relay endpoint as a client. All 36 Relay routes work identically on both platforms.

### Two Modes of Operation

1. **Static mode** — Read pre-exported blueprint data (`.titan/blueprint.json`). Works without a running app. Tools: `get_terrain`, `get_stratagems`, `get_ai_prompt`, `get_dead_ends`, `get_unreliable_routes`, `get_route_patterns`.

2. **Live mode** — Connect to a running app via the Relay HTTP bridge. Required for real-time screen observation, action execution, and performance monitoring. Tools: `scry`, `scry_act`, `scry_diff`, `execute_campaign`, `relay_status`, `relay_terrain`, `generate_auth_stratagem`, `generate_campaign`, `audit_screen`, `get_performance`, `get_frame_history`, `get_page_loads`, `get_memory_snapshot`, `get_alerts`, `list_sessions`, `get_recording_status`, `get_framework_errors`, `get_api_metrics`, `get_api_errors`, `get_tremors`, `add_tremor`, `remove_tremor`, `reset_tremors`, `reload_page`, `get_widget_tree`, `get_events`, `replay_session`, `get_route_history`, `capture_screenshot`, `audit_accessibility`, `inspect_di`, `inspect_envoy`, `configure_envoy`, `toggle_lens`.

---

## Prerequisites

1. **Dart SDK** ≥ 3.10.3 (or Flutter ≥ 3.10.0)
2. **titan_colossus** package in your app's dependencies
3. **Dart SDK** and **Flutter** available on your PATH
4. Your Flutter app configured with `ColossusPlugin(enableRelay: true)` for live mode

### Verify Dart is available

```bash
dart --version
```

Note the path to your `dart` executable. You'll need it for IDE configuration:

```bash
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
flutter run -d macos    # or any device
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

#### Option C: With CLI overrides

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

#### Option E: HTTP+SSE transport (web-compatible)

For browser-based AI clients, remote environments, or when stdio isn't available,
use the SSE transport. This starts an HTTP server with `GET /sse` for
server→client events and `POST /message` for client→server JSON-RPC:

```bash
# Start the MCP server with SSE transport
dart run titan_colossus:blueprint_mcp_server \
  --transport sse --sse-port 3000
```

Configure VS Code to connect via SSE:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "type": "sse",
      "url": "http://localhost:3000/sse"
    }
  }
}
```

Additional CLI options for SSE:

| Flag | Default | Description |
|------|---------|-------------|
| `--transport` | `stdio` | Transport type: `stdio`, `sse`, `ws`, or `streamable` |
| `--sse-port` | `3000` | Port for the SSE HTTP server |
| `--sse-host` | `127.0.0.1` | Bind address (`0.0.0.0` for remote access) |
| `--relay-host` | `127.0.0.1` | Relay host (same as stdio mode) |
| `--relay-port` | `8642` | Relay port (same as stdio mode) |

**Endpoints:**

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/sse` | SSE stream — server→client JSON-RPC responses |
| `POST` | `/message` | Client→server JSON-RPC requests |
| `GET` | `/health` | Health check (returns transport info) |

#### Option F: WebSocket transport (bidirectional)

For full-duplex communication over a single connection, use the WebSocket
transport. Both JSON-RPC requests and responses flow over the same socket:

```bash
# Start the MCP server with WebSocket transport
dart run titan_colossus:blueprint_mcp_server \
  --transport ws --ws-port 3001
```

Configure a WebSocket-capable MCP client:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "type": "ws",
      "url": "ws://localhost:3001/ws"
    }
  }
}
```

Additional CLI options for WebSocket:

| Flag | Default | Description |
|------|---------|-------------|
| `--transport` | `stdio` | Transport type: `stdio`, `sse`, `ws`, or `streamable` |
| `--ws-port` | `3001` | Port for the WebSocket HTTP server |
| `--ws-host` | `127.0.0.1` | Bind address (`0.0.0.0` for remote access) |
| `--relay-host` | `127.0.0.1` | Relay host (same as stdio mode) |
| `--relay-port` | `8642` | Relay port (same as stdio mode) |

**Endpoints:**

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/ws` | WebSocket upgrade — bidirectional JSON-RPC |
| `GET` | `/health` | Health check (returns transport info) |

#### Option G: Streamable HTTP transport (MCP 2025-03-26)

The Streamable HTTP transport implements the latest MCP specification (2025-03-26),
superseding the older HTTP+SSE transport. It uses a single `/mcp` endpoint for
all communication, with optional session management via `Mcp-Session-Id`:

```bash
# Start the MCP server with Streamable HTTP transport
dart run titan_colossus:blueprint_mcp_server \
  --transport streamable --streamable-port 3002
```

Configure VS Code to connect via Streamable HTTP:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "type": "streamableHttp",
      "url": "http://localhost:3002/mcp"
    }
  }
}
```

Additional CLI options:

| Flag | Default | Description |
|------|---------|-------------|
| `--transport` | `stdio` | Transport type: `stdio`, `sse`, `ws`, or `streamable` |
| `--streamable-port` | `3002` | Port for the Streamable HTTP server |
| `--streamable-host` | `127.0.0.1` | Bind address (`0.0.0.0` for remote access) |
| `--relay-host` | `127.0.0.1` | Relay host (same as stdio mode) |
| `--relay-port` | `8642` | Relay port (same as stdio mode) |

**Endpoints:**

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/mcp` | Client sends JSON-RPC requests/notifications |
| `GET` | `/mcp` | Opens SSE stream for server-initiated messages |
| `DELETE` | `/mcp` | Terminates session (requires `Mcp-Session-Id`) |
| `GET` | `/health` | Health check (returns transport info) |

**Key features:**

- **Session management**: `initialize` returns an `Mcp-Session-Id` header
- **Direct JSON responses**: POST returns `application/json` (no SSE needed)
- **Batch support**: Send multiple JSON-RPC requests in a single POST
- **Clean shutdown**: DELETE terminates the session

#### Option H: Auto-detect transport (all-in-one)

Runs all HTTP transports on a single port, auto-detecting the protocol based
on the request path and headers. This is the most flexible option:

```bash
# Start with auto-detection on port 3000
dart run titan_colossus:blueprint_mcp_server \
  --transport auto --port 3000
```

Configure VS Code (Streamable HTTP is recommended for new clients):

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "type": "streamableHttp",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

| Flag | Default | Description |
|------|---------|-------------|
| `--transport` | `stdio` | Set to `auto` for all-in-one |
| `--port` | `3000` | Port for the auto-detect server |
| `--host` | `127.0.0.1` | Bind address |

**All endpoints available on one port:**

| Method | Path | Transport |
|--------|------|-----------|
| `POST` | `/mcp` | Streamable HTTP (2025-03-26) |
| `GET` | `/mcp` | Streamable HTTP server-push SSE |
| `DELETE` | `/mcp` | Streamable HTTP session termination |
| `GET` | `/ws` | WebSocket upgrade |
| `GET` | `/sse` | Legacy SSE stream (2024-11-05) |
| `POST` | `/message` | Legacy SSE JSON-RPC (2024-11-05) |
| `GET` | `/health` | Health check (lists available transports) |

#### WebSocket Client (Dart)

The `McpWebSocketClient` provides a Dart client with **auto-reconnect** and
**exponential backoff** for connecting to the MCP server over WebSocket:

```dart
import 'package:titan_colossus/titan_colossus.dart';

final client = McpWebSocketClient(
  Uri.parse('ws://localhost:3001/ws'),
  maxRetries: 10,          // Max consecutive retry attempts
  baseDelay: Duration(milliseconds: 500), // Initial backoff delay
  maxDelay: Duration(seconds: 30),        // Backoff cap
  heartbeatTimeout: Duration(seconds: 90), // Reconnect if no ping
);

await client.connect();

// Send JSON-RPC requests (returns full response map)
final response = await client.request('tools/list');
final tools = response['result']['tools'] as List;
print('${tools.length} tools available');

// Listen for server notifications
client.messages.listen((msg) {
  print('Notification: ${msg['method']}');
});

// Monitor connection status
client.status.listen((status) {
  print('Status: $status'); // connecting, connected, reconnecting, ...
});

await client.close();
```

**Features:**

| Feature | Description |
|---------|-------------|
| Auto-reconnect | Exponential backoff with ±25% jitter |
| Heartbeat | Responds to server `ping` with `pong`; reconnects on timeout |
| Message queue | Requests sent while disconnected are queued and flushed on reconnect |
| Status stream | `McpConnectionStatus` enum: `connecting`, `connected`, `disconnected`, `reconnecting`, `error`, `failed`, `closed` |

#### Verification

1. Open the Copilot Chat panel
2. Click the **Tools** icon (🔧) in the chat input area
3. You should see `titan-blueprint` listed with 48 tools
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
   - **Command:** `dart`
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
2. **Native**: `Relay.start()` binds an HTTP server on port **8642**
3. **Web**: `Relay.start()` connects via WebSocket to the MCP server's relay endpoint
4. The Relay takes approximately **12 seconds** to fully initialize
5. Shade recording becomes available for gesture capture
6. Scry becomes available for screen observation

### Web Relay Setup

On web, browsers cannot host HTTP servers. Instead, the connection direction is reversed — the web app connects **to** the MCP server's WebSocket relay endpoint.

**1. Configure the MCP server** with `--relay-ws-port`:

```jsonc
// .vscode/mcp.json
{
  "servers": {
    "titan-blueprint": {
      "command": "dart",
      "args": [
        "run", "bin/blueprint_mcp_server.dart",
        "--relay-ws-port", "8643"
      ],
      "cwd": "${workspaceFolder}/packages/titan_colossus"
    }
  }
}
```

**2. Configure your Flutter app** with `targetUrl`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

ColossusPlugin(
  enableRelay: true,
  relayConfig: kIsWeb
      ? const RelayConfig(targetUrl: 'ws://localhost:8643/relay')
      : const RelayConfig(),
)
```

**3. Run the app on web** — the Relay automatically connects to the MCP server's WebSocket endpoint with auto-reconnect and exponential backoff. All 36 Relay routes (scry, campaigns, recording, etc.) work identically.

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
| `--relay-ws-port` | *(none)* | WebSocket relay port for web apps. When set, the MCP server hosts a WebSocket endpoint on this port that web apps connect to |
| `--transport` | `stdio` | Transport type: `stdio`, `sse`, `ws`, `streamable`, or `auto` |
| `--tls-cert` | *(none)* | Path to TLS certificate chain (PEM). Enables HTTPS/WSS when paired with `--tls-key` |
| `--tls-key` | *(none)* | Path to TLS private key (PEM). Enables HTTPS/WSS when paired with `--tls-cert` |
| `--auth-token` | *(none)* | Add a Bearer token for authentication (repeatable for multiple tokens) |
| `--auth-tokens-file` | *(none)* | Path to a file containing tokens (one per line). File changes are hot-reloaded |

### TLS / SSL

All HTTP-based transports (SSE, WebSocket, Streamable HTTP, Auto) support TLS
when `--tls-cert` and `--tls-key` are both provided:

```bash
# Generate a self-signed certificate (for development)
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
  -days 365 -nodes -subj '/CN=localhost'

# Start the server with TLS
dart run titan_colossus:blueprint_mcp_server \
  --transport ws --ws-port 3001 \
  --tls-cert cert.pem --tls-key key.pem
```

Clients then connect over `https://` or `wss://` instead of `http://` or `ws://`.

For the Dart `McpWebSocketClient`, use `trustSelfSigned: true` with self-signed certs:

```dart
final client = McpWebSocketClient(
  Uri.parse('wss://localhost:3001/ws'),
  trustSelfSigned: true, // Development only — do not use in production
);
await client.connect();
```

### Authentication

All HTTP-based transports support Bearer token authentication when
`--auth-token` is provided. The health check endpoint (`GET /health`) always
remains public so monitoring tools can verify the server is running.

```bash
# Start the server with a single token
dart run titan_colossus:blueprint_mcp_server \
  --transport auto --auto-port 3001 \
  --auth-token my-secret-token
```

Clients must include the token in the `Authorization` header:

```
Authorization: Bearer my-secret-token
```

For **WebSocket** connections, browsers cannot set custom headers during the
handshake. As a fallback, the token can also be sent as a query parameter:

```
ws://localhost:3001/ws?token=my-secret-token
```

The `McpWebSocketClient` sends the token via both mechanisms automatically:

```dart
final client = McpWebSocketClient(
  Uri.parse('ws://localhost:3001/ws'),
  authToken: 'my-secret-token',
);
await client.connect();
```

#### Multiple Tokens

Pass `--auth-token` multiple times to accept several tokens concurrently.
This is useful during key rotation when both old and new tokens must work
simultaneously:

```bash
dart run titan_colossus:blueprint_mcp_server \
  --transport auto --auto-port 3001 \
  --auth-token old-token \
  --auth-token new-token
```

#### Token File with Hot-Reload

For production environments, use `--auth-tokens-file` to manage tokens in a
file. The file is watched for changes — tokens are reloaded automatically
without restarting the server.

```bash
# tokens.txt
# Primary API key
alpha-key-xxxxxxxx

# Secondary API key (rotation)
beta-key-yyyyyyyy
```

```bash
dart run titan_colossus:blueprint_mcp_server \
  --transport auto --auto-port 3001 \
  --auth-tokens-file tokens.txt
```

**Zero-downtime key rotation workflow:**

1. Add the new token to the file (keep the old one)
2. The server detects the file change and reloads — both tokens work
3. Update all clients to use the new token
4. Remove the old token from the file
5. The server reloads — only the new token is accepted

Blank lines and lines starting with `#` are ignored.

Combine TLS and authentication for production deployments:

```bash
dart run titan_colossus:blueprint_mcp_server \
  --transport auto --auto-port 3001 \
  --tls-cert cert.pem --tls-key key.pem \
  --auth-tokens-file /etc/titan/tokens.txt
```

```dart
final client = McpWebSocketClient(
  Uri.parse('wss://localhost:3001/ws'),
  authToken: 'my-secret-token',
  trustSelfSigned: true, // Only for self-signed certs in development
);
```

Requests without a valid token receive a **401** JSON-RPC error response:

```json
{
  "jsonrpc": "2.0",
  "error": { "code": -32001, "message": "Unauthorized" },
  "id": null
}
```

### Running manually (for testing)

```bash
cd packages/titan_colossus
dart run titan_colossus:blueprint_mcp_server

# With custom options
dart run titan_colossus:blueprint_mcp_server \
  --relay-host 192.168.1.50 \
  --relay-port 8642 \
  --blueprint-path /path/to/.titan/blueprint.json
```

---

## Tool Reference

The server exposes **48 tools** organized into eleven categories.

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

### Performance Monitoring

These tools provide detailed access to Colossus performance monitors in the running app.

| Tool | Description |
|------|-------------|
| **`get_performance`** | Full performance report (Decree) with health verdict (good/fair/poor), Pulse (FPS, jank rate, frame times), Stride (page load times), Vessel (Pillar count, leak suspects), Echo (widget rebuild counts). |
| **`get_frame_history`** | Per-frame timing history from Pulse. Up to 300 frames with build/raster durations (µs), jank flags, and timestamps. Use to investigate jank patterns. |
| **`get_page_loads`** | Individual page load records from Stride. Up to 100 entries with route paths, durations (ms), and timestamps. Use to find slow routes. |
| **`get_memory_snapshot`** | Live memory snapshot from Vessel. Returns Pillar count, DI instances, leak suspects with ages (seconds since first seen), and exempt types. |
| **`get_alerts`** | Fired Tremor performance alert history. Up to 200 alerts with names, categories (frame, pageLoad, memory, rebuild), severities (info, warning, error), messages, and timestamps. |

### Session & Recording

| Tool | Description |
|------|-------------|
| **`list_sessions`** | List saved Shade recording sessions from ShadeVault. Returns summaries with IDs, names, recording dates, durations, and event counts. Sorted newest first. |
| **`get_recording_status`** | Current Shade recording/replaying state. Shows whether recording or replaying is active, elapsed time, event count, performance recording state, and last session availability. |
| **`start_recording`** | Start a Shade recording session on the running app via Relay. Captures all interactions (taps, scrolls, text entry, navigation) for later replay or Blueprint generation. Avoids needing to manually tap the record button in the app UI. Params: `name` (optional), `description` (optional). |
| **`stop_recording`** | Stop the active Shade recording session. Returns session metadata (event count, duration, session ID). The recorded session is automatically fed to Scout for terrain analysis. Call `export_blueprint` after to save results. |
| **`export_blueprint`** | Export the current Blueprint (Terrain + Stratagems) to disk as `blueprint.json` and `blueprint-prompt.md`. Generates navigation graph from all recorded sessions and auto-generates edge-case test plans via Gauntlet. Params: `directory` (optional, defaults to `.titan`). |

### Error Detection

| Tool | Description |
|------|-------------|
| **`get_framework_errors`** | Captured Flutter framework errors (overflow, build, layout, paint, gesture). Shows errors from `FlutterError.onError` — including RenderFlex overflow, red error screen exceptions, and layout failures. Returns error category, message, library, truncated stack trace, and category breakdown. |

### API Monitoring (Envoy)

These tools require the Envoy HTTP client to be connected via `MetricsCourier` → `Colossus.trackApiMetric`.

| Tool | Description |
|------|-------------|
| **`get_api_metrics`** | Get tracked API metrics from Envoy HTTP client with latency percentiles (p50/p95/p99), success rate, and endpoint grouping. Shows all HTTP requests made through Envoy, including method, URL, status code, duration, success/failure, and caching status. Endpoints are auto-grouped by URL pattern (numeric IDs and UUIDs normalized). |
| **`get_api_errors`** | Get only failed API requests from Envoy HTTP client. Filters API metrics to show non-successful calls for quick error triage. Shows method, URL, status code, duration, and error message for each failed request. |

### Tremor Management

Manage Colossus performance alert thresholds at runtime.

| Tool | Description |
|------|-------------|
| **`get_tremors`** | Get the currently configured Tremor performance alert thresholds. Shows each tremor name, category (frame, pageLoad, memory, rebuild, api, custom), severity, and once-mode setting. Also reports the alert history count. |
| **`add_tremor`** | Add a new Tremor performance alert at runtime. Types: `fps` (threshold), `jankRate` (threshold), `pageLoad` (thresholdMs), `memory` (maxPillars), `rebuilds` (threshold + widget), `leaks`, `apiLatency` (thresholdMs), `apiErrorRate` (threshold). All accept optional `severity` (info/warning/error) and `once` (bool). |
| **`remove_tremor`** | Remove a Tremor performance alert by name. Use `get_tremors` first to see available names. Common names: `fps_low`, `jank_rate`, `page_load_slow`, `memory_high`, `excessive_rebuilds`, `leak_detected`, `api_latency_high`, `api_error_rate`. |
| **`reset_tremors`** | Reset all Tremor fired states, allowing once-mode tremors to fire again. Optionally clears the alert history. Params: `clearHistory` (bool, default false). |

### App Introspection

Tools for inspecting the running app's internals — widget tree, DI container, Envoy configuration, navigation history, and integration events.

| Tool | Description |
|------|-------------|
| **`get_widget_tree`** | Get a statistical summary of the current widget tree. Returns element count, max depth, unique widget types, and the top 20 most frequent widget types. Useful for understanding app structure and detecting bloat. |
| **`get_events`** | Get integration events from Colossus bridges (atlas, basalt, argus, bastion, custom). Events include route changes, circuit trips, auth state changes, and more. Params: `source` (optional filter). |
| **`get_route_history`** | Get the navigation route history from integration events. Shows all route changes (navigate, pop, replace, redirect) in chronological order, plus the current route. |
| **`replay_session`** | Replay a previously recorded Shade session from the ShadeVault. Loads the session by ID and replays all recorded gestures using Phantom. Returns replay stats including events dispatched, duration, and route changes. Params: `sessionId` (required), `speedMultiplier` (default 1.0). |
| **`capture_screenshot`** | Capture a screenshot of the running Flutter app. Returns both a saved PNG file and the image content inline (base64 PNG), allowing AI agents to visually inspect the screen. The `pixelRatio` controls resolution: 0.5 = half (default, smaller payload), 1.0 = full logical, 2.0 = retina. Screenshots are saved to `.titan/screenshots/`. |
| **`audit_accessibility`** | Audit the current screen for accessibility issues. Detects: interactive elements without semantic labels, touch targets smaller than 48×48 dp, and missing semantic roles. Returns a summary with issue count and detailed issue list. |
| **`inspect_di`** | Inspect the Titan DI container (Vault). Lists all registered types, showing which are instantiated vs lazy (unresolved factories), and which are Pillar subclasses. Useful for debugging dependency wiring. |
| **`inspect_envoy`** | Inspect the Envoy HTTP client configuration and active courier (interceptor) chain. Shows base URL, timeouts, default headers, and per-courier configuration. |
| **`configure_envoy`** | Configure the Envoy HTTP client at runtime. Can change base URL, timeouts, redirect settings, add/remove default headers, add/remove couriers (interceptors), or clear all couriers. Returns applied changes and the resulting configuration. |
| **`reload_page`** | Reload the current page. By default, re-navigates to the current route (like a browser refresh — re-triggers guards, builders, and data loading). With `fullRebuild: true`, triggers `reassembleApplication()` for a full widget tree rebuild. |

### UI Control

| Tool | Description |
|------|-------------|
| **`toggle_lens`** | Show or hide the Lens debug FAB (floating action button) in the running app. Use `visible=false` to hide the FAB when AI agents are in control — the manual debug button is unnecessary during MCP sessions. The Lens panel can still be opened programmatically. Call with `visible=true` to restore. |

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

### Performance analysis

> "Check the app's performance — any jank, memory leaks, or slow pages?"

The AI will:
1. Call `get_performance` for a health summary
2. Call `get_frame_history` to inspect janky frames
3. Call `get_memory_snapshot` to check for leak suspects
4. Call `get_alerts` to review fired Tremor alerts
5. Call `get_page_loads` to find slow route transitions

### Recording session management

> "Is there a recording in progress? Show me saved sessions"

The AI will:
1. Call `get_recording_status` to check current state
2. Call `list_sessions` to list saved ShadeVault recordings

### Zero-touch Blueprint generation

> "Create a blueprint by exploring the app"

The AI will:
1. Call `start_recording` with a descriptive name (e.g., `"full_app_exploration"`)
2. Call `scry` to observe the current screen
3. Call `scry_act` to navigate through the app (tap tabs, open screens, fill forms)
4. Repeat steps 2–3 to cover all screens and flows
5. Call `stop_recording` — the session is automatically analyzed by Scout
6. Call `export_blueprint` — saves `blueprint.json` + `blueprint-prompt.md` to `.titan/`

No manual app interaction needed — the AI records, navigates, and exports autonomously.

### Error detection

> "Are there any overflow or build errors in the app?"

The AI will:
1. Call `get_framework_errors` to check for captured `FlutterError.onError` reports
2. Report overflow, build, layout, paint, and gesture errors by category
3. Call `scry` to check for any `ErrorWidget` (red error screen) on the current view

### Take a screenshot and analyze visually

> "Capture a screenshot of the current screen"

The AI will:
1. Call `capture_screenshot` with a pixel ratio of 0.5
2. Receive both a saved PNG file path and the image content inline
3. Visually analyze the screenshot to describe what's on screen

### API performance analysis

> "Show me API errors and slow endpoints"

The AI will:
1. Call `get_api_metrics` for a full breakdown of HTTP requests
2. Call `get_api_errors` to isolate failed requests
3. Report latency percentiles, error rates, and slow endpoints

### Accessibility audit

> "Check this screen for accessibility problems"

The AI will:
1. Call `audit_accessibility` to scan the widget tree
2. Report missing semantic labels, undersized touch targets, and missing roles

### Runtime configuration

> "Hide the debug FAB and set up a performance alert for slow pages"

The AI will:
1. Call `toggle_lens` with `visible=false` to hide the FAB
2. Call `add_tremor` with `type=pageLoad` and `thresholdMs=3000` to alert on slow page loads

### Inspect app internals

> "What's registered in the DI container? What routes has the user visited?"

The AI will:
1. Call `inspect_di` to list all Vault registrations
2. Call `get_route_history` to show the navigation path

---

## Physical Device & Emulator Setup

The MCP server runs on your **development machine** and connects to the Relay HTTP server running **inside the Flutter app**. The network path between them varies by platform:

```
┌──────────────────┐          ┌──────────────────────────┐
│  MCP Server      │  HTTP    │  Flutter App (Relay)     │
│  (dev machine)   │ -------> │  (device / emulator)     │
│  localhost:*      │  :8642  │  0.0.0.0:8642            │
└──────────────────┘          └──────────────────────────┘
```

### Same Machine (Desktop App)

Default configuration works out of the box. The Relay binds to `localhost:8642`.

```json
{
  "command": "dart",
  "args": ["run", "titan_colossus:blueprint_mcp_server"],
  "cwd": "packages/titan_colossus"
}
```

---

### iOS Simulator

No extra configuration needed — the iOS Simulator shares the host's network stack. `localhost:8642` in the MCP server reaches the Relay inside the simulator directly.

```json
{
  "command": "dart",
  "args": ["run", "titan_colossus:blueprint_mcp_server"],
  "cwd": "packages/titan_colossus"
}
```

---

### iOS Physical Device (USB)

iOS physical devices do **not** share the host's network. You need port forwarding via `iproxy` (included with `libimobiledevice`).

**1. Install `libimobiledevice`:**

```bash
brew install libimobiledevice
```

**2. Connect the device via USB and trust the computer** (tap "Trust" on the device if prompted).

**3. Forward port 8642:**

```bash
iproxy 8642 8642
```

This maps your Mac's `localhost:8642` to the device's port `8642`. Keep this terminal open while testing.

**4. Use default MCP configuration** (no `--relay-host` override needed):

```json
{
  "command": "dart",
  "args": ["run", "titan_colossus:blueprint_mcp_server"],
  "cwd": "packages/titan_colossus"
}
```

**Alternative — Wi-Fi (same network):**

If USB is unavailable, use the device's IP address:

```bash
# Find your iOS device's IP: Settings → Wi-Fi → tap (i) on connected network
```

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

> **Security note:** When using Wi-Fi, the Relay is exposed on the local network. Use `--relay-token` for authentication:
>
> ```dart
> ColossusPlugin(
>   enableRelay: true,
>   relayConfig: RelayConfig(authToken: 'my-secret-token'),
> )
> ```
>
> ```json
> "args": ["run", "titan_colossus:blueprint_mcp_server", "--relay-host", "192.168.1.50", "--relay-token", "my-secret-token"]
> ```

---

### Android Emulator

The Android emulator uses a virtual network where `10.0.2.2` maps to the host machine's `localhost`. Since the **MCP server runs on the host** and connects to the Relay inside the emulator, you need `adb` port forwarding to bridge the connection.

**1. Set up port forwarding:**

```bash
adb forward tcp:8642 tcp:8642
```

This maps the host's `localhost:8642` to the emulator's port `8642`.

**2. Use default MCP configuration** (no `--relay-host` override needed):

```json
{
  "command": "dart",
  "args": ["run", "titan_colossus:blueprint_mcp_server"],
  "cwd": "packages/titan_colossus"
}
```

**Verify forwarding is active:**

```bash
adb forward --list
# Should show: <device-serial> tcp:8642 tcp:8642
```

**Remove forwarding when done:**

```bash
adb forward --remove tcp:8642
```

> **Note:** Port forwarding persists across app restarts but is removed when the emulator shuts down. Re-run `adb forward` after rebooting the emulator.

---

### Android Physical Device (USB)

Android physical devices connected via USB also use `adb forward` — the same mechanism as emulators.

**1. Enable USB debugging** on the device:
   - Go to **Settings → About phone** → Tap **Build number** 7 times
   - Go to **Settings → Developer options** → Enable **USB debugging**

**2. Connect the device via USB** and authorize the computer (tap "Allow" on the device).

**3. Verify the device is recognized:**

```bash
adb devices
# Should show your device serial number
```

**4. Forward port 8642:**

```bash
adb forward tcp:8642 tcp:8642
```

**5. Use default MCP configuration:**

```json
{
  "command": "dart",
  "args": ["run", "titan_colossus:blueprint_mcp_server"],
  "cwd": "packages/titan_colossus"
}
```

**Multiple devices connected:**

If you have multiple devices/emulators connected, specify the target:

```bash
# List all devices
adb devices

# Forward for a specific device
adb -s <device-serial> forward tcp:8642 tcp:8642
```

**Alternative — Wi-Fi (same network):**

```bash
# Find your Android device's IP: Settings → Network → Wi-Fi → Connected network
```

```json
{
  "command": "dart",
  "args": [
    "run", "titan_colossus:blueprint_mcp_server",
    "--relay-host", "192.168.1.60",
    "--relay-port", "8642"
  ],
  "cwd": "packages/titan_colossus"
}
```

---

### ADB Wireless Debugging (Android 11+)

For cable-free debugging with `adb` port forwarding over Wi-Fi:

**1. Enable wireless debugging:**
   - Go to **Settings → Developer options → Wireless debugging** → Enable
   - Tap **Pair device with pairing code**

**2. Pair from your computer:**

```bash
adb pair <device-ip>:<pairing-port>
# Enter the pairing code shown on device
```

**3. Connect:**

```bash
adb connect <device-ip>:<port>
# Use the port shown under "Wireless debugging" (NOT the pairing port)
```

**4. Forward the Relay port:**

```bash
adb forward tcp:8642 tcp:8642
```

Now use default MCP configuration — `localhost:8642` reaches the device over Wi-Fi.

---

### Quick Reference Table

| Platform | Setup Required | Command | MCP `--relay-host` |
|----------|---------------|---------|-------------------|
| Desktop app | None | — | `127.0.0.1` (default) |
| iOS Simulator | None | — | `127.0.0.1` (default) |
| iOS Device (USB) | `iproxy` | `iproxy 8642 8642` | `127.0.0.1` (default) |
| iOS Device (Wi-Fi) | Device IP | — | Device IP |
| Android Emulator | `adb forward` | `adb forward tcp:8642 tcp:8642` | `127.0.0.1` (default) |
| Android Device (USB) | `adb forward` | `adb forward tcp:8642 tcp:8642` | `127.0.0.1` (default) |
| Android Device (Wi-Fi) | Device IP | — | Device IP |
| Web | MCP `--relay-ws-port` | `--relay-ws-port 8643` | WebSocket via MCP server |

### Web

On web, browsers cannot host HTTP servers. The connection direction is **reversed** — the web app connects **to** the MCP server's WebSocket relay endpoint. See [Web Relay Setup](#web-relay-setup) above for configuration details. All 48 tools work identically on both native and web platforms.

---

## Troubleshooting

### MCP server not showing up in IDE

| Symptom | Fix |
|---------|-----|
| Server not listed | Restart IDE after adding configuration |
| "command not found: dart" | Ensure `dart` is on your PATH or use absolute path (e.g., `which dart`) |
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
"command": "/path/to/your/dart"
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
