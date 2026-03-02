# Chapter XXI: The Spark Ignites

*In which Kael discovers that the ceremony of state is the enemy of velocity, and learns to ignite widgets with nothing but intention.*

---

The quest board was growing. Every screen needed state — a text controller here, an animation there, a reactive counter somewhere else. Each time, Kael reached for `StatefulWidget` and felt the weight of ceremony descend.

```dart
class HeroProfileEditor extends StatefulWidget {
  @override
  State<HeroProfileEditor> createState() => _HeroProfileEditorState();
}

class _HeroProfileEditorState extends State<HeroProfileEditor>
    with SingleTickerProviderStateMixin {
  late final _nameController = TextEditingController();
  late final _bioController = TextEditingController();
  late final _focusNode = FocusNode();
  late final _animController = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 300),
  );
  int _editCount = 0;
  bool _isDirty = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(controller: _nameController, focusNode: _focusNode),
      TextField(controller: _bioController),
      Text('Edits: $_editCount'),
      FadeTransition(
        opacity: _animController,
        child: Text('Unsaved changes'),
      ),
    ]);
  }
}
```

Forty-two lines. Two classes. A `dispose` method that was nothing but a graveyard of `.dispose()` calls. And the actual *logic* — the part that mattered — was buried under scaffolding.

"Every widget that needs a controller costs me twenty lines of ceremony," Kael muttered, counting the `dispose` calls for the third time that week.

He needed a **Spark**.

---

## The Spark — Hooks-Style Widgets

Spark is a widget that replaces `StatefulWidget` with a single class and **hooks** — small functions that auto-manage their own lifecycle. No `createState`. No `dispose`. No ceremony.

```dart
class HeroProfileEditor extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final nameCtrl = useTextController();
    final bioCtrl = useTextController();
    final focus = useFocusNode();
    final anim = useAnimationController(
      duration: Duration(milliseconds: 300),
    );
    final editCount = useCore(0);
    final isDirty = useCore(false);

    return Column(children: [
      TextField(controller: nameCtrl, focusNode: focus),
      TextField(controller: bioCtrl),
      Text('Edits: ${editCount.value}'),
      FadeTransition(
        opacity: anim,
        child: Text('Unsaved changes'),
      ),
    ]);
  }
}
```

Fifteen lines. One class. Zero `dispose` calls. Every controller, focus node, and animation controller is created, tracked, and disposed automatically.

"Where does `dispose` go?" the junior developer asked.

"Nowhere. That's the point." Kael pointed at `useTextController()`. "The hook creates the controller on the first build and disposes it when the widget leaves the tree. You never touch the lifecycle."

### How It Works

Spark uses **position-based hooks** — each `use*` call is identified by its position in `ignite()`. The first build creates each hook's state. Subsequent rebuilds retrieve the same state at the same position.

The rules are simple:
1. **Always call hooks in the same order** — no hooks inside `if`, `for`, or `try`.
2. **Only call hooks inside `ignite()`** — not in callbacks or async functions.

---

## Reactive State — useCore & useDerived

The real power comes from combining hooks with Titan's reactive engine.

### useCore — Reactive Mutable State

```dart
class QuestCounter extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);
    final label = useCore('Quests');

    return Column(children: [
      Text('${label.value}: ${count.value}'),
      ElevatedButton(
        onPressed: () => count.value++,
        child: Text('Add Quest'),
      ),
    ]);
  }
}
```

`useCore` creates a `Core<T>` — the same reactive primitive used in Pillars. When its value changes, the Spark rebuilds. When the Spark unmounts, the Core is disposed.

### useDerived — Computed Values

```dart
class QuestSummary extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final completed = useCore(7);
    final total = useCore(12);
    final progress = useDerived(
      () => '${completed.value}/${total.value} complete',
    );

    return Text(progress.value);
  }
}
```

`useDerived` creates a `Derived<T>` that auto-tracks its dependencies. When `completed` or `total` changes, the derived value recomputes and the widget rebuilds.

---

## Lifecycle Hooks

### useEffect — Side Effects with Cleanup

```dart
class LiveQuestFeed extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final quests = useCore<List<String>>([]);

    useEffect(() {
      final subscription = questStream.listen(
        (quest) => quests.value = [...quests.value, quest],
      );
      return subscription.cancel; // Cleanup on dispose
    }, []); // Empty keys = run once

    return ListView(
      children: quests.value.map((q) => Text(q)).toList(),
    );
  }
}
```

The keys parameter controls when the effect re-runs:
- `[]` — run once (like `initState`)
- `null` — run every build
- `[dep1, dep2]` — re-run when any dependency changes

### useMemo — Memoized Computation

```dart
class SortedQuestList extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final quests = useCore<List<String>>(['Dragon', 'Goblin', 'Alchemy']);
    final sorted = useMemo(
      () => List<String>.from(quests.value)..sort(),
      [quests.value.length],
    );

    return Column(
      children: sorted.map((q) => Text(q)).toList(),
    );
  }
}
```

### useRef — Mutable Reference (No Rebuild)

```dart
class ClickTracker extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final clickCount = useRef(0);

    return ElevatedButton(
      onPressed: () {
        clickCount.value++;
        print('Clicked ${clickCount.value} times');
      },
      child: Text('Track clicks'),
    );
  }
}
```

`useRef` holds a mutable value that persists across rebuilds but never triggers one.

---

## Controller Hooks

Every Flutter controller has a matching hook that auto-disposes:

| Hook | Creates | Auto-Disposes |
|------|---------|---------------|
| `useTextController()` | `TextEditingController` | ✅ |
| `useAnimationController()` | `AnimationController` | ✅ |
| `useFocusNode()` | `FocusNode` | ✅ |
| `useScrollController()` | `ScrollController` | ✅ |
| `useTabController()` | `TabController` | ✅ |
| `usePageController()` | `PageController` | ✅ |

Animation and tab controllers get their `TickerProvider` automatically from Spark — no `SingleTickerProviderStateMixin` needed.

```dart
class AnimatedQuestCard extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final anim = useAnimationController(
      duration: Duration(milliseconds: 500),
    );

    useEffect(() {
      anim.forward();
      return null;
    }, []);

    return FadeTransition(
      opacity: anim,
      child: Card(child: Text('New Quest!')),
    );
  }
}
```

---

## Pillar Integration — usePillar

Spark works seamlessly with existing Pillars and Beacons:

```dart
class HeroCard extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final hero = usePillar<HeroPillar>(context);
    final fadeIn = useAnimationController(
      duration: Duration(milliseconds: 300),
    );

    useEffect(() {
      fadeIn.forward();
      return null;
    }, []);

    return FadeTransition(
      opacity: fadeIn,
      child: Column(children: [
        Text('Name: ${hero.name.value}'),
        Text('Level: ${hero.level.value}'),
        ElevatedButton(
          onPressed: hero.levelUp,
          child: Text('Level Up'),
        ),
      ]),
    );
  }
}
```

`usePillar` finds the Pillar from the nearest `Beacon` ancestor, falling back to `Titan` global DI. It's the hooks equivalent of `Vestige` — same lookup, zero boilerplate.

---

### The Stream Within

"There's one more thing," Kael said, pulling up the quest activity feed. "Real-time data. WebSocket streams, SSE feeds — things that arrive *over time*."

The junior groaned. "StreamBuilder? That thing is half my error handling code."

"Not anymore." Kael typed a new Spark:

```dart
class QuestActivityFeed extends Spark {
  final Stream<List<QuestEvent>> eventStream;
  const QuestActivityFeed({super.key, required this.eventStream});

  @override
  Widget ignite(BuildContext context) {
    final events = useStream(eventStream, initialData: const []);

    return events.when(
      onData: (data) => ListView.builder(
        itemCount: data.length,
        itemBuilder: (_, i) => ListTile(
          leading: Icon(data[i].icon),
          title: Text(data[i].title),
          subtitle: Text(data[i].timestamp.toString()),
        ),
      ),
      onLoading: () => const Center(child: CircularProgressIndicator()),
      onError: (e, _) => Center(child: Text('Feed error: $e')),
    );
  }
}
```

`useStream` subscribes to the stream, auto-cancels on dispose, and returns an **Ether** (`AsyncValue<T>`) — the same tri-state pattern used throughout Titan. It starts as `AsyncLoading`, transitions to `AsyncData` on each emission, and captures errors as `AsyncError`.

"What if the stream source changes?" the junior asked.

"Add keys," Kael said. "Like every other hook."

```dart
final selectedChannel = useCore('general');
final messages = useStream(
  chatService.messagesFor(selectedChannel.value),
  keys: [selectedChannel.value],
);
```

When `selectedChannel` changes, `useStream` cancels the old subscription and subscribes to the new stream automatically.

---

### Spark vs StatefulWidget

| Aspect | StatefulWidget | Spark |
|--------|---------------|-------|
| Classes needed | 2 (Widget + State) | 1 |
| Manual dispose | Required for every controller | Automatic |
| TickerProvider | Mixin ceremony | Built-in |
| Reactive state | `setState(() {})` | `useCore` (auto-tracking) |
| Computed values | Manual caching | `useDerived` (auto-tracked) |
| Side effects | `initState` + `dispose` | `useEffect` with cleanup |
| Lines of code | 30-50+ | 10-20 |

---

Kael leaned back and looked at the quest board. Five screens rewritten. Two hundred lines of `dispose` calls deleted. Every `StatefulWidget` replaced with a `Spark` — same behavior, half the code, zero lifecycle bugs.

"The hooks just... work?" the PM asked, scrolling through the diff.

"They work because they're honest about what state is," Kael said. "A text controller isn't special — it's state that needs cleanup. An animation controller isn't special — it's state that needs a ticker. Once you accept that, the ceremony disappears."

The junior developer was already converting her latest screen. `extends StatefulWidget` became `extends Spark`. `createState` vanished. The `dispose` graveyard vanished. What remained was pure intention — the controllers she needed, the effects she wanted, the values she tracked.

"It's like the widget is just telling you what it *wants*," she said, "and the framework handles the rest."

Kael smiled. That was exactly the point.

---

*The Spark teaches a simple truth: a widget should declare what it needs, not how to manage it. When lifecycle becomes invisible, intention becomes clear. When ceremony disappears, what remains is the code that matters.*

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
| [IX](chapter-09-the-scroll-inscribes.md) | The Scroll Inscribes |
| [X](chapter-10-the-codex-opens.md) | The Codex Opens |
| [XI](chapter-11-the-quarry-yields.md) | The Quarry Yields |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
| [XVIII](chapter-18-the-conduit-flows.md) | The Conduit Flows |
| [XIX](chapter-19-the-prism-reveals.md) | The Prism Reveals |
| [XX](chapter-20-the-nexus-connects.md) | The Nexus Connects |
| **XXI** | **The Spark Ignites** ← You are here |
