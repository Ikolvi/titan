# Chapter LI — The Veil Conceals

*In which Kael learns that the strongest defense is not what a wall blocks, but what a veil chooses to reveal.*

---

The code review landed at dawn.

Three new team members had joined Ironclad Labs overnight — a backend developer named Rhea, a junior named Fen, and a contractor who preferred to remain anonymous. They dove into the Questboard codebase with the enthusiasm of heroes entering a dungeon, and by noon, the bug reports were already flowing.

"Someone's setting `questsCompleted.value = -5` directly from the UI layer," Kael murmured, scanning the diff. It was Fen's code. Well-intentioned. Direct. And catastrophically wrong — the negative quest count had cascaded through three Derived computations, crashed a Conduit pipeline, and triggered a Vigil alert.

The Elder Architect appeared at Kael's desk, a mug of something ancient and steaming in hand.

"Your Cores are exposed," the Elder said simply. "Anyone who holds a Pillar can read *and write* every Core. You built walls around the state with Conduits and Strikes, but you left the gates wide open."

"I trust the team to use Strikes —"

"Trust is a luxury architecture cannot afford." The Elder set down the mug. "What you need is not a gate. You need a **Veil** — something that reveals the value but conceals the means to change it."

---

## The Problem: Exposed Mutation

Consider a typical Pillar. Every Core field is public, and every public Core exposes both `.value` (read) and `.value =` (write):

```dart
class HeroPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final questsCompleted = core(0);
  late final glory = core(0);
}
```

Any code with access to the Pillar can do this:

```dart
final pillar = Titan.get<HeroPillar>();

// Read — fine
print(pillar.questsCompleted.value);

// Write — bypasses all business logic!
pillar.questsCompleted.value = -5;   // 💥
pillar.glory.value = 999999;         // 💥
```

No Strike was called. No Conduit was consulted. No Watcher observed the change through the proper channel. The mutation slipped past every safeguard because the Core itself was exposed.

---

## ReadCore — The Veil Over the Core

> *A ReadCore is a read-only view of a Core. It reveals the value, the previous value, the name, the disposed state, and the ability to listen and select — but it conceals the setter. The mutation path simply does not exist.*

`ReadCore<T>` is an abstract interface class that exposes *only* the read side of a Core:

```dart
abstract interface class ReadCore<T> {
  /// The current value (read-only).
  T get value;

  /// The previous value before the last change.
  T? get previousValue;

  /// The debug name, if any.
  String? get name;

  /// Whether this Core has been disposed.
  bool get isDisposed;

  /// Read the value without subscribing to changes.
  T peek();

  /// Listen for changes.
  void Function() listen(
    void Function(T value) callback, {
    bool fireImmediately,
  });

  /// Derive a fine-grained selection.
  TitanComputed<R> select<R>(
    R Function(T value) selector, {
    String? name,
  });
}
```

Every `Core<T>` already implements `ReadCore<T>`. The power isn't in new functionality — it's in *type narrowing*. When you return a Core as `ReadCore<T>`, the compiler removes the `.value =` setter from the API.

---

## The Convention: Private Core, Public Veil

The Elder drew a pattern on the whiteboard. Two lines per field — one private, one public:

```dart
class HeroPillar extends Pillar {
  // Private — only this Pillar can mutate
  late final _heroName = core('Unknown Hero');
  late final _questsCompleted = core(0);
  late final _glory = core(0);

  // Public — consumers see ReadCore (no setter)
  ReadCore<String> get heroName => _heroName;
  ReadCore<int> get questsCompleted => _questsCompleted;
  ReadCore<int> get glory => _glory;

  // Mutation goes through methods with business logic
  void completeQuest() => strike(() {
    _questsCompleted.value++;
    _glory.value += 10;
  });

  void rename(String name) => strike(() {
    if (name.trim().isEmpty) return;
    _heroName.value = name.trim();
  });
}
```

"Outside the Pillar," the Elder explained, "the consumer sees `ReadCore<int>` — they can read `questsCompleted.value`, listen for changes, create selectors, and pass it to Vestige widgets. But they *cannot* write to it. The compiler won't let them."

---

## What ReadCore Preserves

The Veil doesn't compromise reactivity. Everything that makes Cores powerful for consumers still works:

```dart
final pillar = Titan.get<HeroPillar>();

// ✅ Reading works
print(pillar.questsCompleted.value); // 0

// ✅ Listening works
final stop = pillar.glory.listen((g) => print('Glory: $g'));

// ✅ Fine-grained selection works
final highGlory = pillar.glory.select((g) => g > 100);

// ✅ Peek (untracked read) works
final currentName = pillar.heroName.peek();

// ❌ Writing is a compile error
pillar.questsCompleted.value = -5;   // Error: no setter 'value'
pillar.glory.value = 999999;         // Error: no setter 'value'
```

"The consumer *sees* everything they need," the Elder said. "They just can't *touch* anything they shouldn't."

---

## Vestige Still Works

Because `ReadCore<T>` preserves the reactive contract, Vestige widgets track ReadCore getters exactly as they would raw Cores:

```dart
class QuestCountWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Vestige<HeroPillar>(
      builder: (context, pillar) {
        // pillar.questsCompleted is ReadCore<int> — auto-tracked
        return Text('Quests: ${pillar.questsCompleted.value}');
      },
    );
  }
}
```

No special adapters. No `.watch()` call. No `ObservableValue` wrapper. ReadCore *is* a Core to the reactive engine — it just has a narrower type at the Dart level.

---

## Handling Core Extensions

Kael noticed a subtlety. Some of his Cores used extension methods like `.increment()`, `.toggle()`, and `.add()`:

```dart
// Inside the Pillar — these work on private Cores
_questsCompleted.increment();        // Core extension ✅
_isSpecialMode.toggle();             // Core extension ✅
_tags.add('legendary');              // Core extension ✅
```

But ReadCore doesn't expose these extensions. The Pillar wraps them in methods:

```dart
class HeroPillar extends Pillar {
  late final _questsCompleted = core(0);
  late final _isSpecialMode = core(false);
  late final _tags = core(<String>[]);

  ReadCore<int> get questsCompleted => _questsCompleted;
  ReadCore<bool> get isSpecialMode => _isSpecialMode;
  ReadCore<List<String>> get tags => _tags;

  // Wrapper methods for Core extensions
  void incrementQuests() => _questsCompleted.increment();
  void toggleSpecialMode() => _isSpecialMode.toggle();
  void addTag(String tag) => _tags.add(tag);
}
```

"Every mutation surface becomes a named method," the Elder said. "The API tells the story of *what can happen to this state*. Not just *what value it holds*."

---

## The Pattern in Practice

Kael refactored the entire QuestboardPillar:

```dart
class QuestboardPillar extends Pillar {
  // ── Private Cores ──────────────────────────
  late final _heroClass = core('Warrior');
  late final _glory = core(0);
  late final _questsCompleted = core(0);

  // ── Public ReadCore getters ────────────────
  ReadCore<String> get heroClass => _heroClass;
  ReadCore<int> get glory => _glory;
  ReadCore<int> get questsCompleted => _questsCompleted;

  // ── Public mutation methods ────────────────
  void selectClass(String heroClass) => strike(() {
    _heroClass.value = heroClass;
    _glory.value = 0;
    _questsCompleted.value = 0;
  });

  void completeQuest({int gloryReward = 10}) => strike(() {
    _questsCompleted.value++;
    _glory.value += gloryReward;
  });
}
```

The UI layer touched nothing but ReadCore getters and mutation methods. No direct `.value =` assignments. No bypassed Strikes. No accidental state corruption.

---

## When to Use ReadCore

ReadCore is a *convention*, not a requirement. The reactive engine doesn't care — it tracks all Cores the same way. Use ReadCore when:

| Scenario | Use ReadCore? |
|---|---|
| Team projects with multiple developers | **Yes** — prevents accidental direct mutation |
| Pillar exposed via DI (`Titan.get()`) | **Yes** — consumers shouldn't mutate directly |
| Pillar-internal Cores (private fields) | **No** — the Pillar itself needs full access |
| Quick prototyping or small apps | Optional — speed matters more than encapsulation |
| Libraries or published packages | **Yes** — API consumers should not depend on setters |

"The Veil is for teams and for time," the Elder said. "A solo developer today may trust themselves. But the developer who reads this code next month — or the one who joins next quarter — they'll thank you for hiding the setter."

---

*The strongest walls are not the ones that block every passage. They are the ones that reveal a clear path forward — and ensure no other path exists.*

---

### Lexicon Entry

| Standard Term | Titan Name | Purpose |
|---|---|---|
| Read-Only State View | **ReadCore** | Compile-time type-narrowed view of Core — hides `.value` setter |
| ReadCore Convention | **Veil** | Private Core fields + public `ReadCore<T>` getters — mutation only via Pillar methods |

---

| [← Chapter L: The Tapestry Unfolds](chapter-50-the-tapestry-unfolds.md) |
