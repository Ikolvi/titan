# Chapter XVIII: The Conduit Flows

*In which Kael learns to intercept the flow of state itself, transforming values before they settle and guarding Cores against the chaos of invalid data.*

---

The bug report was elegant in its destruction: a hero's health had been set to negative three hundred.

"How?" Kael stared at the crash log. Somewhere in the codebase, a Strike had subtracted damage without checking bounds. The health Core dutifully accepted `-300`, the Derived computed a negative health bar width, and the rendering engine threw an exception trying to draw a rectangle with a negative dimension.

Kael had validation in some places — `if` checks in Strikes, Scroll validators for forms. But this wasn't a form. This was a Core being mutated deep in game logic, and the check had been forgotten. What he needed wasn't validation *around* the mutation — he needed validation *inside* the Core itself.

He needed a **Conduit**.

---

## The Conduit — Core-Level Middleware

> *A conduit is a channel through which something flows. Titan's Conduits are pipelines through which every Core value change must pass — transforming, validating, or rejecting the flow before it reaches the state.*

While `StrikeMiddleware` intercepts at the Pillar level (wrapping entire `strike()` calls), a **Conduit** operates on individual Core value changes. Every `core.value = x` assignment passes through the Conduit pipeline.

### The Anatomy of a Conduit

```dart
abstract class Conduit<T> {
  /// Transform or validate the new value before it's applied.
  /// Return the value to set. Throw ConduitRejectedException to block it.
  T pipe(T oldValue, T newValue);

  /// Called after a successful value change.
  void onPiped(T oldValue, T newValue) {}
}
```

Two methods. That's it. `pipe()` intercepts the value *before* it's applied. `onPiped()` fires *after*. The simplicity is deceptive — these two hooks enable an entire class of patterns.

---

## Clamping: The First Conduit

Kael's health bug had an obvious fix:

```dart
class HeroPillar extends Pillar {
  late final health = core(100, conduits: [
    ClampConduit(min: 0, max: 100),
  ]);

  void takeDamage(int amount) => strike(() {
    health.value -= amount;
    // Even if amount is 500, health will be clamped to 0
  });

  void heal(int amount) => strike(() {
    health.value += amount;
    // Even if amount is 999, health will be clamped to 100
  });
}
```

`ClampConduit` is built into Titan. Every value assignment passes through it:

```
health.value = -300
  → ClampConduit.pipe(100, -300)
  → returns 0
  → Core stores 0
  → Dependents see 0
```

"That's it?" The PM was skeptical. "One line fixes the negative health bug?"

"One parameter," Kael corrected. "`conduits: [ClampConduit(min: 0, max: 100)]`. The Core *cannot* hold an invalid value. Not through Strikes, not through direct assignment, not through any code path."

---

## Chaining Conduits

Conduits compose. When multiple Conduits are attached, each receives the output of the previous one (FIFO order):

```dart
late final heroName = core('', conduits: [
  TransformConduit((_, v) => v.trim()),        // 1. Remove whitespace
  TransformConduit((_, v) => v.toLowerCase()), // 2. Lowercase
  ValidateConduit((_, v) =>                    // 3. Reject if empty
    v.isEmpty ? 'Name cannot be empty' : null,
  ),
]);
```

Setting `heroName.value = '  SIR LANCELOT  '` flows through:

```
'  SIR LANCELOT  '
  → trim → 'SIR LANCELOT'
  → toLowerCase → 'sir lancelot'
  → validate → null (valid)
  → Core stores 'sir lancelot'
```

The order matters. If validation came before trimming, `'   '` would pass validation (not empty) but store whitespace.

---

## Rejecting Changes

Sometimes transformation isn't enough — you need to *reject* invalid values entirely:

```dart
class QuestPillar extends Pillar {
  late final reward = core(100, conduits: [
    ValidateConduit((_, value) =>
      value < 0 ? 'Reward cannot be negative' : null,
    ),
    ValidateConduit((_, value) =>
      value > 10000 ? 'Reward exceeds maximum' : null,
    ),
  ]);

  void setReward(int amount) {
    try {
      strike(() => reward.value = amount);
    } on ConduitRejectedException catch (e) {
      log.warning('Invalid reward: ${e.message}');
    }
  }
}
```

When a Conduit throws `ConduitRejectedException`:
- The Core's value remains **unchanged**
- No notifications are sent to dependents
- No `onPiped` callbacks fire
- The exception propagates to the caller

---

## The Freeze Conduit

As the Questboard grew, Kael discovered a pattern: some state should become immutable after a certain point. A completed quest shouldn't have its reward changed. A published hero bio shouldn't be editable.

```dart
late final questReward = core(0, conduits: [
  FreezeConduit((oldValue, _) => questStatus.value == 'completed'),
]);
```

Once `questStatus` becomes `'completed'`, every attempt to change `questReward` throws `ConduitRejectedException`. The value is frozen — not by convention, but by enforcement.

---

## Custom Conduits

The built-in Conduits cover common patterns, but Kael needed something specific: a Conduit that logged every state change to the Annals automatically.

```dart
class AuditConduit<T> extends Conduit<T> {
  final String coreName;
  final String pillarType;

  AuditConduit({required this.coreName, required this.pillarType});

  @override
  T pipe(T oldValue, T newValue) => newValue; // Pass through

  @override
  void onPiped(T oldValue, T newValue) {
    Annals.record(AnnalEntry(
      coreName: coreName,
      pillarType: pillarType,
      oldValue: oldValue,
      newValue: newValue,
      action: 'conduit_change',
    ));
  }
}
```

Now any Core could be audited with zero business logic changes:

```dart
late final status = core('draft', conduits: [
  AuditConduit(coreName: 'status', pillarType: 'QuestPillar'),
]);
```

---

## Dynamic Conduits

Conduits can be added and removed at runtime:

```dart
class AdminPillar extends Pillar {
  late final price = core(0);
  late final _clamp = ClampConduit<int>(min: 0, max: 9999);

  void enablePriceGuard() => price.addConduit(_clamp);
  void disablePriceGuard() => price.removeConduit(_clamp);
  void clearAllGuards() => price.clearConduits();
}
```

This enables feature-flag-driven validation, user-role-based constraints, and progressive enhancement patterns.

---

## The Throttle Conduit

During load testing, Kael noticed a slider that updated a Core 60 times per second was overwhelming the analytics pipeline. The `ThrottleConduit` solved it:

```dart
late final sliderValue = core(0.0, conduits: [
  ThrottleConduit(const Duration(milliseconds: 100)),
]);
```

Changes faster than 100ms apart are rejected. The UI remains responsive (it can read the current value), but the Core only accepts updates at a controlled rate.

---

## Conduit vs. StrikeMiddleware

A natural question: when do you use a Conduit versus `StrikeMiddleware`?

| | Conduit | StrikeMiddleware |
|---|---------|-----------------|
| **Level** | Individual Core value changes | Entire `strike()` calls |
| **Scope** | Per-Core | Per-Pillar |
| **Can transform** | Yes — change the value | No — observe only |
| **Can reject** | Yes — throw to block | No |
| **Knows about** | Old value, new value | Pillar instance |
| **Use for** | Validation, clamping, transforms | Logging, analytics, auth |

They complement each other. A Pillar might use `StrikeMiddleware` for analytics while individual Cores use Conduits for data integrity.

---

## The Complete Picture

Kael looked at the Questboard's health system — the one that had started this chapter with a `-300` bug:

```dart
class HeroPillar extends Pillar {
  late final health = core(100, conduits: [
    ClampConduit(min: 0, max: 100),
  ]);

  late final mana = core(50, conduits: [
    ClampConduit(min: 0, max: 200),
  ]);

  late final name = core('', conduits: [
    TransformConduit((_, v) => v.trim()),
    ValidateConduit((_, v) =>
      v.isEmpty ? 'Name required' : null,
    ),
  ]);

  late final isAlive = derived(() => health.value > 0);
  late final status = derived(() =>
    health.value > 50 ? 'healthy' : health.value > 0 ? 'wounded' : 'fallen',
  );
}
```

Every Core that needed protection had it — built into the reactive layer, not scattered across business logic. The `-300` bug was structurally impossible now.

"The Conduit doesn't just fix bugs," Kael told the team during the next architecture review. "It prevents entire *categories* of bugs. When a Core can't hold an invalid value, you don't need to check for invalid values downstream."

---

The junior developer raised her hand. "What if we need to compose all of this — Conduits on Cores, StrikeMiddleware on Pillars, Watchers for side effects, Heralds for cross-Pillar events?"

Kael smiled. "That's the point. Each tool has one job. They compose because they don't overlap."

She looked at the architecture diagram on the whiteboard — Pillars holding Cores, Conduits guarding the flow, Watchers observing the ripples, Heralds carrying the signals between domains. Eighteen chapters of patterns, each doing one thing well, all fitting together like the gears of something ancient and powerful.

"It's not just a framework," she said quietly. "It's an architecture."

Kael nodded. "Total Integrated Transfer Architecture Network. Titan."

---

*The Conduit lesson is clear: guard the source, not the stream. When state itself refuses to be invalid, everything downstream is safe.*

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
| **XVIII** | **The Conduit Flows** |
| [XIX](chapter-19-the-prism-reveals.md) | The Prism Reveals |
