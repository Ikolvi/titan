# Chapter LII — The Cartographer's Table

*In which new heroes join the guild, and Kael learns that the greatest map is not the one that shows everything — but the one that shows where to start.*

---

The hiring spree hit Ironclad Labs like a siege.

Three developers arrived on Monday. Two more on Wednesday. By Friday, Kael's quiet corner of the codebase had become a bazaar of questions, misread variable names, and pull requests that betrayed a fundamental truth: nobody knew what a "Pillar" was.

"Is this a column?" Fen asked, staring at the `QuestboardPillar` class. "Like, a UI column?"

"It's closer to a BLoC," Kael started, but the blank look told him that didn't help either.

Rhea, the backend developer, was more direct. "I've been writing Dart for three years. I know Streams, I know Provider, I know BLoC. I've never seen a 'Core' or a 'Derived' or a 'Strike.' Why does everything have a fantasy name?"

It was a fair question. Kael had asked the same thing, once, before the names had settled into his muscle memory like a second language. He remembered the Elder's answer — but the Elder wasn't here. He was on his own.

He opened a blank document and started writing.

---

## The Rosetta Stone

"Think of it as translation," Kael told the room. "You already know these concepts. You just know them by different names."

He projected the table:

| What It Does | BLoC | Provider | Riverpod | GetX | **Titan** |
|---|---|---|---|---|---|
| Holds state & logic | `Bloc` / `Cubit` | `ChangeNotifier` | `Notifier` | `GetxController` | **Pillar** |
| A reactive value | State class | Field + `notifyListeners()` | `state` | `.obs` | **Core** |
| Computed value | — (manual) | — | `Provider` | `Obx(() => ...)` | **Derived** |
| Dispatch action | `add(event)` / `emit()` | Method call | Method call | Method call | **strike()** |
| React to changes | `BlocListener` | listen | `ref.listen` | `ever()` | **watch()** |
| Provide to tree | `BlocProvider` | `ChangeNotifierProvider` | `ProviderScope` | `Get.put()` | **Beacon** |
| Consume in widget | `BlocBuilder` | `Consumer` | `ConsumerWidget` | `Obx` | **Vestige** |
| Global DI | `context.read<T>()` | `context.read<T>()` | `ref.read` | `Get.find()` | **Titan.get()** |

Rhea leaned back. "So 'Core' is just... a reactive variable?"

"Exactly. And 'Derived' is a computed value that auto-tracks its dependencies. No manual subscription, no `addListener`."

"And 'Strike'?"

"A state mutation. Like BLoC's `emit()` inside a Cubit, but it wraps the change — middleware, logging, and batching all happen automatically."

Fen squinted at the table. "Eight concepts. That's... not bad."

"That's the whole core," Kael said. "Everything else is optional."

---

## The Three Circles

Kael drew three concentric circles on the whiteboard.

```
┌───────────────────────────────────────────────┐
│               EVERYTHING ELSE                 │
│  Trove, Moat, Pyre, Banner, Sluice, Clarion  │
│  Census, Warden, Arbiter, Lode, Tapestry...   │
│  ┌───────────────────────────────────────┐    │
│  │            WEEK ONE                   │    │
│  │  Ether, Confluence, Spark, ReadCore   │    │
│  │  Herald, Relic, Conduit               │    │
│  │  ┌───────────────────────────────┐    │    │
│  │  │          DAY ONE              │    │    │
│  │  │                               │    │    │
│  │  │  Pillar  Core  Derived        │    │    │
│  │  │  Strike  Beacon  Vestige      │    │    │
│  │  │  Titan.get()  watch()         │    │    │
│  │  │                               │    │    │
│  │  └───────────────────────────────┘    │    │
│  └───────────────────────────────────────┘    │
└───────────────────────────────────────────────┘
```

"The inner circle is Day One," Kael explained. "Eight concepts. You can build a complete feature — state, computed values, side effects, UI — with nothing else."

"The middle circle is Week One. Async loading states, hooks-style widgets, event buses, persistence. You learn these when the feature you're building demands them."

"The outer circle?" Rhea asked.

"You might never need it. Rate limiting, circuit breakers, job schedulers, event sourcing — that's enterprise infrastructure. It's there if the app grows to need it."

"How many concepts total?" Fen asked.

"Ninety-five."

The room went quiet.

"But listen," Kael said. "Seventy of those are in the outer circle. The inner circle — what you need today — is eight. BLoC's inner circle is twenty-four."

---

## Why Not Just Call It 'Store'?

Rhea wasn't finished. "I get the mapping. But *why* not just call it a Store? Or a Bloc? Why invent names?"

Kael pulled up a search.

```
$ grep -r "Provider" lib/ | wc -l
47
```

"Forty-seven hits. Flutter's Provider, Riverpod's Provider, BlocProvider, ChangeNotifierProvider, RepositoryProvider, MultiProvider, ServiceProvider. Which one do you mean?"

He changed the search:

```
$ grep -r "Pillar" lib/ | wc -l
12
```

"Twelve. Every one of them is a Titan Pillar. No ambiguity."

"So it's a namespace," Rhea said.

"It's *precision*. When you see 'Herald' in a code review, you know it's an event bus. When you see 'Conduit,' you know it's Core-level middleware. The name *is* the documentation."

---

## The First Hour

Kael gave each new developer a single file:

```dart
import 'package:titan/titan.dart';

class CounterPillar extends Pillar {
  // Core — a reactive value
  late final _count = core(0);

  // ReadCore — read-only view (consumers can read, not write)
  ReadCore<int> get count => _count;

  // Derived — computed from Cores, auto-tracks dependencies
  late final isEven = derived(() => _count.value % 2 == 0);

  // Strike — mutate state (middleware, logging, batching all apply)
  void increment() => strike(() => _count.value++);
  void decrement() => strike(() => _count.value--);
  void reset() => strike(() => _count.value = 0);
}
```

"Read it," he said. "Tell me what it does."

Fen answered first. "It's a counter. `_count` is the state. `count` is a read-only view. `isEven` is computed. The three methods change the value."

"How long did that take you?"

Fen checked the clock. "Maybe thirty seconds."

"Now write a Pillar for a to-do list. Private Cores, ReadCore getters, methods for add and remove."

Twelve minutes later, Fen had a working `TodoPillar` with three Cores, three ReadCore getters, a Derived for the pending count, and four Strike methods. No boilerplate classes, no event hierarchies, no code generation.

Rhea took fifteen minutes but added a `watch()` that logged every change.

---

## The Widget Side

Next: connecting to Flutter.

```dart
class CounterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Beacon(
      create: (_) => CounterPillar(),
      child: Vestige<CounterPillar>(
        builder: (context, pillar) {
          return Column(
            children: [
              Text('Count: ${pillar.count.value}'),
              Text(pillar.isEven.value ? 'Even' : 'Odd'),
              ElevatedButton(
                onPressed: pillar.increment,
                child: const Text('Increment'),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

"Beacon provides, Vestige consumes," Kael said. "That's the widget side. Two concepts."

"And it only rebuilds the Vestige, not the whole screen?" Rhea asked.

"Only the Vestige. And only when the specific Cores it reads actually change. If you read `count.value` but not `isEven.value`, changes to `isEven` don't rebuild you."

"That's... actually cleaner than BlocBuilder," Rhea admitted.

---

## The Printable Card

Before the session ended, Kael pinned a card to the team board:

```
┌─────────────────────────────────────────────────┐
│              TITAN QUICK REFERENCE              │
├────────────┬────────────────────────────────────┤
│ Pillar     │ Your store. Holds state & logic.   │
│ Core       │ A reactive value. core(0)          │
│ ReadCore   │ Read-only Core. Hides the setter.  │
│ Derived    │ Computed from Cores. Auto-tracks.   │
│ Strike     │ Mutate state. strike(() => ...)     │
│ Watcher    │ Side effect. watch(() => ...)       │
│ Beacon     │ Provides Pillar to widget tree.     │
│ Vestige    │ Rebuilds when Pillar state changes. │
│ Titan.get  │ Global DI. Titan.get<MyPillar>()   │
│ Ether      │ Async state: loading/data/error.    │
│ Confluence │ Multi-Pillar consumer widget.       │
│ Spark      │ Hooks-style widget (useCore, etc.)  │
├────────────┴────────────────────────────────────┤
│ That's it. Everything else is optional.         │
└─────────────────────────────────────────────────┘
```

"When you see a name you don't recognize," Kael said, "check the docs. Every name has one class, one chapter, one purpose. The name *is* the search term."

---

## The Real Numbers

That evening, Kael compiled the team's onboarding metrics:

| Developer | Background | Time to First PR | Concepts Used |
|---|---|---|---|
| Fen (Junior) | Basic Dart | 2 hours | 7 (Pillar, Core, ReadCore, Derived, Strike, Beacon, Vestige) |
| Rhea (Backend) | BLoC, Provider | 1.5 hours | 9 (+watch, Ether) |
| Contract Dev | Riverpod | 1 hour | 8 (+Titan.get) |

For comparison, Kael's last onboarding at a BLoC shop:

| Developer | Background | Time to First PR | Concepts Used |
|---|---|---|---|
| New hire | Basic Dart | 6 hours | 14 (Bloc, Cubit, Event, State, Equatable, copyWith, BlocProvider, BlocBuilder, BlocObserver, Repository, RepositoryProvider, context.read, Emitter, on<Event>) |

The names were different. The learning was faster.

---

*A map with strange names is still a map. And the shortest path through unfamiliar territory is not to rename every landmark — it's to give travelers a legend they can hold in one hand.*

---

### Lexicon Entry

| Standard Term | Titan Name | Purpose |
|---|---|---|
| Quick Reference | **Rosetta Stone** | Translation table from BLoC/Provider/Riverpod/GetX to Titan names |
| Learning Tiers | **Three Circles** | Day 1 (8) → Week 1 (12) → As Needed (70+) progressive discovery |

---

| [← Chapter LI: The Veil Conceals](chapter-51-the-veil-conceals.md) | [Chapter LIII: The Forge Accepts →](chapter-53-the-forge-accepts.md) |
