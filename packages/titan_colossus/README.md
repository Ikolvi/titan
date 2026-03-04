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
| Lens Tabs | **Lens Tab** | Auto-registered "Perf" and "Shade" tabs in Lens |
| Route Integration | **Atlas Observer** | Automatic page load timing via Atlas |

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
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

One line to add, one line to remove. ColossusPlugin handles `Colossus.init()`, wraps with `Lens` and `ShadeListener`, and calls `Colossus.shutdown()` on dispose.

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

## Ecosystem Integration

| System | Integration |
|--------|-------------|
| **Titan DI** | Self-registers via `Titan.put()` |
| **Herald** | Emits `ColossusTremor` events for alerts |
| **Chronicle** | Logs performance events and alerts |
| **Vigil** | Reports alert violations with severity |
| **Lens** | Auto-registered "Perf" debug tab |
| **Atlas** | `ColossusAtlasObserver` for route timing |

## Architecture

```
┌─────────────────────────────────────────────┐
│                 Colossus                     │
│              (Pillar singleton)              │
├──────────┬──────────┬──────────┬────────────┤
│  Pulse   │  Stride  │  Vessel  │   Echo     │
│  (FPS)   │ (Loads)  │ (Memory) │ (Rebuilds) │
├──────────┴──────────┴──────────┴────────────┤
│        Shade         │       Inscribe       │
│  (Record & Replay)   │  (Export Reports)    │
├──────────────────────┴──────────────────────┤
│              Tremor Engine                   │
│        (Threshold evaluation loop)           │
├──────────┬──────────┬──────────┬────────────┤
│  Herald  │Chronicle │  Vigil   │   Lens     │
│ (Events) │ (Logs)   │ (Errors) │  (UI Tab)  │
└──────────┴──────────┴──────────┴────────────┘
```

## License

MIT — see [LICENSE](LICENSE).
