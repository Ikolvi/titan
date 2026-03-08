# Chapter LVIII — The Scry Pierces

*In which the machines learn not merely to replay the past, but to see the present — and to act upon what they see with their own judgment.*

> **Package:** This feature is in `titan_colossus` — add `import 'package:titan_colossus/titan_colossus.dart';` to use it.

---

The Campaign system was powerful. The Stratagems were precise. But they were all written *before* the test ran.

"Every Campaign is a prophecy," Fen said, studying the Gauntlet's latest batch of edge-case tests. "It says: go here, tap this, expect that. And if the app changes between when the test was written and when it runs..."

"The prophecy fails," Rhea finished.

They'd seen it happen. A designer moved a button. A backend changed a loading state. A feature flag toggled an entirely different screen. The Campaign still charged forward on its predetermined path, tapping coordinates that no longer held the button it expected, waiting for elements that had been renamed.

Kael set down his tools. "Campaigns are scripts. We need something that can *see*."

He turned to the forge and began building something new.

---

## The Scry

> *"To scry" — to see distant events through magical means. The Scry gives machines eyes.*

The concept was radical: instead of executing a pre-written script of actions, give the AI assistant *live vision* of the running app. Let it observe what's on screen right now, decide what to do, act, and then observe again.

An autonomous agent loop. See → decide → act → repeat.

```
┌──────────────────────────────────────────────────┐
│                  AI Agent Loop                   │
│                                                  │
│   ┌─────────┐     ┌────────┐     ┌──────────┐   │
│   │  scry   │ ──▶ │ AI     │ ──▶ │ scry_act │   │
│   │(observe)│     │(decide)│     │  (act)   │   │
│   └─────────┘     └────────┘     └──────────┘   │
│        ▲                              │          │
│        │          new screen          │          │
│        └──────────────────────────────┘          │
└──────────────────────────────────────────────────┘
```

Kael called the observation result a **Gaze** — a snapshot of the screen as the AI understands it, not as pixels or a raw widget tree, but as *meaningful categories*: buttons you can tap, fields you can type in, navigation you can traverse, content you can read, and structural chrome you can ignore.

```dart
final gaze = scry.observe(glyphs, route: '/login');

print(gaze.buttons);    // [Enter the Questboard]
print(gaze.fields);     // [Hero Name]
print(gaze.navigation); // []
print(gaze.content);    // [Welcome, Hero]
```

---

## The Five Kinds

> *Not all elements deserve equal attention. The Scry teaches machines to focus.*

Every glyph captured by the Shade's Tableau is classified into one of five kinds:

| Kind | What it means | Example |
|------|---------------|---------|
| **Button** | Interactive — can be tapped | `Sign Out`, `Submit Quest` |
| **Field** | Text input — can be typed into | `Hero Name`, `Email` |
| **Navigation** | Tab, nav bar, drawer item | `Quests`, `Heroes`, `Settings` |
| **Content** | Display-only text or image | `Welcome, Kael`, `Quest #42` |
| **Structural** | UI chrome (AppBar title, tooltip) | `Questboard`, toolbar labels |

```dart
switch (element.kind) {
  case ScryElementKind.button:
    // The AI can tap this
  case ScryElementKind.field:
    // The AI can type into this
  case ScryElementKind.navigation:
    // The AI can navigate here
  case ScryElementKind.content:
    // Read-only information
  case ScryElementKind.structural:
    // UI scaffolding — usually ignorable
}
```

The classification isn't just string matching. Scry tracks which widget types appeared for each label across the entire glyph set. A label like "Hero Name" might appear as both a `RichText` (the decoration label) and a `TextField` (the actual input). Scry's two-pass algorithm ensures the *interactive* widget wins:

**Pass 1** — Scan all glyphs, recording which labels have text input widgets. Track the "preferred" widget type, interaction type, semantic role, and current value for each label.

**Pass 2** — Deduplicate by label. For each unique label, use the preferred values from Pass 1. A label that appeared as both `RichText` and `TextField` becomes a `field`, not `content`.

---

## The Gaze

> *A Gaze is not raw data. It is understanding.*

The `ScryGaze` is the structured result of observation. It groups elements by kind and provides quick access patterns:

```dart
class ScryGaze {
  List<ScryElement> get buttons;     // Tappable elements
  List<ScryElement> get fields;      // Text inputs
  List<ScryElement> get navigation;  // Navigation items
  List<ScryElement> get content;     // Display-only
  List<ScryElement> get structural;  // UI chrome
  List<ScryElement> get gated;       // ⚠️ Destructive actions

  String? route;       // Current route path
  int glyphCount;      // Raw glyph count (for diagnostics)
  bool isAuthScreen;   // Auto-detected login/signup screens
}
```

The Gaze also detects auth screens automatically — if the screen has text fields and a login/signup button, `isAuthScreen` is true. This helps the AI agent understand context without being told.

---

## Formatted Output

> *The AI does not read Dart objects. It reads Markdown.*

`formatGaze` transforms a Gaze into structured Markdown that any AI assistant can parse:

```markdown
# 🔮 Screen: /login
**Route**: /login | **Elements**: 4

## 📝 Text Fields (1)
Use `scry_act(action: "enterText", label: "<label>", value: "<text>")` to type into a field.
- **Hero Name** (TextField, fieldId: hero_name_login, value: "Kael")

## 🔘 Buttons (1)
- **Enter the Questboard** (FilledButton)

## 📄 Content (2)
- Welcome, Hero
- Choose your name to begin
```

Every section includes usage instructions. The AI doesn't need to guess the API — the output *teaches* the API.

---

## Acting: scry_act

> *Sight without action is merely watching. The Scry gives machines hands.*

The companion to `scry` is `scry_act` — it performs a single action on the live app and immediately returns the new screen state.

```
AI calls: scry_act(action: "tap", label: "Sign Out")

Scry:
  1. Builds a minimal Campaign with one step
  2. Sends it to the Relay
  3. Waits for the screen to settle (1000ms for navigation transitions)
  4. Observes the new screen
  5. Returns formatted Markdown with the result + new Gaze
```

The AI never has to call `scry` after `scry_act` — the observation is automatic.

### Single Action

```json
{
  "action": "tap",
  "label": "Sign Out"
}
```

### Text Entry

For text fields, `scry_act` handles the complexity automatically:

```json
{
  "action": "enterText",
  "label": "Hero Name",
  "value": "Arcturus"
}
```

Behind the scenes, this generates a *three-step* campaign:

1. **waitForElement** — ensures "Hero Name" is present and the screen has settled
2. **enterText** — types "Arcturus" into the field (with `clearFirst: true`)
3. **dismissKeyboard** — closes the keyboard so it doesn't block observation

The AI doesn't need to know about these mechanics. It just says "type Arcturus into Hero Name" and Scry handles the rest.

### Multi-Action

For multi-step flows like filling a form and tapping submit, `scry_act` accepts an `actions` array:

```json
{
  "actions": [
    {"action": "enterText", "label": "Hero Name", "value": "Arcturus"},
    {"action": "tap", "label": "Enter the Questboard"}
  ]
}
```

This executes all actions in a single Campaign — no round-trips between the AI and the app. Each text action still gets its waitForElement/dismissKeyboard wrapping. The result shows all actions performed:

```markdown
# ✅ All Actions Succeeded

**Actions performed** (2):
1. `enterText` on "Hero Name" → "Arcturus"
2. `tap` on "Enter the Questboard"

---

# 🔮 Screen: /questboard
...
```

---

## Text Injection: Three Strategies

> *Finding the right controller in a running Flutter app is harder than it sounds.*

When `scry_act` processes an `enterText` action, the StratagemRunner must find the `TextEditingController` for the target field and set its text. This happens through three strategies, tried in order:

**Strategy 1: FocusManager Polling** — After tapping the field, poll `FocusManager.instance.primaryFocus` up to 5 times (100ms apart). When focus is established, walk up the element tree from the focused node looking for an `EditableText` widget, which always holds a controller.

**Strategy 2: Position-Based Lookup** — Walk the *entire* element tree from root. For each `EditableText` found, check if its RenderBox bounds contain the tap coordinates. This handles cases where touch events don't establish focus (common on macOS desktop with simulated touch events).

**Strategy 3: ShadeTextController Registry** — If exactly one ShadeTextController is registered in the Shade's controller map, use it directly. This is a last-resort shortcut for simple screens with a single text field.

If all three strategies fail, a `StateError` is thrown — no silent failures.

```
Tap field at (150, 200)
  ▼
Strategy 1: FocusManager → primaryFocus → walk ancestors → EditableText?
  ✓ Found → use controller
  ✗ Not found after 5 attempts →
  ▼
Strategy 2: Walk element tree → find EditableText at (150, 200)?
  ✓ Found → use controller
  ✗ Not found →
  ▼
Strategy 3: Shade registry has exactly 1 controller?
  ✓ Found → use controller
  ✗ Not found → throw StateError
```

---

## Current Values

> *The Scry doesn't just see elements. It sees what they contain.*

Text fields report their current value in the Gaze output. When the TableauCapture walks the widget tree, it reads `controller.text` from `TextField` and `TextFormField` widgets:

```markdown
## 📝 Text Fields (1)
- **Hero Name** (TextField, fieldId: hero_name_login, value: "Kael")
```

The AI can see that "Hero Name" currently contains "Kael" and decide whether to clear it or type something new. Checkboxes, switches, sliders, and radio buttons also report their current values:

```markdown
- **Dark Mode** (Switch, value: "on")
- **Accept Terms** (Checkbox, value: "true")
- **Volume** (Slider, value: "0.75")
```

---

## Gated Actions

> *Some buttons should not be pressed without asking first.*

Scry automatically flags destructive actions — buttons whose labels match patterns like "delete", "remove", "disconnect", "reset", or "destroy". These appear in the Gaze with a warning:

```markdown
- **Delete Account** (TextButton) ⚠️ requires permission
```

The MCP tool description instructs the AI to ask the user for approval before acting on gated elements. The AI sees the warning, pauses, and asks: "I see a Delete Account button. Should I tap it?"

---

## The MCP Integration

> *Two tools. One loop. The AI sees and acts without leaving its context.*

The Blueprint MCP server exposes Scry through two tools:

| Tool | Purpose |
|------|---------|
| `scry` | Observe the current screen state |
| `scry_act` | Perform action(s) and observe the result |

The AI agent loop is:

```
1. Call scry → see what's on screen
2. Decide what to do based on the Gaze
3. Call scry_act(action, label, value) → perform action
4. The result includes the new screen state (no need for step 1 again)
5. Repeat from step 2
```

For multi-step flows, the AI can skip the loop entirely:

```
1. Call scry → see the login form
2. Call scry_act(actions: [...]) → fill form + tap submit
3. Result shows the post-login screen
```

---

## FieldId Resolution

> *Sometimes a field has an ID but no visible label. Scry bridges the gap.*

Text fields created with `useTextController(fieldId: 'hero_name_login')` have field IDs that are stable across app updates. The AI can target fields by `fieldId` instead of `label`:

```json
{
  "action": "enterText",
  "fieldId": "hero_name_login",
  "value": "Arcturus"
}
```

Scry resolves the fieldId to a display label by searching the current glyphs. If the field exists on screen, its label is used for targeting. If not found, a clear error message is returned.

---

Fen leaned back in her chair. On her screen, the Copilot had been watching the Questboard app through Scry for the last ten minutes — observing screens, typing into fields, navigating between tabs, all without a single pre-written Campaign.

"It's not following a script anymore," she said quietly. "It's *exploring*."

Kael nodded. "That's the difference between a Campaign and a Scry. A Campaign is a map someone drew before the journey. A Scry is a pair of eyes on the ground."

"And the multi-action?" Rhea asked.

"Efficiency. The AI doesn't need to make a round trip for every keystroke. It can say 'fill in the name, fill in the password, tap login' in one breath. But it still *sees* the result."

Rhea watched the Copilot's output scroll past. It had found a dead-end screen — a quest detail page with no back button on certain Android devices. The AI flagged it, wrote a bug report, and moved on to the next screen.

All on its own.

"The Campaigns were scrolls," Kael said. "The Scry is sight."

---

*Next: [Chapter LIX — ???](chapter-59-todo.md)*

---

**New in this chapter:**
- `Scry` — Real-time AI agent interface for live app observation and interaction
- `ScryGaze` — Structured observation result: buttons, fields, navigation, content, structural, gated
- `ScryElement` — Single screen element with kind, label, widgetType, currentValue, fieldId, gated flag
- `ScryElementKind` — Element categories: button, field, navigation, content, structural
- `Scry.observe(glyphs)` — Parse raw glyphs into a categorized Gaze with two-pass classification
- `Scry.formatGaze(gaze)` — Convert Gaze to AI-friendly Markdown with usage instructions
- `Scry.buildActionCampaign()` — Build a single-action Campaign with auto waitForElement/dismissKeyboard
- `Scry.buildMultiActionCampaign()` — Build a multi-action Campaign combining several steps
- `Scry.resolveFieldLabel()` — Resolve fieldId to display label from glyphs
- `Scry.formatActionResult()` — Format single-action result with pass/fail and new screen state
- `Scry.formatMultiActionResult()` — Format multi-action result with all actions listed
- `_injectText` — Three-strategy text injection: FocusManager polling, position-based lookup, ShadeTextController registry
- `_findControllerAtPosition()` — Walk element tree to find EditableText at coordinates
- `_applyTextValue()` — ShadeTextController-aware text setting with clearFirst support
- MCP tools: `scry` (observe), `scry_act` (single or multi-action)
- `isAuthScreen` — Automatic login/signup screen detection
- Gated actions — Auto-flagging destructive buttons with ⚠️ warning
- `currentValue` extraction for TextField, TextFormField, Checkbox, Switch, Slider, Radio
