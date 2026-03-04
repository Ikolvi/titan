# Colossus — Enterprise Performance Monitoring

**Package:** `titan_colossus` · **Named for:** The Colossus of Rhodes, a giant who stood watch over the harbor

Titan's enterprise performance monitoring package provides frame tracking, page load timing, memory monitoring, rebuild counting, threshold alerts, aggregated reports, export, and gesture recording/replay.

## The Colossus Lexicon

| Standard Term | Titan Name | Class |
|---------------|------------|-------|
| Performance Monitor | **Colossus** | `Colossus` |
| Frame Metrics | **Pulse** | `Pulse` |
| Page Load Timing | **Stride** | `Stride` |
| Memory Monitor | **Vessel** | `Vessel` |
| Rebuild Counter | **Echo** | `Echo` |
| Performance Alert | **Tremor** | `Tremor` |
| Performance Report | **Decree** | `Decree` |
| Report Export | **Inscribe** | `Inscribe` |
| Metric Data Point | **Mark** | `Mark` |
| Gesture Recorder | **Shade** | `Shade` |
| Recorded Event | **Imprint** | `Imprint` |
| Replay Engine | **Phantom** | `Phantom` |
| Capture Widget | **ShadeListener** | `ShadeListener` |
| Session Store | **ShadeVault** | `ShadeVault` |
| Text Controller | **ShadeTextController** | `ShadeTextController` |
| Plugin Adapter | **ColossusPlugin** | `ColossusPlugin` |

## Installation

```yaml
dependencies:
  titan_colossus: ^1.1.0
```

```dart
import 'package:titan_colossus/titan_colossus.dart';
```

---

## Quick Start

### Plugin Integration (Recommended)

The simplest way to add Colossus — one line to add, one line to remove:

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  runApp(
    Beacon(
      pillars: [MyPillar.new],
      plugins: [
        if (kDebugMode) ColossusPlugin(
          tremors: [Tremor.fps(), Tremor.leaks()],
          enableLens: true,
          enableShade: true,
          getCurrentRoute: () => Atlas.current.path,
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

`ColossusPlugin` handles everything: `Colossus.init()`, `Lens` overlay, `ShadeListener` wrapping, export/route callbacks, and `Colossus.shutdown()` on dispose. Remove the plugin line for production builds — no widget tree restructuring needed.

### Manual Integration

For more control over initialization order:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Colossus (registers as a Pillar via Titan.put)
  final colossus = Colossus.init(
    enablePulse: true,    // frame metrics
    enableStride: true,   // page load timing
    enableVessel: true,   // memory monitoring
    vesselInterval: const Duration(seconds: 30),
    tremors: [
      Tremor(
        name: 'Slow Frame',
        severity: TremorSeverity.warning,
        condition: (marks) => marks.whereType<FrameMark>()
            .any((m) => m.buildDuration.inMilliseconds > 16),
      ),
    ],
  );

  runApp(
    ShadeListener(
      shade: colossus.shade,
      child: MaterialApp.router(
        routerConfig: Atlas(
          observers: [ColossusAtlasObserver()],
          // ...
        ),
      ),
    ),
  );
}
```

---

## Colossus — The Orchestrator

`Colossus` is a `Pillar` singleton that manages all monitors:

```dart
// Initialize
final colossus = Colossus.init(
  enablePulse: true,
  enableStride: true,
  enableVessel: true,
);

// Access the singleton
final instance = Colossus.instance;

// Check status
if (Colossus.isActive) {
  // ...
}

// Generate a report
final decree = colossus.generateDecree();

// Shutdown
colossus.shutdown();
```

### Zero Overhead When Inactive

All monitors check `Colossus.isActive` before collecting data. When Colossus isn't initialized, overhead is zero.

---

## Monitors

### Pulse — Frame Metrics

Tracks frame build and raster durations using `SchedulerBinding.addTimingsCallback`:

```dart
Colossus.init(enablePulse: true);

// Access frame history
final frames = colossus.pulse.frames;  // List<FrameMark>
final avgBuild = colossus.pulse.averageBuildTime;
final avgRaster = colossus.pulse.averageRasterTime;
final jankyFrames = colossus.pulse.jankyFrameCount;
```

**FrameMark** fields:

| Field | Type | Description |
|-------|------|-------------|
| `buildDuration` | `Duration` | Time spent building the frame |
| `rasterDuration` | `Duration` | Time spent rasterizing |
| `timestamp` | `DateTime` | When the frame was recorded |

### Stride — Page Load Timing

Measures page load durations using post-frame callbacks:

```dart
Colossus.init(enableStride: true);

// With Atlas observer (automatic):
Atlas(observers: [ColossusAtlasObserver()]);

// Manual recording:
colossus.stride.startTiming('profile-page');
// ... page loads ...
colossus.stride.stopTiming('profile-page');

// Access history
final loads = colossus.stride.pageLoads;  // List<PageLoadMark>
```

**PageLoadMark** fields:

| Field | Type | Description |
|-------|------|-------------|
| `pageName` | `String` | Route or page identifier |
| `duration` | `Duration` | Total load time |
| `timestamp` | `DateTime` | When the load was recorded |

### Vessel — Memory Monitoring

Periodically checks memory usage via `Timer.periodic`:

```dart
Colossus.init(
  enableVessel: true,
  vesselInterval: const Duration(seconds: 30),
);

final snapshots = colossus.vessel.snapshots;  // List<MemoryMark>
final suspects = colossus.vessel.leakSuspects; // List<LeakSuspect>
```

**MemoryMark** fields:

| Field | Type | Description |
|-------|------|-------------|
| `rss` | `int` | Resident set size in bytes |
| `timestamp` | `DateTime` | When the snapshot was taken |

### Echo — Rebuild Counter

A `StatelessWidget` wrapper that counts rebuilds with zero allocation overhead:

```dart
Echo(
  name: 'profile-card',
  child: ProfileCard(),
)
```

When `Colossus.isActive`, each rebuild increments a counter. Access via `colossus.echo.rebuilds`.

---

## Tremor — Performance Alerts

Configure threshold-based alerts that fire when conditions are met:

```dart
Colossus.init(
  tremors: [
    Tremor(
      name: 'Slow Frame',
      severity: TremorSeverity.warning,
      condition: (marks) => marks.whereType<FrameMark>()
          .any((m) => m.buildDuration.inMilliseconds > 16),
    ),
    Tremor(
      name: 'Memory Spike',
      severity: TremorSeverity.critical,
      condition: (marks) => marks.whereType<MemoryMark>()
          .any((m) => m.rss > 500 * 1024 * 1024), // 500 MB
    ),
  ],
);
```

Tremors are emitted via `Herald` as `ColossusTremor` events, integrating with the standard Titan event bus:

```dart
herald.on<ColossusTremor>((tremor) {
  print('Alert: ${tremor.name} [${tremor.severity}]');
});
```

**TremorSeverity** levels: `info`, `warning`, `critical`.

---

## Decree — Performance Reports

Generate aggregated performance reports:

```dart
final decree = colossus.generateDecree();

print(decree.health);          // PerformanceHealth.good / .warning / .critical
print(decree.avgBuildTime);    // Duration
print(decree.avgRasterTime);   // Duration
print(decree.totalRebuilds);   // int
print(decree.jankyFrameRatio); // double (0.0 – 1.0)
print(decree.pageLoads);       // List<PageLoadMark>
print(decree.memorySnapshots); // List<MemoryMark>
print(decree.leakSuspects);    // List<LeakSuspect>
print(decree.activeTremors);   // List<Tremor>
```

**PerformanceHealth** verdicts: `good`, `warning`, `critical`.

---

## Inscribe — Report Export

Export Decree reports in multiple formats:

```dart
final decree = colossus.generateDecree();

// Markdown
final md = Inscribe.toMarkdown(decree);

// JSON
final json = Inscribe.toJson(decree);

// HTML
final html = Inscribe.toHtml(decree);

// Save to disk (dart:io)
final result = await InscribeIO.save(decree, format: 'md', directory: '/tmp');
print(result.path); // SaveResult with file path
```

---

## Integration

### ColossusPlugin — One-Line Integration

`ColossusPlugin` is a `TitanPlugin` that wraps all Colossus setup into a single Beacon plugin:

```dart
Beacon(
  pillars: [MyPillar.new],
  plugins: [
    if (kDebugMode) ColossusPlugin(
      tremors: [Tremor.fps(), Tremor.leaks()],
      enableLens: true,           // wraps with Lens overlay
      enableShade: true,          // wraps with ShadeListener
      enableLensTab: true,        // registers Perf + Shade tabs
      enableChronicle: true,      // logs to Chronicle
      shadeStoragePath: '/path',  // session persistence
      exportDirectory: '/export', // report export directory
      onExport: (paths) => Share.shareFiles(paths),
      getCurrentRoute: () => Atlas.current.path,
      autoReplayOnStartup: true,
    ),
  ],
  child: MaterialApp(...),
)
```

| Lifecycle | What Happens |
|-----------|-------------|
| `onAttach()` | Calls `Colossus.init()`, wires export/route callbacks, schedules auto-replay |
| `buildOverlay()` | Wraps child with `Lens` and `ShadeListener` (if enabled) |
| `onDetach()` | Calls `Colossus.shutdown()` |

To remove Colossus entirely: delete the `ColossusPlugin(...)` line and remove the `titan_colossus` import.

### Lens Debug Overlay

Lens (debug overlay) is part of `titan_colossus`. Add performance tabs to the Lens debug overlay:

```dart
import 'package:titan_colossus/titan_colossus.dart';

Lens(
  plugins: [ColossusLensTab()],
  child: MaterialApp(...),
)
```

### Atlas Route Timing

Automatically time page loads during navigation:

```dart
Atlas(
  observers: [ColossusAtlasObserver()],
  // ...
)
```

---

## Shade — Gesture Recording & Replay

Shade records user interactions (pointer events, keyboard input, text entry) for replay and debugging.

### Recording

```dart
final shade = colossus.shade;

// Start recording
shade.startRecording();

// ... user interacts with the app ...

// Stop recording
final session = shade.stopRecording(); // ShadeSession
```

### ShadeListener

Wrap your app to capture all pointer events:

```dart
ShadeListener(
  shade: colossus.shade,
  child: MaterialApp(...),
)
```

### ShadeTextController

Auto-recording `TextEditingController` for text input capture:

```dart
final controller = ShadeTextController(
  shade: shade,
  fieldId: 'hero_name',
);

TextField(controller: controller)
```

During replay, Phantom can inject text directly via the controller registry — no keyboard simulation needed.

### Phantom — Replay Engine

Replay recorded sessions programmatically:

```dart
final phantom = Phantom(shade: shade, suppressKeyboard: true);
final result = await phantom.replay(session);

print(result.totalEvents);    // int
print(result.actualDuration); // Duration
print(result.wasCancelled);   // bool
```

### Route Safety

Ensure replay starts on the correct route:

```dart
shade.getCurrentRoute = () => Atlas.current.path;

// Route is captured automatically on startRecording()
print(session.startRoute); // '/quest/42'

// Enforce matching route on replay
await Colossus.instance.replaySession(
  session,
  requireMatchingRoute: true, // throws if current route ≠ startRoute
);
```

### ShadeVault — Session Persistence

Persist recording sessions to disk:

```dart
final vault = ShadeVault(directory: '/path/to/sessions');

// Save a session
await vault.save(session);

// List saved sessions
final summaries = await vault.listSessions(); // List<ShadeSessionSummary>

// Load a session
final loaded = await vault.load(summaries.first.id);

// Configure auto-replay
await vault.setAutoReplayConfig(
  ShadeAutoReplayConfig(
    enabled: true,
    sessionId: session.id,
    speed: 2.0,
  ),
);
```

### Shade Lens Tab

Add a recording/replay UI to the Lens debug overlay:

```dart
Lens(
  plugins: [ColossusLensTab(), ShadeLensTab(shade: colossus.shade)],
  child: MaterialApp(...),
)
```

The Shade Lens tab provides:
- Start/stop recording controls
- Session library browser
- One-tap replay with speed control
- Route mismatch warnings

---

## Imprint — Recorded Events

Each recorded event is an `Imprint`:

| Field | Type | Description |
|-------|------|-------------|
| `type` | `ImprintType` | `pointer`, `keyboard`, `text`, `textAction` |
| `timestamp` | `DateTime` | When the event occurred |
| `data` | `Map<String, dynamic>` | Event-specific payload |

**ImprintType** values: `pointer`, `keyboard`, `text`, `textAction`.

---

## PhantomResult

Replay outcome data:

| Field | Type | Description |
|-------|------|-------------|
| `totalEvents` | `int` | Dispatched + skipped events |
| `actualDuration` | `Duration` | Wall-clock replay time |
| `wasNormalized` | `bool` | Whether positions were normalized |
| `wasCancelled` | `bool` | Whether replay was cancelled |
| `speedRatio` | `double` | Actual / expected duration ratio |

---

## Complete Example

### With ColossusPlugin (Recommended)

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final atlas = Atlas(
    observers: [HeraldAtlasObserver(), ColossusAtlasObserver()],
    passages: [
      Passage('/', (_) => const HomeScreen()),
      Passage('/profile', (_) => const ProfileScreen()),
    ],
  );

  runApp(
    Beacon(
      pillars: [HomePillar.new, ProfilePillar.new],
      plugins: [
        if (kDebugMode) ColossusPlugin(
          tremors: [Tremor.fps(), Tremor.jankRate(), Tremor.leaks()],
          enableLens: true,
          enableShade: true,
          enableChronicle: true,
          shadeStoragePath: '/tmp/shade_sessions',
          exportDirectory: '/tmp/reports',
          onExport: (paths) => Share.shareFiles(paths),
          getCurrentRoute: () {
            try { return Atlas.current.path; }
            catch (_) { return null; }
          },
          autoReplayOnStartup: true,
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

### Manual Integration

```dart
import 'package:titan_colossus/titan_colossus.dart';
import 'package:titan_argus/titan_argus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final colossus = Colossus.init(
    enablePulse: true,
    enableStride: true,
    enableVessel: true,
    tremors: [
      Tremor(
        name: 'Janky Frame',
        severity: TremorSeverity.warning,
        condition: (marks) => marks.whereType<FrameMark>()
            .any((m) => m.buildDuration.inMilliseconds > 16),
      ),
    ],
  );

  // Wire route tracking for Shade
  colossus.shade.getCurrentRoute = () => Atlas.current.path;

  runApp(
    ShadeListener(
      shade: colossus.shade,
      child: Lens(
        plugins: [
          ColossusLensTab(),
          ShadeLensTab(shade: colossus.shade),
        ],
        child: MaterialApp.router(
          routerConfig: Atlas(
            observers: [ColossusAtlasObserver()],
            passages: [
              Passage('/', (_) => const HomeScreen()),
              Passage('/profile', (_) => const ProfileScreen()),
            ],
          ),
        ),
      ),
    ),
  );
}
```

---

## Testing

```bash
cd packages/titan_colossus && flutter test  # 303+ tests
```

---

[← Argus Auth](13-argus-auth.md) · [Migration Guide →](10-migration-guide.md)
