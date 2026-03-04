# Chapter LIII — The Forge Accepts

*In which Kael discovers that the strongest fortifications are the ones you can mount and remove in a single motion — and that the workshop accepts any tool that fits the socket.*

---

The production deploy was in twelve hours.

Kael stared at the Questboard's `main.dart`, counting the layers of wrapping widgets like geological strata. `ShadeListener` around `Lens` around `Beacon` around `MaterialApp`. Each layer was essential for development — Colossus tracked frame jank, Shade recorded gesture macros, Lens projected the debug overlay — but none of it belonged in a customer-facing build.

"How do we strip Colossus for production?" Fen asked, echoing the question the entire team had been avoiding.

"Comment it out," someone suggested.

"That's three separate widgets you'd need to unwrap," Rhea pointed out. "And the `Colossus.init()` call in `main()`. And the export callback. And the route-wiring. Miss one and you get a runtime crash."

She was right. Kael pulled up the current code and traced the Colossus integration. It was spread across five separate locations in `main.dart`:

```dart
// 1. Initialize Colossus
Colossus.init(
  tremors: [Tremor.fps(), Tremor.jankRate(), Tremor.leaks()],
  enableLensTab: true,
  enableChronicle: true,
  shadeStoragePath: shadeDir,
  exportDirectory: exportDir,
);

// 2. Wire export callback
Colossus.instance.onExport = (paths) { ... };

// 3. Wire route tracking
Colossus.instance.shade.getCurrentRoute = () => Atlas.current.path;

// 4. Schedule auto-replay
WidgetsBinding.instance.addPostFrameCallback((_) {
  Colossus.instance.checkAutoReplay();
});

// 5. Widget tree wrapping (three layers)
ShadeListener(
  shade: Colossus.instance.shade,
  child: Lens(
    enabled: true,
    child: Beacon(
      pillars: [...],
      child: MaterialApp.router(...),
    ),
  ),
)
```

Five touchpoints. Three widget nestings. One nervous developer trying to remember which order they go in. It was the kind of integration tax that made teams leave monitoring tools disabled rather than deal with the ceremony.

"There has to be a better way," Kael muttered.

---

## The Socket and the Tool

The Elder had taught Kael about Pillars, about Cores, about Beacons that held them all together. But the Beacon was more than a provider — it was a **lifecycle manager**. It called `onAttach()` when it mounted, `onDetach()` when it disposed, and `build()` on every frame in between.

What if the Beacon could accept *tools*?

Not dependencies. Not state containers. Tools — modular capabilities that could hook into the Beacon's lifecycle without becoming permanent fixtures of the architecture.

Kael sketched the interface:

```dart
/// A plugin that hooks into Beacon's lifecycle.
abstract class TitanPlugin {
  const TitanPlugin();

  /// Called when the Beacon mounts (after Pillars are created).
  void onAttach() {}

  /// Wrap the widget tree with overlay widgets.
  Widget buildOverlay(BuildContext context, Widget child) => child;

  /// Called when the Beacon unmounts (after Pillars are disposed).
  void onDetach() {}
}
```

Three methods. All optional. A `const` constructor so plugins could be declared inline without allocation overhead. The `buildOverlay` returned the child unchanged by default — a no-op unless overridden.

"A plugin is a tool that fits into the Beacon's socket," Kael explained to the team. "It can initialize resources, wrap the tree, and clean up — all automatically."

---

## The Colossus Plugin

With the `TitanPlugin` interface in hand, the Colossus integration became a single class:

```dart
class ColossusPlugin extends TitanPlugin {
  final List<Tremor> tremors;
  final bool enableLens;
  final bool enableShade;
  final String? shadeStoragePath;
  final String? exportDirectory;
  final void Function(List<String>)? onExport;
  final String? Function()? getCurrentRoute;
  final bool autoReplayOnStartup;

  const ColossusPlugin({
    this.tremors = const [],
    this.enableLens = true,
    this.enableShade = true,
    this.shadeStoragePath,
    this.exportDirectory,
    this.onExport,
    this.getCurrentRoute,
    this.autoReplayOnStartup = false,
  });

  @override
  void onAttach() {
    Colossus.init(
      tremors: tremors,
      shadeStoragePath: shadeStoragePath,
      exportDirectory: exportDirectory,
    );
    if (onExport != null) Colossus.instance.onExport = onExport;
    if (getCurrentRoute != null) {
      Colossus.instance.shade.getCurrentRoute = getCurrentRoute;
    }
  }

  @override
  Widget buildOverlay(BuildContext context, Widget child) {
    Widget result = child;
    if (enableLens) result = Lens(enabled: true, child: result);
    if (enableShade && Colossus.isActive) {
      result = ShadeListener(shade: Colossus.instance.shade, child: result);
    }
    return result;
  }

  @override
  void onDetach() => Colossus.shutdown();
}
```

Five integration points collapsed into one declaration. Three widget wrappers managed internally. Initialization, wiring, and cleanup handled by the Beacon lifecycle.

---

## One Line to Rule Them All

The `main.dart` transformed from a sprawl of setup code into a clean declaration:

```dart
runApp(
  Beacon(
    pillars: [QuestboardPillar.new, QuestListPillar.new],
    plugins: [
      ColossusPlugin(
        tremors: [Tremor.fps(), Tremor.jankRate(), Tremor.leaks()],
        enableLensTab: true,
        enableChronicle: true,
        shadeStoragePath: shadeDir,
        exportDirectory: exportDir,
        onExport: (paths) => SharePlus.instance.share(
          ShareParams(files: paths.map((p) => XFile(p)).toList()),
        ),
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
```

"And for production?" Fen asked.

Kael smiled and deleted the `ColossusPlugin(...)` block:

```dart
runApp(
  Beacon(
    pillars: [QuestboardPillar.new, QuestListPillar.new],
    plugins: [],  // or just remove the parameter entirely
    child: MaterialApp.router(routerConfig: atlas.config),
  ),
);
```

No widget tree restructuring. No forgotten cleanup calls. No `Colossus.instance` dangling in production. One line removed, and the entire monitoring stack vanished cleanly.

"Better yet," Kael added, "use a compile-time flag:"

```dart
plugins: [
  if (kDebugMode) ColossusPlugin(),
],
```

Colossus would never even be instantiated in release builds. Tree-shaking would remove the dead code path entirely.

---

## The Beacon Accepts

Kael opened `Beacon` and traced how plugins integrated with the existing lifecycle:

```
Beacon initState:
  1. Create Pillars         (existing)
  2. Initialize Pillars     (existing)
  3. Call plugin.onAttach()  ← NEW (for each plugin, in order)

Beacon build:
  1. _BeaconInherited(...)   (existing)
  2. Apply plugin.buildOverlay(context, child)  ← NEW (in order)

Beacon dispose:
  1. Dispose Pillars         (existing)
  2. Call plugin.onDetach()   ← NEW (reverse order)
```

The beauty was in the ordering. Plugins attached *after* Pillars existed, so they could reference Titan state. Overlays wrapped *inside* the `_BeaconInherited`, so they had access to the Beacon's Pillars. Detachment ran in reverse — last plugin attached was first to detach — ensuring clean teardown.

"What if we have multiple plugins?" Rhea asked.

"They compose," Kael answered. "Each `buildOverlay` wraps the result of the previous one. First plugin is innermost, last plugin is outermost."

```dart
Beacon(
  plugins: [analyticsPlugin, colossusPlugin],
  // Build order: child → analytics overlay → colossus overlay
  // Detach order: colossus.onDetach() → analytics.onDetach()
)
```

---

## Writing Your Own

Rhea immediately saw the pattern's potential. She had an analytics SDK that required similar wrapping ceremony:

```dart
class AnalyticsPlugin extends TitanPlugin {
  final String apiKey;
  const AnalyticsPlugin({required this.apiKey});

  @override
  void onAttach() {
    Analytics.init(apiKey: apiKey);
  }

  @override
  void onDetach() {
    Analytics.flush();
    Analytics.shutdown();
  }
}
```

No `buildOverlay` override needed — analytics didn't add visible widgets. The Beacon called `onAttach()` at mount and `onDetach()` at unmount, and the analytics SDK's lifecycle was managed automatically.

"The `TitanPlugin` interface is the socket," Kael said. "Any tool that fits the interface can plug into the Beacon. One line to add, one line to remove."

---

## The Enterprise Pattern

By afternoon, the team had established a production convention:

```dart
// lib/plugins.dart — centralize plugin configuration
List<TitanPlugin> appPlugins({required bool isDev}) => [
  if (isDev) ColossusPlugin(
    tremors: [Tremor.fps(), Tremor.leaks()],
    enableLens: true,
  ),
  // Add more plugins here as needed
];

// main.dart — clean, unchanging structure
runApp(
  Beacon(
    pillars: appPillars,
    plugins: appPlugins(isDev: kDebugMode),
    child: MaterialApp.router(routerConfig: atlas.config),
  ),
);
```

The `main.dart` never changed between environments. The plugin list was the single source of truth for what capabilities were active. Adding a new monitoring tool meant adding one line to `appPlugins`. Removing one meant deleting that line.

"Enterprise architecture," Rhea said, leaning back. "Not because it's complicated. Because it's *modular*."

---

*The strongest fortress is not the one with the thickest walls — it's the one where every defense can be mounted or removed without disturbing the foundation. The Forge does not reject tools; it accepts anything that fits the socket.*

---

### Lexicon Entry

| Standard Term | Titan Name | Purpose |
|---|---|---|
| Plugin | **TitanPlugin** | Abstract base class for Beacon plugin architecture |
| Colossus Plugin | **ColossusPlugin** | One-line Colossus integration via TitanPlugin |

### Key APIs

| API | Description |
|---|---|
| `TitanPlugin.onAttach()` | Called during Beacon `initState`, after Pillars are created |
| `TitanPlugin.buildOverlay()` | Wraps the widget tree inside the Beacon's inherited scope |
| `TitanPlugin.onDetach()` | Called during Beacon `dispose`, in reverse order |
| `Beacon(plugins: [...])` | Pass plugins to Beacon for automatic lifecycle management |
| `ColossusPlugin(...)` | All Colossus configuration in a single const constructor |

---

| [← Chapter LII: The Cartographer's Table](chapter-52-the-cartographers-table.md) |
