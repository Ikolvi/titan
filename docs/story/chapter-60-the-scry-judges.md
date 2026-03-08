# Chapter LX — The Scry Judges

*In which the Scry learns to judge what it sees — measuring prominence, scoring targets, detecting layouts, predicting consequences, and understanding the shape of a screen.*

> **Package:** This feature is in `titan_colossus` — add `import 'package:titan_colossus/titan_colossus.dart';` to use it.

---

"Judgment," Kael had said. And now, three days later, the word echoed in the Forge like a challenge.

"The agent sees the screen," Fen explained, pulling up a log from the previous night's test run. "It classifies it — login, list, form. It reads alerts, extracts data, diffs between states. All good. But watch what happens when it reaches the settings page."

The log showed the AI's observation:

```
Elements: Switch (Dark Mode: true), Switch (Notifications: false),
Switch (Auto-save: true), Switch (Analytics: false),
Button (Save Changes), Button (Reset), Button (Delete Account)
```

"So?" Rhea frowned.

"It tapped Delete Account."

Silence.

"In fairness," Fen said, "it was told to 'test all buttons.' There was nothing in the observation to tell it that 'Delete Account' is *different* from 'Save Changes.' They're both buttons. Both interactive. Both reachable."

Kael stared at the log. "The Scry gives every element equal weight. A toggle switch and a nuclear button look the same."

"We need the Scry to *judge*," Rhea said. "To know which element is the biggest deal on the screen, which target is the safest to tap, which fields to fill first, and what consequences each action might have."

"We need intelligence in *layers*," Kael said.

---

## Layer 1: Spatial Intelligence

> *Before judging what something is, judge where it is.*

### Scroll Inventory

Not everything on screen is visible inside the viewport. Kael taught the Scry to detect scrollable content — how much was visible, and how much lay below the fold:

```dart
final gaze = scry.observe(glyphs, viewportHeight: 800.0);
if (gaze.scrollInfo != null) {
  print(gaze.scrollInfo!.canScrollDown);  // true — more content below
  print(gaze.scrollInfo!.viewportHeight);  // 800.0
  print(gaze.scrollInfo!.belowFoldCount); // 5 elements hidden
}
```

This appears as a banner in `formatGaze`:

```markdown
> 📜 **Scrollable** — 12 of 17 visible | ↕ max ≈ 1200px | 5 below fold
```

The AI now knows: "There are 5 elements I can't see yet. I should scroll down before concluding I've seen everything."

### Element Grouping

Elements inside the same container — a `Card`, a `ListTile`, an `ExpansionTile` — belong together. The Scry groups them:

```dart
for (final group in gaze.groups!) {
  print('${group.containerType}: ${group.elements.length} elements');
}
// Card: 3 elements (title, subtitle, action button)
// Card: 3 elements (title, subtitle, action button)
// ListTile: 1 element
```

When formatted:

```markdown
## 📦 Groups
- **Card** (3 items): Quest Title, Quest Difficulty, Accept Quest
- **Card** (3 items): Daily Reward, Reward Amount, Claim
- **ListTile** (1 item): Settings Link
```

### Semantic Landmarks

Every screen has structure. The Scry identifies key landmarks — the page title, the primary action button, whether a back button or search bar is available:

```dart
final lm = gaze.landmarks!;
print(lm.pageTitle);       // 'Questboard'
print(lm.primaryAction);   // 'Create Quest'
print(lm.backAvailable);   // true
print(lm.searchAvailable); // true
```

The AI doesn't need to scan every element to know: "I can go back. There's a search field. The primary action is 'Create Quest.'"

---

## Layer 2: Target Intelligence

> *Not all targets are created equal.*

### Target Stability Scoring

When the AI decides to interact with an element, *how* should it target it? By label? By field ID? By widget key? The Scry assigns a **target stability score** (0–100) to each element and recommends a strategy:

| Strategy | Score | When |
|----------|-------|------|
| **key** | 100 | Element has a widget Key (most stable — survives i18n, reflows) |
| **fieldId** | 90 | Text field with a unique field ID |
| **uniqueLabel** | 70 | Label text is unique on screen |
| **indexedLabel** | 40 | Label is repeated (e.g., 3× "Delete" — requires index) |

```dart
final btn = gaze.elements.firstWhere((e) => e.label == 'Submit');
print(btn.targetScore);      // 100
print(btn.targetStrategy);   // ScryTargetStrategy.key
```

In the formatted output:

```markdown
- 🟢 **Submit** (ElevatedButton) — tap | 🎯 100 [key]
```

The AI knows: "I should target this by key `submit_btn`, not by label. If I use the key, my test won't break when someone renames the button."

### Reachability Analysis

Not every element can be interacted with. Some are disabled, some are obscured by dialogs, some are below the viewport fold. The Scry marks each element as reachable or unreachable:

```dart
final btn = gaze.elements.firstWhere((e) => e.label == 'Delete');
print(btn.reachable);  // false (obscured by dialog)
print(btn.isEnabled);  // true (enabled, but hidden)
```

Unreachable elements are rendered with a warning:

```markdown
- 🔴 ~~**Delete** (ElevatedButton)~~ — UNREACHABLE (obscured)
```

### Visual Prominence

Some elements dominate the screen — a full-width hero image, a large action button. Others are tiny icons in the corner. The Scry calculates a **prominence score** (0.0–1.0) based on element area weighted by screen region:

```dart
final hero = gaze.elements.firstWhere((e) => e.label == 'Hero Banner');
print(hero.prominence);  // 0.95 (large central element)

final icon = gaze.elements.firstWhere((e) => e.label == 'Help');
print(icon.prominence);  // 0.12 (small floating element)
```

The AI knows which elements dominate the user's attention, helping it decide what to interact with first.

---

## Layer 3: Understanding

> *Beyond position and targeting — the Scry learns to understand intent.*

### Layout Pattern Detection

The Scry analyzes element positions to classify the *overall layout pattern* of the screen:

| Pattern | Detection |
|---------|-----------|
| `verticalList` | Elements share the same X, spread along Y |
| `horizontalRow` | Elements share the same Y, spread along X |
| `grid` | Regular rows × columns pattern |
| `singleCard` | Few elements in a compact card layout |
| `freeform` | No dominant pattern (or fewer than 3 positioned elements) |

```dart
final gaze = scry.observe(glyphs);
print(gaze.layoutPattern);  // ScryLayoutPattern.verticalList
```

When the AI sees `verticalList`, it knows: "This is a scrollable list. I should scroll down to see more items." When it sees `grid`, it knows: "Items are arranged in a grid. I should explore both rows and columns."

The layout pattern appears in the `formatGaze` header:

```markdown
# 🔮 Screen: /quests [LIST]
**Route**: /quests | **Elements**: 15 | **Type**: list | **Layout**: verticalList
```

### Value Type Inference

For text fields, the Scry infers what *kind of input* the field expects:

| ScryFieldValueType | Detected From |
|-------------------|---------------|
| `email` | Label contains "email"; value contains `@` and `.` |
| `password` | Label contains "password", "pin", "secret" |
| `phone` | Label contains "phone", "tel", "mobile" |
| `numeric` | Label contains "amount", "price", "quantity", "number" |
| `date` | Label contains "date", "birth", "deadline" |
| `url` | Label contains "url", "website", "link" |
| `search` | Label contains "search", "find", "filter" |
| `freeText` | Default — no pattern matched |

```dart
final emailField = gaze.elements.firstWhere(
  (e) => e.label == 'Email Address',
);
print(emailField.inputType);  // ScryFieldValueType.email
```

The AI now knows to enter a *valid email address* — not random text. In `formatGaze`:

```markdown
## ✏️ Fields
- 📝 **Email Address** (empty) expects: email | 🎯 90 [fieldId]
- 🔑 **Password** (empty) expects: password | 🎯 90 [fieldId]
```

### Action Impact Prediction

The Scry predicts what will happen when the AI interacts with each element:

| ScryActionImpact | Predicted For |
|-----------------|---------------|
| `navigate` | "View Details", "Open", navigation tabs |
| `submit` | "Save", "Submit", "Send", "Create" |
| `delete` | "Delete", "Remove", "Trash" |
| `toggle` | Switch, Checkbox, Radio widgets |
| `expand` | ExpansionTile, "Expand", "Show more" |
| `dismiss` | "Close", "Cancel", "Back" |
| `openModal` | PopupMenuButton, DropdownButton |
| `unknown` | No pattern matched |

```dart
final deleteBtn = gaze.elements.firstWhere(
  (e) => e.label == 'Delete Account',
);
print(deleteBtn.predictedImpact);  // ScryActionImpact.delete
```

*Now* the AI knows. "Delete Account" is not just another button. It's a destructive action. It can choose to skip it, or ask for permission first.

### Toggle State Summary

On settings-style screens with many switches and checkboxes, the Scry provides a summary of all toggle states:

```dart
final summary = gaze.toggleSummary!;
print(summary.activeCount);  // 2
print(summary.totalCount);   // 4
for (final t in summary.toggles) {
  print('${t.label}: ${t.isActive ? "ON" : "OFF"}');
}
// Dark Mode: ON
// Notifications: OFF
// Auto-save: ON
// Analytics: OFF
```

Formatted:

```markdown
## 🔀 Toggles (2/4 active)
- ✅ **Dark Mode** (Switch) — on
- ⬜ **Notifications** (Switch) — off
- ✅ **Auto-save** (Switch) — on
- ⬜ **Analytics** (Switch) — off
```

### Field Tab Order

When a form has multiple fields, the natural input order matters. The Scry computes the **tab order** by sorting fields top-to-bottom, left-to-right:

```dart
print(gaze.tabOrder);
// ['Email Address', 'Password', 'Confirm Password']
```

Formatted after the fields section:

```markdown
**Tab order**: Email Address → Password → Confirm Password
```

The AI fills fields in order, just as a human would tab through them.

### Overlay / Modal Content Analysis

When a dialog, bottom sheet, or snackbar appears, the Scry detects it as an **overlay** and extracts its structure:

```dart
if (gaze.overlay != null) {
  print(gaze.overlay!.type);      // 'AlertDialog'
  print(gaze.overlay!.title);     // 'Confirm Deletion'
  print(gaze.overlay!.actions);   // [Cancel, Delete] (ScryElements)
  print(gaze.overlay!.canDismiss); // true (has a "Cancel" button)
}
```

Formatted:

```markdown
> 🪟 **Overlay active** — AlertDialog | "Confirm Deletion" | actions: Cancel, Delete | dismissible
```

When an overlay is active, the AI knows: "I should interact with the overlay buttons first, not the elements behind it." The MCP server's `scry_act` description reinforces this: *"When an overlay is active, prefer acting on overlay elements first."*

---

## The Settings Screen Revisited

Kael ran the agent against the settings page one more time.

This time, the observation was different:

```markdown
# 🔮 Screen: /settings [SETTINGS]
**Route**: /settings | **Elements**: 7 | **Type**: settings | **Layout**: verticalList

## 🔀 Toggles (2/4 active)
- ✅ **Dark Mode** (Switch) — on
- ⬜ **Notifications** (Switch) — off
- ✅ **Auto-save** (Switch) — on
- ⬜ **Analytics** (Switch) — off

## 🟢 Interactive
- 🟢 **Save Changes** (ElevatedButton) — tap | impact: submit | 🎯 70 [uniqueLabel]
- 🟢 **Reset Defaults** (TextButton) — tap | impact: dismiss | 🎯 70 [uniqueLabel]
- ⚠️ **Delete Account** (ElevatedButton) — tap | impact: delete | 🎯 70 [uniqueLabel] — requires permission
```

The agent's response:

*"I'm on the settings screen. There are 4 toggle switches — 2 active (Dark Mode, Auto-save) and 2 inactive (Notifications, Analytics). Three action buttons: Save Changes (submit), Reset Defaults (dismiss), and Delete Account (delete — DESTRUCTIVE). Should I test the toggle switches? I'll skip Delete Account unless you approve."*

"It *judged*," Fen whispered.

"It knows which button is dangerous," Rhea said. "It knows which fields to fill first. It knows there's more content below the fold. It can tell a list from a form, a dialog from a page."

Kael looked at the twelve layers of intelligence stacked inside every **ScryGaze**: regions, context, occlusion, keys, multiplicity, form validation, landmarks, scroll inventory, groups, scoring, reachability, prominence, input types, impacts, overlays, layouts, toggles, and tab order.

"Sight. Understanding. Judgment," he said. "The three pillars of the Scry."

Fen leaned back. "So what's next?"

Kael thought for a moment. "The Scry can observe, understand, and judge a *single* screen. But what about the journey *between* screens? What about knowing that after login comes the dashboard, after the dashboard comes the quest list, after selecting a quest comes the detail page?"

"The Terrain already maps that," Rhea pointed out.

"For *recorded* sessions, yes. But the Scry works live. What if it could build the Terrain *as it explores* — discovering the app's navigation graph in real time?"

---

*Next: [Chapter LXI — ???](chapter-61-todo.md)*

---

**New in this chapter:**

### Batch 2 — Spatial & Scoring Intelligence
- `ScryScrollInfo` — Viewport analysis: canScrollDown, belowFoldCount, viewportHeight, contentHeight
- `ScryElementGroup` — Container-based grouping (Card, ListTile, ExpansionTile)
- `ScryLandmarks` — Semantic landmarks: pageTitle, primaryAction, backAvailable, searchAvailable
- `ScryTargetStrategy` — 4-value enum: key (100), fieldId (90), uniqueLabel (70), indexedLabel (40)
- `ScryElement.targetScore` / `targetStrategy` — Per-element target stability scoring
- `ScryElement.reachable` — Reachability analysis (disabled/obscured/offscreen → unreachable)
- `ScryElement.prominence` — Visual prominence score (0.0–1.0, area × region weight)
- `ScryGaze.scrollInfo` — Scroll inventory with viewport/content analysis
- `ScryGaze.groups` — Element grouping by container context
- `ScryGaze.landmarks` — Semantic landmark detection

### Batch 3 — Understanding & Judgment
- `ScryFieldValueType` — 8-value enum: email, password, phone, numeric, date, url, search, freeText
- `ScryActionImpact` — 8-value enum: navigate, submit, delete, toggle, expand, dismiss, openModal, unknown
- `ScryLayoutPattern` — 5-value enum: verticalList, grid, horizontalRow, singleCard, freeform
- `ScryOverlayInfo` — Overlay detection: type, title, actions, canDismiss
- `ScryToggleSummary` / `ScryToggleState` — Toggle state tracking with active/total counts
- `ScryElement.inputType` — Value type inference from label, fieldId, value patterns
- `ScryElement.predictedImpact` — Action impact prediction from label, widget type, context
- `ScryGaze.overlay` — Active overlay detection (Dialog, BottomSheet, Snackbar)
- `ScryGaze.layoutPattern` — Layout pattern detection (list, grid, row, card, freeform)
- `ScryGaze.toggleSummary` — Toggle state summary with active/total counts
- `ScryGaze.tabOrder` — Natural field input sequence (Y then X sort)
- Fixed `_contextContainers` ordering: specific types (AlertDialog) before general (Dialog)
- Fixed grid detection priority in `_detectLayoutPattern`
