# Chapter XXX: The Cartograph Maps

> *"Every path in the realm had a name, and every name had a path. But when strangers arrived carrying scrolls with cryptic addresses — deep links from distant kingdoms — someone had to translate. That someone was the Cartograph."*

---

## The Problem

Questboard's routing was solid. Atlas handled navigation, Passages defined routes, Sentinels guarded them. But then came the deep links.

A hero tapped a link in a message: `questboard://quest/42/rewards`. The app launched — and showed the home screen. The deep link was lost.

"Atlas knows the routes," Kael said, "but it doesn't know how to parse an arbitrary URI into the right route. We need a mapper."

Lyra nodded. "We need the **Cartograph** — a map of every named route."

---

## The Cartograph

A cartograph is a mapmaker's tool. Titan's `Cartograph` maps between named routes and URI paths, enabling:

- **Named route navigation** (go by name, not by path)
- **URL building** (construct paths from names + params)
- **Deep link resolution** (parse URIs into route matches)

```dart
import 'package:titan_atlas/titan_atlas.dart';

final cartograph = Cartograph(
  routes: {
    'home': '/',
    'quest-list': '/quests',
    'quest-detail': '/quests/:id',
    'quest-rewards': '/quests/:id/rewards',
    'profile': '/profile/:username',
    'settings': '/settings',
  },
);
```

---

## Named Route Navigation

Instead of remembering path strings, navigate by name:

```dart
// Build a URL from a route name
final url = cartograph.buildUrl('quest-detail', params: {'id': '42'});
// → '/quests/42'

final rewardsUrl = cartograph.buildUrl(
  'quest-rewards',
  params: {'id': '42'},
);
// → '/quests/42/rewards'

// Navigate using the built URL
Atlas.of(context).go(url);
```

With query parameters:

```dart
final url = cartograph.buildUrl(
  'quest-list',
  queryParams: {'sort': 'newest', 'limit': '20'},
);
// → '/quests?sort=newest&limit=20'
```

---

## Deep Link Parsing

When a URI arrives from outside the app, the Cartograph parses it into a `CartographMatch`:

```dart
final match = cartograph.match('/quests/42/rewards');

if (match != null) {
  print(match.name);       // 'quest-rewards'
  print(match.params);     // {'id': '42'}
  print(match.path);       // '/quests/42/rewards'
}
```

If no route matches, `match()` returns `null`:

```dart
final noMatch = cartograph.match('/unknown/path');
// → null
```

---

## Deep Link Handling

Wire the Cartograph into your Atlas configuration for automatic deep link resolution:

```dart
final atlas = Atlas(
  passages: [
    Passage(path: '/', builder: (wp) => const HomeScreen()),
    Passage(path: '/quests', builder: (wp) => const QuestListScreen()),
    Passage(
      path: '/quests/:id',
      builder: (wp) => QuestDetailScreen(id: wp.runes['id']!),
    ),
    Passage(
      path: '/quests/:id/rewards',
      builder: (wp) => QuestRewardsScreen(id: wp.runes['id']!),
    ),
  ],
);
```

Handle incoming deep links by matching and navigating:

```dart
void handleDeepLink(Uri uri) {
  final match = cartograph.match(uri.path);
  if (match != null) {
    final url = cartograph.buildUrl(match.name, params: match.params);
    atlas.go(url);
  }
}
```

---

## Reverse Lookups

Given a path, find the route name — useful for analytics and breadcrumbs:

```dart
final match = cartograph.match('/profile/kael');

if (match != null) {
  analytics.trackScreen(match.name); // 'profile'
  print(match.params);               // {'username': 'kael'}
}
```

---

## The Deep Link Crisis

It happened during the Festival of Quests. The war council sent out thousands of scrolls — each containing a deep link to a specific quest reward. Heroes tapped the links and... landed on the home screen.

Kael registered the Cartograph:

```dart
final cartograph = Cartograph(
  routes: {
    'home': '/',
    'quest-detail': '/quests/:id',
    'quest-rewards': '/quests/:id/rewards',
    'leaderboard': '/leaderboard',
  },
);

// In the app's deep link handler
void onDeepLink(Uri uri) {
  final match = cartograph.match(uri.path);
  if (match == null) {
    // Unknown link — go home
    atlas.go('/');
    return;
  }

  switch (match.name) {
    case 'quest-rewards':
      final questId = match.params['id']!;
      atlas.go('/quests/$questId/rewards');
    case 'quest-detail':
      final questId = match.params['id']!;
      atlas.go('/quests/$questId');
    default:
      atlas.go(match.path);
  }
}
```

The deep links resolved instantly. Heroes tapped and arrived exactly where intended — the reward screen for quest 42, the leaderboard, the profile page.

---

## CartographMatch

The match result contains everything needed:

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | The matched route name |
| `path` | `String` | The original path that was matched |
| `params` | `Map<String, String>` | Extracted path parameters |

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Cartograph` | Named route registry — maps names ↔ URI patterns |
| `CartographMatch` | Match result with name, path, and extracted params |
| `buildUrl()` | Build a URL from a route name + params + optional query params |
| `match()` | Parse a URI path into a `CartographMatch` (or null) |
| Deep link handling | Match incoming URIs → navigate to the correct route |
| Reverse lookups | Path → route name for analytics and breadcrumbs |

---

> *"The Cartograph unrolled across the table, every path named, every name mapped to a path. No deep link would go unanswered again — for the mapmaker knew every road in the realm."*

---

[← Chapter XXIX: The Rampart Rises](chapter-29-the-rampart-rises.md)
