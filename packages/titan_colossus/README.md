# Titan Colossus

<p align="center">
  <img src="https://raw.githubusercontent.com/Ikolvi/titan/main/assets/titan_banner.webp" width="100%" alt="Titan Banner" />
</p>

**Enterprise-grade performance monitoring for the Titan ecosystem.**

Colossus — named after the Colossus of Rhodes, a representation of the Titan Helios — stands watch over your app's performance, seeing every frame, every navigation, every allocation.

[![Pub Version](https://img.shields.io/pub/v/titan_colossus)](https://pub.dev/packages/titan_colossus)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

| Feature | Titan Name | What it does |
|---------|-----------|--------------|
| Frame Monitoring | **Pulse** | FPS, jank detection, build/raster timing |
| Page Load Timing | **Stride** | Time-to-first-paint per route navigation |
| Memory Monitoring | **Vessel** | Pillar count, DI instance tracking, leak detection |
| Rebuild Tracking | **Echo** | Widget rebuild counting via wrapper widget |
| Performance Alerts | **Tremor** | Configurable threshold alerts via Herald |
| Performance Reports | **Decree** | Aggregated metrics with health verdict |
| Report Export | **Inscribe** | Export as Markdown, JSON, or HTML |
| Gesture Recording | **Shade** | Record user interactions as replayable macros |
| Gesture Replay | **Phantom** | Replay recorded sessions with synthetic events |
| Debug Overlay | **Lens** | In-app debug overlay with extensible plugin tabs |
| Lens Tabs | **Lens Tab** | Auto-registered "Perf", "Shade", and "Blueprint" tabs |
| Route Integration | **Atlas Observer** | Automatic page load timing via Atlas |
| AI Test Discovery | **Scout** | Passive session analyzer building a flow graph |
| Flow Graph | **Terrain** | Screen/transition map with dead-end & reliability detection |
| Edge-Case Tests | **Gauntlet** | Auto-generate targeted Stratagems for any screen |
| Test Execution | **Campaign** | Multi-route test orchestrator with setup/teardown |
| Test Results | **Verdict** / **Debrief** | Per-step results & aggregated analysis with fix suggestions |
| Blueprint Overlay | **Blueprint Tab** | Interactive Lens tab for AI-assisted test generation |
| Auto-Integration | **ColossusPlugin** | Zero-code Atlas + Shade → Scout wiring |
| Blueprint Export | **BlueprintExport** | Export Terrain, Stratagems & Verdicts to JSON/Markdown for AI assistants |
| Export CLI | **export_blueprint** | Offline Blueprint export from saved Shade sessions |
| MCP Server | **blueprint_mcp_server** | Model Context Protocol server for Copilot/Claude integration |
| Screen Observation | **Scry** | AI agent interface with 18 intelligence capabilities |
| Screen Snapshots | **Tableau** | Element tree snapshot with interactive widget detection |
| Element Capture | **Glyph** | UI element abstraction with label, bounds, and interaction type |
| HTTP Interception | **Sentinel** | Charles Proxy-like HTTP traffic capture built into the app |
| DevTools Bridge | **DevToolsBridge** | Expose Colossus data to Flutter DevTools via `dart:developer` |

## Quick Start

### 1. Add dependency

```yaml
dev_dependencies:
  titan_colossus: ^1.0.0
```

### 2. Initialize via plugin (recommended)

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  runApp(
    Beacon(
      pillars: [MyPillar.new],
      plugins: [
        if (kDebugMode) ColossusPlugin(
          tremors: [Tremor.fps(), Tremor.leaks()],
          // HTTP Interception — capture all network traffic
          enableSentinel: true,
          sentinelConfig: const SentinelConfig(
            excludePatterns: [r'localhost:864\d'], // Skip Relay traffic
          ),
          // AI Blueprint Generation — all enabled by default
          enableTableauCapture: true,   // Shade records screen metadata
          autoLearnSessions: true,      // Shade → Scout auto-feed
          autoAtlasIntegration: true,   // Auto-wire Atlas observer & routes
          // AI-Bridge Export — auto-save Blueprint on app shutdown
          blueprintExportDirectory: '.titan',
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

One line to add, one line to remove. ColossusPlugin handles `Colossus.init()`, wraps with `Lens` and `ShadeListener`, auto-wires Atlas observer, feeds Shade recordings into Scout, and calls `Colossus.shutdown()` on dispose.

### Manual initialization (alternative)

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  if (kDebugMode) {
    Colossus.init(
      tremors: [
        Tremor.fps(),
        Tremor.leaks(),
        Tremor.pageLoad(),
      ],
    );
  }

  runApp(
    Lens(
      enabled: kDebugMode,
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

That's it. Colossus auto-registers its Lens tab and begins monitoring.

### Usage without Titan state management

Colossus works with **any** Flutter architecture — Bloc, Riverpod, Provider, GetX, or vanilla `setState`. You don't need to use Titan's `Pillar`, `Core`, `Vestige`, or `Beacon` for your app's business logic. Colossus manages its own state internally.

#### ColossusBindings — the abstraction layer

Colossus uses a **bindings system** that decouples its internals from Titan. By default, `TitanBindings` is installed (for Chronicle logging, Herald events, Vigil errors, and Titan DI). For non-Titan apps, call `installDefaults()` to use lightweight standalone implementations:

| Binding | TitanBindings (default) | installDefaults() |
|---------|------------------------|-------------------|
| Logger | Chronicle | `dart:developer` log() |
| Event bus | Herald | StreamController |
| Error reporter | Vigil | In-memory list |
| Service locator | Titan DI | Map-based lookup |
| Reactive values | Core | ChangeNotifier |

#### With Bloc / Provider / Riverpod

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // Use standalone bindings — no Titan integration required
  ColossusBindings.installDefaults();

  if (kDebugMode) {
    Colossus.init(
      tremors: [Tremor.fps(), Tremor.leaks()],
      enableSentinel: true,
      sentinelConfig: const SentinelConfig(
        excludePatterns: [r'localhost:864\d'],
      ),
    );
  }

  runApp(
    // Use your preferred state management — no Beacon required
    BlocProvider(               // Bloc
      create: (_) => MyCubit(),
      child: Lens(              // Colossus debug overlay
        enabled: kDebugMode,
        child: MaterialApp(
          home: const MyHomePage(),
        ),
      ),
    ),
  );
}
```

#### Custom bindings (advanced)

For deeper integration with your framework, create custom bindings:

```dart
class BlocBindings extends ColossusBindings {
  BlocBindings()
      : super(
          createLogger: DefaultLogger.new,
          eventBus: DefaultEventBus(),
          errorReporter: DefaultErrorReporter(),
          serviceLocator: DefaultServiceLocator(),
          createReactiveValue: <T>(T initial) =>
              DefaultReactiveValue<T>(initial),
        );
}

void main() {
  ColossusBindings.install(BlocBindings());
  Colossus.init();
  runApp(const MyBlocApp());
}
```

#### What works without Titan state management

All Colossus features work without Beacon or Pillar:
- **Pulse** (FPS), **Stride** (page loads), **Vessel** (memory), **Echo** (rebuilds)
- **Tremor** performance alerts
- **Sentinel** HTTP interception
- **DevToolsBridge** service extensions and timeline
- **Shade** recording & **Phantom** replay
- **Scry** AI testing & **Campaign** execution
- **Lens** debug overlay
- **Scout** / **Terrain** / **Gauntlet** discovery
- **MCP** / **Relay** remote bridge

> **Note:** `Vessel` Pillar leak detection is less useful in non-Titan apps since it monitors Titan's DI registry. All other features are fully framework-agnostic.

#### Sentinel standalone (zero Titan dependency)

Sentinel itself has no Titan imports — it uses only `dart:io` and `dart:convert`. You can use it as a lightweight HTTP interceptor without installing Colossus:

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  Sentinel.install(
    config: SentinelConfig(
      excludePatterns: [r'analytics\.'],
      maxBodyCapture: 32 * 1024,
    ),
    onRecord: (record) {
      debugPrint('${record.method} ${record.url} → '
          '${record.statusCode} (${record.duration.inMilliseconds}ms)');
    },
  );

  runApp(const MyApp());

  // Later: Sentinel.uninstall();
}
```

#### Manual page load timing

Without Atlas, record page load times manually:

```dart
final sw = Stopwatch()..start();
await loadData();
sw.stop();
Colossus.instance.stride.record('/my-page', sw.elapsed);
```

#### Manual Shade recording

Without Atlas/Beacon, wrap your widget tree manually:

```dart
ShadeListener(
  shade: Colossus.instance.shade,
  child: MaterialApp(home: const MyApp()),
)
```

## The Colossus Lexicon

| Component | Symbol | Purpose |
|-----------|--------|---------|
| `Colossus` | 🏛️ | Main Pillar — singleton orchestrator |
| `Pulse` | 💓 | Frame rendering metrics |
| `Stride` | 🦶 | Page load timing |
| `Vessel` | 🏺 | Memory monitoring & leak detection |
| `Echo` | 🔁 | Widget rebuild tracking |
| `Tremor` | 🌍 | Performance alert threshold |
| `Decree` | 📜 | Aggregated performance report |
| `Inscribe` | ✍️ | Export decree as Markdown, JSON, or HTML |
| `InscribeIO` | 💾 | Save export files to disk |
| `Mark` | 📍 | Base performance measurement |
| `FrameMark` | 🎞️ | Single frame timing |
| `PageLoadMark` | 📄 | Single page load timing |
| `MemoryMark` | 🧠 | Memory state snapshot |
| `RebuildMark` | ♻️ | Widget rebuild snapshot |
| `LeakSuspect` | 💧 | Suspected memory leak |
| `Shade` | 👤 | Gesture recording controller |
| `Imprint` | 👣 | Single recorded pointer event |
| `ShadeSession` | 📼 | Complete recorded interaction session |
| `Phantom` | 👻 | Replays sessions via handlePointerEvent |
| `PhantomResult` | 📊 | Replay outcome statistics |
| `ShadeListener` | 👂 | Transparent widget capturing pointer events |
| `ColossusPlugin` | 🔌 | One-line Beacon plugin for full Colossus integration |
| `Scout` | 🔭 | Passive session analyzer — builds flow graph from recordings |
| `Terrain` | 🗺️ | Screen/transition graph with dead-end & reliability detection |
| `Outpost` | 🏕️ | Single screen node in the Terrain graph |
| `March` | 🚶 | Directed edge between two Outposts (navigation transition) |
| `Lineage` | 🧬 | Resolves parameterized routes (e.g. `/quest/:id` → `/quest/42`) |
| `RouteParameterizer` | 📐 | Registers known route patterns for Lineage resolution |
| `Gauntlet` | ⚔️ | Auto-generates edge-case Stratagems for any Outpost |
| `Stratagem` | 📋 | Single test scenario: steps, setup, teardown, expected outcomes |
| `Campaign` | 🎯 | Multi-route test orchestrator with setup/teardown lifecycle |
| `Verdict` | ⚖️ | Per-step test result with outcome and diagnostics |
| `Debrief` | 📝 | Aggregated campaign analysis with fix suggestions |
| `Signet` | 🔖 | Type-safe screen identifier for Outpost lookup |
| `BlueprintLensTab` | 🗂️ | Interactive Lens tab with 5 sub-tabs for Blueprint data |
| `BlueprintExport` | 📦 | Structured export container for Terrain, Stratagems & Verdicts |
| `BlueprintExportIO` | 💾 | File I/O for saving/loading Blueprint exports |
| `BlueprintSaveResult` | ✅ | Result object from `saveAll()` with JSON and prompt paths |
| `Scry` | 👁️ | AI agent interface — observes screens, acts on elements |
| `ScryGaze` | 🔮 | Observation result with classified elements and intelligence |
| `ScryElement` | 🎯 | Single observable element (button, field, nav, content) |
| `ScryElementKind` | 🏷️ | Element classification enum |
| `ScryScreenType` | 📱 | Screen type classification (login, form, list, etc.) |
| `ScryAlert` | ⚡ | Detected error, warning, info, or loading state |
| `ScryDiff` | 🔄 | Before/after screen comparison |
| `Tableau` | 📸 | Element tree snapshot captured from live widget tree |
| `TableauCapture` | 🔍 | Static walker — extracts Glyphs from the Element tree |
| `Glyph` | ✨ | Single captured UI element (type, label, bounds, interaction) |
| `Sentinel` | 🕵️ | Silent HTTP interception via `HttpOverrides` |
| `SentinelRecord` | 📝 | Complete HTTP transaction record (request + response + timing) |
| `SentinelConfig` | ⚙️ | Filtering, body capture limits, and retention settings |
| `DevToolsBridge` | 🔗 | Connects Colossus to Flutter DevTools (extensions, timeline, events) |

## Usage

### Pulse — Frame Monitoring

Pulse automatically tracks every frame via Flutter's `addTimingsCallback`:

```dart
final colossus = Colossus.instance;
print('FPS: ${colossus.pulse.fps}');
print('Jank rate: ${colossus.pulse.jankRate}%');
print('Avg build: ${colossus.pulse.avgBuildTime.inMicroseconds}µs');
```

### Stride — Page Load Timing

Automatic with Atlas:

```dart
final atlas = Atlas(
  passages: [...],
  observers: [ColossusAtlasObserver()],
);
```

Manual timing:

```dart
final sw = Stopwatch()..start();
await loadHeavyData();
sw.stop();
Colossus.instance.stride.record('/data', sw.elapsed);
```

### Vessel — Memory & Leak Detection

Vessel periodically checks Titan's DI registry for Pillar lifecycle anomalies:

```dart
Colossus.init(
  vesselConfig: VesselConfig(
    leakThreshold: Duration(minutes: 3),
    exemptTypes: {'AuthPillar', 'AppPillar'}, // Long-lived, not leaks
  ),
);
```

### Echo — Rebuild Tracking

Wrap widgets to track their rebuild count:

```dart
Echo(
  label: 'QuestList',
  child: QuestListWidget(),
)
```

View rebuild data in the Lens "Perf" tab or via code:

```dart
final rebuilds = Colossus.instance.rebuildsPerWidget;
print(rebuilds); // {QuestList: 42, HeroProfile: 7}
```

### Tremor — Performance Alerts

Configure alerts that emit Herald events when thresholds are breached:

```dart
Colossus.init(
  tremors: [
    Tremor.fps(threshold: 50),                          // FPS < 50
    Tremor.jankRate(threshold: 10),                      // > 10% jank
    Tremor.pageLoad(threshold: Duration(seconds: 1)),    // > 1s load
    Tremor.memory(maxPillars: 30),                       // > 30 Pillars
    Tremor.rebuilds(threshold: 100, widget: 'QuestList'),// > 100 rebuilds
    Tremor.leaks(),                                      // Any leak suspect
  ],
);

// Listen for alerts via Herald
Herald.on<ColossusTremor>((event) {
  print('⚠️ ${event.message}');
});
```

### Decree — Performance Reports

Generate a comprehensive performance report:

```dart
final report = Colossus.instance.decree();

print(report.health);    // PerformanceHealth.good
print(report.summary);   // Full formatted report

// Drill into specifics
print(report.avgFps);
print(report.jankRate);
print(report.slowestPageLoad?.path);
print(report.topRebuilders(5));
```

### Inscribe — Export Reports

Export the Decree as Markdown, JSON, or a self-contained HTML dashboard:

```dart
final decree = Colossus.instance.decree();

// Markdown — great for GitHub issues, PRs, documentation
final md = Inscribe.markdown(decree);

// JSON — great for CI pipelines, dashboards, data analysis
final json = Inscribe.json(decree);

// HTML — self-contained visual dashboard (no external deps)
final html = Inscribe.html(decree);
```

Convenience methods on Colossus:

```dart
final md   = Colossus.instance.inscribeMarkdown();
final json = Colossus.instance.inscribeJson();
final html = Colossus.instance.inscribeHtml();
```

### Save to Disk

Use `InscribeIO` to persist reports to the file system (mobile, desktop, server — not web):

```dart
// Save individual formats
final path = await InscribeIO.saveHtml(decree, directory: '/tmp');
print('Report saved to $path');

// Save all three formats at once
final result = await InscribeIO.saveAll(decree, directory: '/reports');
print(result.markdown); // /reports/colossus-decree-20250115-100530.md
print(result.json);     // /reports/colossus-decree-20250115-100530.json
print(result.html);     // /reports/colossus-decree-20250115-100530.html
```

### Lens Integration

Colossus auto-registers two tabs in the Lens debug overlay:

**Perf tab** with sub-tabs:
- **Pulse** — Real-time FPS, jank rate, frame bar chart
- **Stride** — Page load history with timing
- **Vessel** — Pillar count, instance count, leak suspects
- **Echo** — Widget rebuild counts sorted by frequency
- **Export** — Copy/save reports in Markdown, JSON, HTML

**Shade tab** with controls for:
- Starting/stopping gesture recording
- Viewing last recorded session info
- Replaying sessions with progress tracking
- Viewing replay results

### Shade — Gesture Recording & Replay

Record real user interactions, then replay them as automated macros:

```dart
final shade = Colossus.instance.shade;

// Start recording
shade.startRecording(name: 'checkout_flow');

// ... user interacts with the app ...

// Stop and get the session
final session = shade.stopRecording();
print('Recorded ${session.eventCount} events');

// Save for later
final json = session.toJson();

// Replay while monitoring performance
final result = await Colossus.instance.replaySession(session);
final decree = Colossus.instance.decree();
print(decree.summary);
```

Wrap your app with `ShadeListener` to capture all pointer events:

```dart
ShadeListener(
  shade: Colossus.instance.shade,
  child: MaterialApp(...),
)
```

#### Text Input Recording

For text input recording and replay, use Spark's `useTextController` hook.
When `Colossus.init()` is called, it automatically registers a factory
that creates `ShadeTextController` instances — recording-aware controllers
that capture every text change during a Shade recording session.

```dart
// In a Spark widget — text input is automatically recorded
class MyForm extends Spark {
  @override
  Widget build(BuildContext context) {
    final nameController = useTextController(fieldId: 'user_name');
    final emailController = useTextController(fieldId: 'user_email');

    return Column(
      children: [
        TextField(controller: nameController),
        TextField(controller: emailController),
      ],
    );
  }
}
```

The `fieldId` parameter enables accurate text replay — Phantom matches
recorded text events to the correct field by ID. Without `fieldId`,
Phantom falls back to injecting text into the currently focused field.

### Widget Detection — TableauCapture & Glyphs

TableauCapture walks the live Flutter Element tree and extracts **Glyphs** —
standardized representations of every meaningful widget on screen. These
Glyphs feed into Shade recordings, Scout analysis, and Scry observation.

#### Supported Interactive Widgets

The following widget types are automatically detected as interactive
and captured with their label, bounds, enabled state, and interaction type:

| Widget | Interaction Type | Enabled Detection |
|--------|-----------------|--------------------|
| `ElevatedButton`, `TextButton`, `FilledButton`, `OutlinedButton` | tap | `widget.enabled` |
| `IconButton` | tap | `onPressed != null` |
| `FloatingActionButton` | tap | always |
| `GestureDetector` | tap / longPress | `onTap`, `onLongPress`, or `onDoubleTap != null` |
| `InkWell` | tap | `onTap != null` |
| `TextField`, `TextFormField` | textInput | `widget.enabled` |
| `Checkbox` | checkbox | `onChanged != null` |
| `Radio` | radio | `onChanged != null` |
| `Switch` | switch | `onChanged != null` |
| `Slider` | slider | `onChanged != null` |
| `DropdownButton`, `PopupMenuButton` | dropdown | always |
| `ListTile` | tap | `widget.enabled` |
| `ExpansionTile` | tap | always |
| `NavigationDestination` | tap | always |
| `TabBar` | tap | always |
| `SegmentedButton` | tap | always |
| `SearchBar` | tap | always |
| `MenuAnchor` | tap | always |
| `Autocomplete` | tap | always |

#### Label Extraction

Labels are extracted automatically in priority order:

1. **Child `Text` widget** — `ElevatedButton(child: Text('Save'))` → `"Save"`
2. **Decoration hint/label** — `TextField(decoration: InputDecoration(labelText: 'Email'))` → `"Email"`
3. **Tooltip or semantic label** — `IconButton(tooltip: 'Delete')` → `"Delete"`
4. **Semantics label** — `Semantics(label: 'Close menu')` → `"Close menu"`
5. **Widget key** — `GestureDetector(key: ValueKey('avatar-tap'))` → `"avatar-tap"`
6. **Positional fallback** — `GestureDetector(onTap: ...)` → `"tap@120,340"`

Steps 5–6 ensure that `GestureDetector` and `InkWell` widgets without
text children are still discoverable by Scry. For best results, add a
`Key` to interactive widgets that wrap non-text children:

```dart
// ✅ Discoverable by Scry via key
GestureDetector(
  key: const ValueKey('profile-avatar'),
  onTap: () => navigateToProfile(),
  child: CircleAvatar(backgroundImage: userImage),
)

// ⚠️ Still discoverable, but targeted by coordinates
GestureDetector(
  onTap: () => navigateToProfile(),
  child: CircleAvatar(backgroundImage: userImage),
)
```

#### Visible Content Widgets

These widgets are captured as non-interactive content (display-only):

`Text`, `RichText`, `Image`, `Icon`, `AppBar`, `Card`, `Dialog`,
`AlertDialog`, `SimpleDialog`, `SnackBar`, `BottomSheet`, `Chip`,
`Badge`, `Banner`, `Tooltip`, `Drawer`, `CircularProgressIndicator`,
`LinearProgressIndicator`, `ErrorWidget`

All other widgets (`Container`, `Padding`, `Row`, `Column`, `Center`,
`Align`, `Builder`, etc.) are classified as layout noise and skipped.

#### Deduplication

Material buttons produce nested interactive layers (e.g.,
`FilledButton` → `InkWell` → `GestureDetector`). TableauCapture
automatically suppresses inner layers that share the same label,
so each logical button produces exactly one Glyph.

---

### Scry — AI Agent Interface

Scry gives AI assistants (via MCP) live vision of the running app.
Instead of executing pre-written Campaigns, the AI observes the screen,
decides what to do, acts, and observes the result.

#### The Agent Loop

```
scry (observe) → AI decides → scry_act (act) → scry_diff (compare) → repeat
```

#### Observing

```dart
const scry = Scry();
final gaze = scry.observe(glyphs, route: '/login');

gaze.buttons;     // Tappable elements (ElevatedButton, GestureDetector, InkWell, ...)
gaze.fields;      // Text inputs with current values
gaze.navigation;  // Tab bars, nav items
gaze.content;     // Display-only text and images
gaze.gated;       // ⚠️ Destructive actions (delete, remove, reset)
gaze.screenType;  // ScryScreenType.login, .form, .list, etc.
gaze.alerts;      // Errors, warnings, loading indicators
gaze.dataFields;  // Detected key-value data pairs
gaze.suggestions; // Context-aware action recommendations
```

#### Screen Types

| Type | Detection Logic |
|------|----------------|
| `login` | Text fields + login/signin/enter button |
| `form` | Multiple fields + submit/save button |
| `list` | Many similar content items, no fields |
| `detail` | Key-value data pairs, no input fields |
| `settings` | Toggles, switches, checkboxes, dropdowns |
| `empty` | Very few elements, no meaningful content |
| `error` | Error alerts visible (snackbar, error text) |
| `dashboard` | Mix of navigation, content, and buttons |
| `unknown` | Cannot be classified |

#### Element Classification

| Kind | Description |
|------|-------------|
| `button` | Tappable interactive elements (buttons, GestureDetector, InkWell) |
| `field` | Text input fields (TextField, TextFormField, EditableText) |
| `navigation` | Tab bar, nav bar, drawer items |
| `content` | Display-only text, images, icons |
| `structural` | AppBar titles, toolbar labels |

#### Acting

```json
{"action": "tap", "label": "Sign Out"}
{"action": "enterText", "label": "Hero Name", "value": "Arcturus"}
{"action": "longPress", "key": "profile-avatar"}
```

Targeting supports `label` (display text), `key` (widget Key), or
positional labels (`"tap@120,340"`) for elements without visible text.

---

### Sentinel — HTTP Interception

Sentinel intercepts all HTTP traffic via `dart:io` `HttpOverrides` — like
Charles Proxy but built into the app. Works with any Dart HTTP client
(package:http, dio, Envoy, raw HttpClient) because all native HTTP flows
through `dart:io`.

#### Enable via ColossusPlugin

```dart
ColossusPlugin(
  enableSentinel: true,
  sentinelConfig: const SentinelConfig(
    excludePatterns: [r'localhost:864\d'], // Exclude Relay traffic
    maxBodyCapture: 64 * 1024,            // 64 KB body limit
    maxRecords: 500,                      // Ring buffer size
  ),
)
```

#### Enable manually

```dart
Colossus.init(
  enableSentinel: true,
  sentinelConfig: SentinelConfig(
    excludePatterns: [r'localhost:864\d'],
  ),
);
```

#### Browse captured records

```dart
final records = Colossus.instance.sentinelRecords;
for (final r in records) {
  print('${r.method} ${r.url} → ${r.statusCode} '
        '(${r.duration.inMilliseconds}ms, ${r.responseSize}B)');
}
```

#### SentinelRecord fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique request ID |
| `method` | `String` | HTTP method (GET, POST, etc.) |
| `url` | `Uri` | Full request URL |
| `timestamp` | `DateTime` | When the request started |
| `duration` | `Duration` | Total round-trip time |
| `statusCode` | `int?` | Response status (null if connection failed) |
| `requestHeaders` | `Map<String, List<String>>` | Request headers |
| `requestBody` | `List<int>?` | Request body bytes (capped) |
| `requestSize` | `int` | Actual request body size |
| `responseHeaders` | `Map<String, List<String>>?` | Response headers |
| `responseBody` | `List<int>?` | Response body bytes (capped) |
| `responseSize` | `int?` | Actual response body size |
| `success` | `bool` | Whether status is 2xx |
| `error` | `String?` | Error message on failure |

#### SentinelConfig options

| Option | Default | Description |
|--------|---------|-------------|
| `maxBodyCapture` | `65536` | Max bytes to capture per body |
| `excludePatterns` | `[]` | URL regex patterns to skip |
| `includePatterns` | `null` | If set, only matching URLs are captured |
| `captureRequestBody` | `true` | Capture request bodies |
| `captureResponseBody` | `true` | Capture response bodies |
| `captureHeaders` | `true` | Capture headers |
| `maxRecords` | `500` | Max records in memory (ring buffer) |

#### Relay endpoint

Sentinel records are available via the Relay HTTP bridge:

```bash
# Get all records
curl http://localhost:8642/sentinel/records

# Clear records
curl -X DELETE http://localhost:8642/sentinel/records
```

#### Standalone usage (without Colossus)

```dart
Sentinel.install(
  config: SentinelConfig(maxBodyCapture: 32 * 1024),
  onRecord: (record) {
    print('${record.method} ${record.url} → ${record.statusCode}');
  },
);

// Make HTTP calls — all traffic is captured
final response = await http.get(Uri.parse('https://api.example.com/data'));

// Clean up
Sentinel.uninstall();
```

#### Testing

In test environments where Flutter's test zone blocks network access:

```dart
Sentinel.install(
  onRecord: (r) => records.add(r),
  chainPreviousOverrides: false, // Skip Flutter test's MockHttpOverrides
);

// Use Sentinel.createClient() instead of HttpClient()
final client = Sentinel.createClient()!;
```

---

### DevToolsBridge — Flutter DevTools Integration

DevToolsBridge connects Colossus data to Flutter DevTools via three
`dart:developer` APIs:

1. **Service Extensions** — DevTools extension tabs can query live data
2. **Timeline Annotations** — Performance events in the DevTools timeline
3. **Event Streaming** — Real-time push via `postEvent`

#### Automatic setup

DevToolsBridge installs automatically when `Colossus.init()` is called
with `enableDevTools: true` (the default).

#### Service Extensions

| Extension | What it returns |
|-----------|----------------|
| `ext.colossus.getPerformance` | Full Decree (FPS, jank, page loads, memory) |
| `ext.colossus.getApiMetrics` | All tracked API call metrics |
| `ext.colossus.getSentinelRecords` | Sentinel HTTP records with full detail |
| `ext.colossus.getTerrain` | Scout's navigation graph |
| `ext.colossus.getMemorySnapshot` | Vessel memory state |
| `ext.colossus.getAlerts` | Tremor alert history |
| `ext.colossus.getFrameworkErrors` | Captured Flutter framework errors |
| `ext.colossus.getEvents` | Integration events (filterable by source) |

#### Timeline methods

```dart
DevToolsBridge.timelinePageLoad('/quest/42', Duration(milliseconds: 347));
DevToolsBridge.timelineTremor('fps_low', 'FPS dropped to 42', 'warning');
DevToolsBridge.timelineApiCall('GET', 'https://api.example.com/users', 200, 181);
```

#### Event streaming

```dart
DevToolsBridge.postTremorAlert('fps_low', 'frame', 'warning', 'FPS dropped to 42');
DevToolsBridge.postApiMetric({'method': 'GET', 'url': '...', 'durationMs': 181});
DevToolsBridge.postRouteChange('/login', '/quests', 'navigate');
DevToolsBridge.postFrameworkError('overflow', 'A RenderFlex overflowed by 42 pixels');
```

#### Structured logging

```dart
DevToolsBridge.log('Campaign completed: 12/15 passed');
```

---

### Scout — AI Test Discovery

Scout passively analyzes Shade sessions to build a **Terrain** — a live map of
every screen the user visited and every transition between them:

```dart
final scout = Scout.instance;

// Analyze a completed recording session
scout.analyzeSession(session);

// Access the discovered terrain
final terrain = scout.terrain;
print(terrain.outposts.length);  // Number of unique screens
print(terrain.marches.length);   // Number of transitions

// Export as Mermaid diagram or AI-ready map
final mermaid = terrain.toMermaid();
final aiMap = terrain.toAiMap();
```

Scout learns incrementally — each new session enriches the existing Terrain
with new routes, transitions, and reliability data.

### Terrain — Flow Graph

Terrain is a directed graph of **Outposts** (screens) connected by **Marches**
(transitions). It auto-detects dead-ends, low-reliability edges, and orphaned screens:

```dart
final terrain = scout.terrain;

// Find a specific screen
final quest = terrain.findOutpost('/quest/details');

// Check screen health
print(quest?.deadEnd);         // true if no outgoing transitions
print(quest?.visitCount);     // How many times the screen was visited
print(quest?.reliability);    // Transition success rate (0.0 → 1.0)
```

### Gauntlet — Edge-Case Test Generation

Gauntlet auto-generates **Stratagems** (test plans) targeting weak spots
discovered by Scout:

```dart
final gauntlet = Gauntlet(terrain: scout.terrain);

// Generate stratagems for a specific screen
final stratagems = gauntlet.forOutpost('/quest/details');

// Generate stratagems for the entire terrain
final all = gauntlet.forAll();

for (final s in all) {
  print('${s.name}: ${s.steps.length} steps');
}
```

### Campaign — Test Execution

Campaign orchestrates multi-step test runs with lifecycle management:

```dart
final campaign = Campaign(
  stratagems: gauntlet.forAll(),
  onSetup: () async => initTestEnvironment(),
  onTeardown: () async => cleanupTestEnvironment(),
);

final debrief = await campaign.execute();

print(debrief.passRate);           // e.g. 0.85
print(debrief.failedVerdicts);     // List of failed step results
print(debrief.fixSuggestions);     // AI-ready fix recommendations
```

### Lineage — Route Resolution

Lineage resolves parameterized routes back to their registered patterns:

```dart
final parameterizer = RouteParameterizer();
parameterizer.registerPattern('/quest/:id');
parameterizer.registerPattern('/hero/:heroId/quest/:questId');

final resolved = parameterizer.resolve('/quest/42');
print(resolved); // '/quest/:id'
```

### Zero-Code Integration

With `ColossusPlugin`, everything wires itself automatically:

1. **Shade → Scout**: Every completed recording is auto-fed to Scout
2. **Atlas → Scout**: Route patterns are pre-seeded from Atlas's trie
3. **Atlas Observer**: Page-load timing via `ColossusAtlasObserver`
4. **Shade.getCurrentRoute**: Auto-wired from Atlas for screen identification
5. **Terrain Notifier**: UI auto-refreshes when new sessions are analyzed

```dart
// That's it — one plugin, zero manual wiring
ColossusPlugin(
  tremors: [Tremor.fps(), Tremor.leaks()],
)
```

### Blueprint Lens Tab

The Blueprint tab adds a 5-sub-tab interactive interface to the Lens overlay:

- **Terrain** — Mermaid graph visualization, AI map export, conflict detection
- **Stratagem** — Browse auto-generated test plans with expandable detail cards
- **Verdict** — Step-by-step test results with pass/fail/skip rows
- **Lineage** — Route resolution metrics and Signet analysis
- **Campaign** — Campaign execution details with debrief summaries

### BlueprintExport — AI-Bridge Export

Export the complete Blueprint (Terrain + Stratagems + Verdicts) to disk
so AI assistants like Copilot and Claude can consume it at IDE time:

```dart
// Live export from the current Scout state
final export = BlueprintExport.fromScout(scout: Scout.instance);

// Save to .titan/ directory
await BlueprintExportIO.saveAll(export, directory: '.titan');
// → .titan/blueprint.json       (structured data)
// → .titan/blueprint-prompt.md  (AI-ready Markdown summary)
```

#### Auto-Export on App Shutdown

Set `blueprintExportDirectory` on `ColossusPlugin` and Blueprint data is
automatically exported when the app shuts down:

```dart
ColossusPlugin(
  blueprintExportDirectory: '.titan',
)
```

#### Offline Export from Saved Sessions

Use the CLI tool to build a Blueprint from previously saved Shade sessions:

```bash
# Basic export (run from your project root)
dart run titan_colossus:export_blueprint

# With options
dart run titan_colossus:export_blueprint \
  --sessions-dir .titan/sessions \
  --output-dir .titan \
  --patterns /quest/:id,/hero/:heroId \
  --intensity thorough

# AI prompt only
dart run titan_colossus:export_blueprint --prompt-only
```

#### Blueprint MCP Server

Expose Blueprint data to AI assistants via the Model Context Protocol:

```json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": ["run", "titan_colossus:blueprint_mcp_server"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

Available MCP tools:
- `get_terrain` — Full navigation graph (json, mermaid, or ai_map format)
- `get_stratagems` — Generated test plans (filterable by route)
- `get_ai_prompt` — AI-ready Markdown summary
- `get_dead_ends` — Screens with no outgoing transitions
- `get_unreliable_routes` — Transitions with low reliability scores
- `get_route_patterns` — Registered parameterized route patterns

## Ecosystem Integration

| System | Integration |
|--------|-------------|
| **Titan DI** | Self-registers via `Titan.put()` |
| **Herald** | Emits `ColossusTremor` events for alerts |
| **Chronicle** | Logs performance events and alerts |
| **Vigil** | Reports alert violations with severity |
| **Lens** | Auto-registered "Perf", "Shade", and "Blueprint" tabs |
| **Atlas** | Auto-wired observer, route pre-seeding, `getCurrentRoute` |
| **Shade** | Auto-feeds completed recordings into Scout |
| **Scout** | Builds Terrain from sessions, triggers `terrainNotifier` |
| **BlueprintExport** | Bridges runtime data to IDE-time AI assistants |
| **MCP Server** | Exposes Blueprint tools to Copilot/Claude |
| **Sentinel** | Captures all HTTP traffic via `HttpOverrides` interception |
| **DevToolsBridge** | Exposes Colossus data to Flutter DevTools via `dart:developer` |

## Architecture

```
┌─────────────────────────────────────────────┐
│                 Colossus                     │
│              (Pillar singleton)              │
├──────────┬──────────┬──────────┬────────────┤
│  Pulse   │  Stride  │  Vessel  │   Echo     │
│  (FPS)   │ (Loads)  │ (Memory) │ (Rebuilds) │
├──────────┴──────────┴──────────┴────────────┤
│  Sentinel (HTTP)  │  Shade (Record & Replay)│
├───────────────────┬─────────────────────────┤
│ Inscribe (Export) │ DevToolsBridge (DevTools)│
├───────────────────┴─────────────────────────┤
│            AI Blueprint Generation           │
│  Scout → Terrain → Gauntlet → Campaign       │
│  Lineage │ Stratagem │ Verdict │ Debrief     │
├─────────────────────────────────────────────┤
│              AI-Bridge Export                 │
│  BlueprintExport │ ExportIO │ MCP Server     │
│  CLI Tool │ Auto-Export │ AI Prompt          │
├──────────┬──────────┬──────────┬────────────┤
│  Herald  │Chronicle │  Vigil   │   Lens     │
│ (Events) │ (Logs)   │ (Errors) │  (UI Tab)  │
└──────────┴──────────┴──────────┴────────────┘
```

## License

MIT — see [LICENSE](LICENSE).
