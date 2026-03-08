# Chapter LIX — The Gaze Deepens

*In which the Scry learns not merely to see, but to understand — classifying screens, detecting alerts, reading data, and remembering what changed.*

> **Package:** This feature is in `titan_colossus` — add `import 'package:titan_colossus/titan_colossus.dart';` to use it.

---

The Scry could see. It could act. But after a week of watching the AI agent explore the Questboard, Kael noticed something troubling.

"It found the login screen," Fen reported, scrolling through the session log. "Entered credentials. Tapped the button. Great. Then it landed on the quest list and..."

"And?" Rhea prompted.

"It described it as 'a screen with 12 content elements and 3 buttons.' That's technically true. But a *person* would say 'it's a list of quests.' The AI doesn't understand *what kind of screen* it's looking at."

Kael pulled up another log. "And here — the app showed an error snackbar for two seconds. The AI's observation happened to capture it in the glyph data, but it was buried in the content list alongside the AppBar title and the hero's name. The AI didn't notice it was an *error*."

"It sees everything equally," Rhea said. "It has no sense of importance."

"Then we give it one," Kael said.

---

## Screen Classification

> *A login screen is not merely "a screen with fields." It is a gate. The Scry must know the difference.*

Kael defined nine screen types — archetypes that cover the vast majority of mobile app screens:

| ScryScreenType | Detection Logic | Example |
|----------------|----------------|---------|
| `login` | Has text fields AND a login/signup/sign-in button | Login page, registration form |
| `form` | Has text fields AND a submit/save/create button (but not login) | Quest creation, profile edit |
| `settings` | Has toggles, switches, or "settings" in structural labels | App settings page |
| `list` | Many content elements relative to interactive ones | Quest list, hero roster |
| `detail` | Few interactive elements, moderate content | Quest detail view |
| `empty` | Very few elements total (< 3) | Blank state, loading placeholder |
| `error` | Error snackbar or error text detected in alerts | Error overlay, failure page |
| `dashboard` | Mix of buttons, content, and navigation | Home screen with stats and actions |
| `unknown` | Default when no pattern matches | Unusual or transitional screens |

The classification uses *priority ordering*: `error` beats everything (you always want to know about errors first), then `login`, `settings`, `form`, `empty`, `list`, `detail`, `dashboard`, and finally `unknown`.

```dart
final gaze = scry.observe(glyphs, route: '/login');
print(gaze.screenType);  // ScryScreenType.login

final questList = scry.observe(questGlyphs, route: '/quests');
print(questList.screenType);  // ScryScreenType.list
```

The screen type appears at the top of every formatted Gaze:

```markdown
# 🔮 Screen: /login [LOGIN]
**Route**: /login | **Elements**: 4 | **Type**: login
```

Now the AI knows *instantly* what kind of screen it's looking at. A login screen calls for credentials. A list screen calls for selecting an item. A form screen calls for filling fields and submitting.

---

## Alert Detection

> *An error banner that scrolls past unnoticed is worse than no monitoring at all.*

The second intelligence was alert detection. Kael taught the Scry to recognize four severity levels:

| Severity | Icon | What triggers it |
|----------|------|-----------------|
| `error` | 🔴 | Error text patterns ("Error:", "Failed", "Invalid"), SnackBar with error patterns |
| `warning` | 🟡 | MaterialBanner alerts, warning-pattern text |
| `info` | 🔵 | SnackBar without error/warning patterns |
| `loading` | ⏳ | CircularProgressIndicator, LinearProgressIndicator, RefreshIndicator |

The detection works through three mechanisms:

**Widget type matching** — Loading indicators are identified by their widget type alone. CircularProgressIndicator, LinearProgressIndicator, and RefreshIndicator are *always* loading alerts.

**Ancestor chain inspection** — Scry examines the ancestor chain (up to 5 levels stored in each glyph). If an element has `SnackBar` in its ancestors, its label becomes a snackbar alert. If it has `MaterialBanner`, it becomes a banner alert. The severity depends on whether the label contains error keywords.

**Text pattern matching** — Labels are checked against error patterns: "error", "failed", "invalid", "denied", "unauthorized", "not found", "timed out", and more. A content element labeled "Failed to load quests" becomes an error alert.

```dart
final gaze = scry.observe(glyphs, route: '/quests');

for (final alert in gaze.alerts) {
  print('${alert.severity}: ${alert.message}');
  // error: Failed to load quests
  // loading: (CircularProgressIndicator)
}

print(gaze.hasErrors);  // true — at least one error-severity alert
print(gaze.isLoading);  // true — at least one loading indicator
```

Alerts appear prominently in the formatted output:

```markdown
## ⚡ Alerts
- 🔴 **error**: Failed to load quests (SnackBar)
- ⏳ **loading**: (CircularProgressIndicator)
```

The AI no longer needs to scan through dozens of content elements hoping to spot an error. Alerts are surfaced *first*, before everything else.

---

## Key-Value Pair Extraction

> *"Class: Scout" is not just text. It is a fact about the hero.*

Many screens display structured data — a hero's stats, a quest's details, an order summary. These appear as label-value pairs: "Class: Scout", "Level: 42", "Glory: 1,250". Kael taught the Scry to recognize them.

Two extraction strategies work together:

**Inline Pattern** — A single content element containing text that matches `Key: Value` format. The regex splits on the first colon, trimming whitespace. "Class: Scout" becomes `ScryKeyValue(key: "Class", value: "Scout")`.

```dart
// Recognized patterns:
// "Class: Scout"     → key: "Class",     value: "Scout"
// "Level: 42"        → key: "Level",     value: "42"
// "Status: Active"   → key: "Status",    value: "Active"

// NOT recognized (skipped):
// "Enter your email" — no colon
// "Hero Name"        — interactive field, not data
// "A very long key name that exceeds 30 characters: value" — key too long
```

**Proximity Pairing** — Two non-interactive content elements that sit at the same Y-coordinate (within 8 pixels). If a short label (≤ 20 characters) appears next to a value on the same row, they're paired. This handles layouts where the label and value are separate widgets but visually adjacent.

```dart
final gaze = scry.observe(heroDetailGlyphs, route: '/hero/1');

for (final kv in gaze.dataFields) {
  print('${kv.key} = ${kv.value}');
  // Class = Scout
  // Level = 42
  // Glory = 1,250
}
```

Data fields appear in a dedicated section of the formatted output:

```markdown
## 📊 Data Fields
- **Class**: Scout
- **Level**: 42
- **Glory**: 1,250
```

Now the AI can *read* the screen's data, not just list its elements. When testing a quest completion flow, it can verify "Status: Completed" appeared in the data fields.

---

## Action Suggestions

> *"What should I do here?" — the most common question an AI asks itself.*

Kael added context-aware suggestions based on the detected screen type. Instead of the AI guessing what to do next, the Scry offers hints:

```dart
final gaze = scry.observe(loginGlyphs, route: '/login');
print(gaze.suggestions);
// [
//   "This is a login screen. Enter credentials in the text fields.",
//   "After entering credentials, tap the login/submit button.",
// ]
```

Each screen type generates different suggestions:

| Screen Type | Suggestions |
|-------------|------------|
| `login` | Enter credentials, tap login button |
| `form` | Fill required fields, tap submit |
| `list` | Tap an item to see details, check for empty states |
| `error` | An error is displayed — read alert details, retry or navigate away |
| `loading` | Content is loading — wait and re-observe |
| `detail` | Review content, look for action buttons |
| `settings` | Toggle settings, verify changes persist |
| `dashboard` | Explore available actions and navigation |
| `empty` / `unknown` | Investigate further, navigate to other screens |

Suggestions appear at the end of the formatted Gaze:

```markdown
## 💡 Suggestions
- This is a login screen. Enter credentials in the text fields.
- After entering credentials, tap the login/submit button.
```

---

## State Diffing: ScryDiff

> *The most important information is not what's on screen — it's what changed.*

The final intelligence was the ability to *compare* two observations. After the AI performs an action, the critical question isn't "what's on screen now?" — it's "what's *different*?"

Kael built `ScryDiff` — a pure comparison between two `ScryGaze` snapshots:

```dart
final before = scry.observe(loginGlyphs, route: '/login');
// ... AI taps "Enter the Questboard" ...
final after = scry.observe(questGlyphs, route: '/quests');

final diff = scry.diff(before, after);

print(diff.routeChanged);      // true (/login → /quests)
print(diff.screenTypeChanged); // true (login → list)
print(diff.appeared);          // [Quest 1, Quest 2, Quest 3, ...]
print(diff.disappeared);       // [Hero Name, Enter the Questboard, ...]
print(diff.changedValues);     // {} — no fields with changed values
print(diff.hasChanges);        // true
```

The diff tracks five dimensions of change:

| Dimension | What it detects |
|-----------|----------------|
| `appeared` | Elements present in the new Gaze but not the old one |
| `disappeared` | Elements present in the old Gaze but not the new one |
| `changedValues` | Fields that exist in both but have different `currentValue` |
| `routeChanged` | Route path changed between observations |
| `screenTypeChanged` | Screen type classification changed |

### Formatted Diff

The `diff.format()` method produces AI-readable Markdown:

```markdown
# 🔄 Screen Changes

**Route**: /login → /quests
**Screen Type**: login → list

## ➕ Appeared (5)
- Quest 1 (content)
- Quest 2 (content)
- Quest 3 (content)
- Quests (navigation)
- Hero (navigation)

## ➖ Disappeared (3)
- Hero Name (field)
- Enter the Questboard (button)
- Welcome, Hero (content)
```

### The MCP Tool: scry_diff

The MCP server uses `scry_diff` to make comparison automatic. It remembers the last observation — whether from `scry`, `scry_act`, or a previous `scry_diff` — and compares against the current screen:

```
AI calls: scry_diff

MCP Server:
  1. Recalls the last ScryGaze (_lastGaze)
  2. Observes the current screen
  3. Runs scry.diff(lastGaze, currentGaze)
  4. Updates _lastGaze to the new observation
  5. Returns: formatted diff + full current Gaze
```

The agent loop becomes even more powerful:

```
1. Call scry → initial observation (stored as _lastGaze)
2. Perform some action (tap, enter text)
3. Call scry_diff → see exactly what changed
4. Decide next action based on the diff
5. Repeat from step 2
```

No need to mentally compare two full Gaze outputs. The diff highlights exactly what matters.

---

## The Complete Intelligence Layer

Together, these five capabilities transform the Scry from a raw observer into an intelligent assistant:

```
┌──────────────────────────────────────────────────────────┐
│                  Scry Intelligence Layer                 │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Screen Type  │  │    Alerts    │  │  Key-Value    │  │
│  │  Detection    │  │  Detection   │  │  Extraction   │  │
│  │  (9 types)    │  │  (4 levels)  │  │  (2 methods)  │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
│                                                          │
│  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │   Action     │  │         State Diffing            │  │
│  │  Suggestions │  │  (appeared / disappeared /       │  │
│  │  (per type)  │  │   changed / route / screen)     │  │
│  └──────────────┘  └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

A formatted Gaze now reads like a *briefing*, not a data dump:

```markdown
# 🔮 Screen: /login [LOGIN]
**Route**: /login | **Elements**: 4 | **Type**: login

## ⚡ Alerts
- ⏳ **loading**: (CircularProgressIndicator)

## 📝 Text Fields (1)
- **Hero Name** (TextField, fieldId: hero_name_login, value: "")

## 🔘 Buttons (1)
- **Enter the Questboard** (FilledButton)

## 📄 Content (2)
- Welcome, Hero
- Choose your name to begin

## 📊 Data Fields
(none detected)

## 💡 Suggestions
- This is a login screen. Enter credentials in the text fields.
- After entering credentials, tap the login/submit button.
```

---

Fen ran the agent again. This time, instead of describing the quest list as "12 content elements and 3 buttons," the AI's first message was different:

*"I'm looking at a list screen (/quests) showing 10 quests. There's a loading indicator — content is still being fetched. I'll wait and re-observe."*

Thirty seconds later:

*"Loading completed. The screen now shows 15 quests, 3 navigation tabs, and no errors. I notice the following data: Quests Available: 15, Completed: 3. I'll tap the first quest to check the detail view."*

After tapping:

*"Screen changed from list → detail. Route: /quests → /quest/1. New elements appeared: quest title, description, difficulty rating. The 'Accept Quest' button appeared. The tab navigation disappeared (we're in a sub-page). Diff shows 12 elements appeared, 13 disappeared."*

"It's not just seeing anymore," Fen said quietly. "It's *reading*."

Kael watched the diff output scroll past — precise, structured, intelligent. Every change documented. Every alert surfaced. Every screen understood.

"Sight was the first step," he said. "Understanding is the second."

Rhea leaned forward. "What's the third?"

Kael smiled. "Judgment."

---

*Next: [Chapter LX — The Scry Judges](chapter-60-the-scry-judges.md)*

---

**New in this chapter:**
- `ScryScreenType` — 9-value enum: login, form, list, detail, settings, empty, error, dashboard, unknown
- `ScryAlertSeverity` — 4-value enum: error, warning, info, loading
- `ScryAlert` — Detected alert with severity, message, and source widget type
- `ScryKeyValue` — Extracted key-value data pair (inline or proximity-based)
- `ScryDiff` — Pure comparison between two ScryGaze snapshots
- `ScryGaze.screenType` — Automatic screen type classification
- `ScryGaze.alerts` — Detected errors, warnings, loading indicators
- `ScryGaze.dataFields` — Extracted key-value pairs from screen content
- `ScryGaze.suggestions` — Context-aware next action hints
- `ScryGaze.hasErrors` — Quick check for error-severity alerts
- `ScryGaze.isLoading` — Quick check for loading indicators
- `Scry.diff(before, after)` — Compare two observations to detect changes
- `ScryDiff.format()` — AI-readable Markdown summary of all changes
- `ScryDiff.routeChanged` / `screenTypeChanged` / `hasChanges` — Quick change checks
- MCP tool: `scry_diff` — Auto-compare against last observation with `_lastGaze` caching
- Screen classification priority: error > login > settings > form > empty > list > detail > dashboard > unknown
- Alert detection: widget type (loading indicators), ancestor chain (SnackBar, MaterialBanner), text patterns (error keywords)
- KV extraction: inline `Key: Value` regex + proximity Y-band pairing (8px tolerance)
- Action suggestions: per-screen-type contextual hints for AI decision-making
