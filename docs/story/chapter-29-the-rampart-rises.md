# Chapter XXIX: The Rampart Rises

> *"As Questboard's fame spread from the small screens of wandering heroes to the grand displays of the war council, Kael realized the fortress walls themselves must shift — compact for the lone scout, broad for the assembled council."*

---

## The Problem

Questboard looked great on phones. But when the war council opened it on their oversized tablets and widescreen displays, the interface stretched grotesquely — buttons the size of shields, text swimming in oceans of whitespace. And when squeezed back onto a phone, the multi-column layouts collapsed into gibberish.

"We need adaptive layouts," Kael said, staring at screenshots from three different screen sizes. "Something that knows when to show a side panel and when to hide it."

Lyra pulled up Titan's archives. "There's a builder for that. It's called the **Rampart** — a wall with different tiers."

---

## The Rampart

A rampart is a defensive wall with multiple levels. Titan's `Rampart` widget provides tiered layout adaptation based on screen width:

```dart
import 'package:titan_bastion/titan_bastion.dart';

class QuestDashboard extends StatelessWidget {
  const QuestDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Rampart(
      compact: (context) => const QuestListMobile(),
      medium: (context) => const QuestListTablet(),
      expanded: (context) => const QuestListDesktop(),
    );
  }
}
```

Three tiers, Material 3 breakpoints by default:
- **compact**: 0–599px (phones)
- **medium**: 600–839px (tablets)
- **expanded**: 840px+ (desktops)

"It falls back gracefully," Lyra explained. "If you skip `medium`, it uses `compact`. If you skip `expanded`, it uses `medium` or `compact`."

```dart
// Two-tier layout — no tablet breakpoint needed
Rampart(
  compact: (context) => const MobileLayout(),
  expanded: (context) => const DesktopLayout(),
)
```

---

## Custom Breakpoints

The war council's displays were unusual — massive tactical screens that needed extra-wide breakpoints:

```dart
Rampart(
  breakpoints: const RampartBreakpoints(
    compact: 0,
    medium: 768,
    expanded: 1280,
  ),
  compact: (context) => const MobileLayout(),
  medium: (context) => const TabletLayout(),
  expanded: (context) => const DesktopLayout(),
)
```

---

## Responsive Values

Padding, font sizes, icon sizes — everything needed to scale with the tier. `RampartValue` provided per-tier values with a fallback chain:

```dart
final cardPadding = RampartValue<double>(
  compact: 8,
  medium: 16,
  expanded: 24,
);

// In a widget
Padding(
  padding: EdgeInsets.all(cardPadding.resolve(context.rampartLayout)),
  child: QuestCard(quest: quest),
)
```

For values that stay the same across tiers:

```dart
final fixedSpacing = RampartValue<double>.all(12);
```

---

## Conditional Visibility

Some elements should only appear on larger screens — the side panel, the minimap, the council chat:

```dart
RampartVisibility(
  visibleOn: {RampartLayout.medium, RampartLayout.expanded},
  child: const SidePanel(),
)
```

When hidden, the child is replaced with `SizedBox.shrink()` (zero size). For stateful children that should preserve their state when hidden:

```dart
RampartVisibility(
  visibleOn: {RampartLayout.expanded},
  maintainState: true,  // keeps state alive when hidden
  child: const ChatPanel(),
)
```

---

## Context Extensions

For quick tier checks anywhere in the tree:

```dart
Widget build(BuildContext context) {
  final layout = context.rampartLayout;

  return Column(
    children: [
      if (context.isExpanded) const BreadcrumbBar(),
      QuestList(),
      if (!context.isCompact) const QuestStats(),
    ],
  );
}
```

Available extensions:
- `context.rampartLayout` → `RampartLayout` enum
- `context.isCompact` → `bool`
- `context.isMedium` → `bool`
- `context.isExpanded` → `bool`

---

## Static Helpers

Need the tier without a widget? Use the static methods:

```dart
// From a width value
final tier = Rampart.layoutFor(800); // RampartLayout.medium

// From MediaQuery (requires BuildContext)
final tier = Rampart.layoutOf(context);
```

---

## The Questboard Dashboard

Kael built a responsive dashboard that showed a list on phones, a grid on tablets, and a full master-detail layout on desktops:

```dart
class QuestDashboard extends StatelessWidget {
  const QuestDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Questboard')),
      body: Row(
        children: [
          // Side nav only on large screens
          RampartVisibility(
            visibleOn: {RampartLayout.expanded},
            child: const NavigationRail(destinations: [...]),
          ),
          // Main content adapts
          Expanded(
            child: Rampart(
              compact: (ctx) => const QuestListVertical(),
              medium: (ctx) => const QuestGridView(),
              expanded: (ctx) => const QuestMasterDetail(),
            ),
          ),
        ],
      ),
      // Bottom nav only on small screens
      bottomNavigationBar: context.isCompact
          ? const BottomNavigationBar(items: [...])
          : null,
    );
  }
}
```

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Rampart` | Responsive layout builder with compact/medium/expanded tiers |
| `RampartBreakpoints` | Custom breakpoint thresholds (defaults to Material 3) |
| `RampartLayout` | Enum for the three tiers |
| `RampartValue<T>` | Per-tier values with fallback chain and `resolve()` |
| `RampartVisibility` | Show/hide widgets based on tier, with optional `maintainState` |
| `RampartContext` | Extensions: `rampartLayout`, `isCompact`, `isMedium`, `isExpanded` |
| `Rampart.layoutFor()` | Static: width → tier |
| `Rampart.layoutOf()` | Static: context → tier (via MediaQuery) |

---

> *"The rampart rose, its walls shifting with the terrain. Where once the fortress had strained against screens too large or too small, now it adapted — a different face for every display, but the same unbreakable structure within."*

---

[← Chapter XXVIII: The Argus Guards](chapter-28-the-argus-guards.md) · [Chapter XXX: The Cartograph Maps →](chapter-30-the-cartograph-maps.md)
