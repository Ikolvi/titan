// ---------------------------------------------------------------------------
// Scry — Real-Time AI Agent Interface
// ---------------------------------------------------------------------------
// "To scry" — to see distant events through magical means.
//
// Scry gives any AI assistant (via MCP) the ability to observe the live
// app screen and perform actions in real-time, without pre-recorded
// stratagems or campaigns. The AI sees → decides → acts → observes the
// result, forming an autonomous agent loop.
// ---------------------------------------------------------------------------

/// The kind of screen element detected from a glyph.
///
/// Used by [ScryElement] to categorize glyphs into groups that
/// are meaningful for an AI agent deciding what to do next.
///
/// ```dart
/// switch (element.kind) {
///   case ScryElementKind.button:
///     print('Can tap: ${element.label}');
///   case ScryElementKind.field:
///     print('Can type in: ${element.label}');
///   case ScryElementKind.navigation:
///     print('Can navigate to: ${element.label}');
///   case ScryElementKind.content:
///     print('Displays: ${element.label}');
///   case ScryElementKind.structural:
///     print('UI chrome: ${element.label}');
/// }
/// ```
enum ScryElementKind {
  /// Tappable button (ElevatedButton, IconButton, TextButton, etc.).
  button,

  /// Text input field (TextField, TextFormField).
  field,

  /// Navigation element (tab, drawer item, nav destination).
  navigation,

  /// Display-only content (Text, RichText not part of UI chrome).
  content,

  /// Structural UI chrome (AppBar title, toolbar label, tooltip).
  structural,
}

/// A single screen element observed by Scry.
///
/// Distills a raw glyph map into an AI-friendly element with
/// a clear [kind], [label], and optional metadata for targeting.
///
/// ```dart
/// final element = ScryElement(
///   kind: ScryElementKind.button,
///   label: 'Sign Out',
///   widgetType: 'IconButton',
///   isInteractive: true,
/// );
/// ```
class ScryElement {
  /// Creates a [ScryElement].
  const ScryElement({
    required this.kind,
    required this.label,
    required this.widgetType,
    this.isInteractive = false,
    this.fieldId,
    this.currentValue,
    this.semanticRole,
    this.interactionType,
    this.isEnabled = true,
    this.gated = false,
  });

  /// The categorized kind of this element.
  final ScryElementKind kind;

  /// The display label (text content or tooltip).
  final String label;

  /// The Flutter widget type (e.g., `'IconButton'`, `'Text'`).
  final String widgetType;

  /// Whether this element accepts user interaction.
  final bool isInteractive;

  /// The field ID for text input targeting (from ShadeTextController).
  final String? fieldId;

  /// Current value for stateful widgets (checkboxes, switches, sliders).
  final String? currentValue;

  /// Semantic role (button, textField, header, image, link, etc.).
  final String? semanticRole;

  /// Interaction type (tap, longPress, textInput, scroll, etc.).
  final String? interactionType;

  /// Whether the element is enabled.
  final bool isEnabled;

  /// Whether this element is "gated" — the AI should ask the user
  /// for permission before interacting with it.
  ///
  /// Elements are gated if they appear to be destructive or
  /// irreversible actions (delete, remove, reset, etc.).
  final bool gated;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'label': label,
    'widgetType': widgetType,
    if (isInteractive) 'isInteractive': true,
    if (fieldId != null) 'fieldId': fieldId,
    if (currentValue != null) 'currentValue': currentValue,
    if (semanticRole != null) 'semanticRole': semanticRole,
    if (interactionType != null) 'interactionType': interactionType,
    if (!isEnabled) 'isEnabled': false,
    if (gated) 'gated': true,
  };
}

/// The result of a Scry observation — a structured view of the
/// current app screen, optimized for AI decision-making.
///
/// A [ScryGaze] categorizes all visible elements into groups:
///
/// - [buttons] — tappable controls the AI can tap
/// - [fields] — text inputs the AI can type into
/// - [navigation] — tabs, nav items the AI can switch to
/// - [content] — display-only text (potential user data)
/// - [structural] — UI chrome (app title, toolbar labels)
///
/// ```dart
/// const scry = Scry();
/// final gaze = scry.observe(glyphs);
///
/// print('Buttons: ${gaze.buttons.map((e) => e.label)}');
/// print('Fields: ${gaze.fields.map((e) => e.label)}');
/// print('You can navigate to: ${gaze.navigation.map((e) => e.label)}');
/// ```
class ScryGaze {
  /// Creates a [ScryGaze].
  const ScryGaze({
    required this.elements,
    this.route,
    this.glyphCount = 0,
  });

  /// All detected elements.
  final List<ScryElement> elements;

  /// Current route, if available.
  final String? route;

  /// Total number of raw glyphs analyzed.
  final int glyphCount;

  /// Interactive buttons (tappable, non-navigation).
  List<ScryElement> get buttons =>
      elements.where((e) => e.kind == ScryElementKind.button).toList();

  /// Text input fields.
  List<ScryElement> get fields =>
      elements.where((e) => e.kind == ScryElementKind.field).toList();

  /// Navigation elements (tabs, nav destinations).
  List<ScryElement> get navigation =>
      elements.where((e) => e.kind == ScryElementKind.navigation).toList();

  /// Display-only content labels.
  List<ScryElement> get content =>
      elements.where((e) => e.kind == ScryElementKind.content).toList();

  /// Structural UI chrome labels.
  List<ScryElement> get structural =>
      elements.where((e) => e.kind == ScryElementKind.structural).toList();

  /// Elements that require user permission before interacting.
  List<ScryElement> get gated =>
      elements.where((e) => e.gated).toList();

  /// Whether this looks like an authentication/login screen.
  bool get isAuthScreen =>
      fields.isNotEmpty &&
      buttons.any(
        (b) => _loginButtonPattern.hasMatch(b.label.toLowerCase()),
      );

  static final _loginButtonPattern = RegExp(
    r'\b(log\s*in|sign\s*in|enter|submit|continue)\b',
  );

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (route != null) 'route': route,
    'glyphCount': glyphCount,
    'buttonCount': buttons.length,
    'fieldCount': fields.length,
    'navigationCount': navigation.length,
    'contentCount': content.length,
    'elements': elements.map((e) => e.toJson()).toList(),
  };
}

/// **Scry** — real-time AI agent interface for observing and interacting
/// with a live Flutter app.
///
/// Scry parses raw glyph data (from Tableau/Relay) into a structured
/// [ScryGaze] that an AI assistant can reason about and act upon.
///
/// ## Core Loop
///
/// ```text
/// ┌─────────┐     ┌──────────┐     ┌─────────┐
/// │  Scry   │────▶│  Decide  │────▶│  Act    │
/// │ observe │     │ (AI)     │     │ scry_act│
/// └─────────┘     └──────────┘     └────┬────┘
///      ▲                                │
///      └────────────────────────────────┘
///              new screen state
/// ```
///
/// ## Usage
///
/// ```dart
/// const scry = Scry();
///
/// // Parse glyphs from Relay /blueprint
/// final gaze = scry.observe(glyphs, route: '/quests');
///
/// // Format for AI consumption
/// final markdown = scry.formatGaze(gaze);
/// print(markdown);
/// // # Current Screen
/// // **Route**: /quests | 177 glyphs
/// //
/// // ## 🔘 Buttons (3)
/// // - **Sign Out** (IconButton)
/// // - **About** (IconButton)
/// // - **Complete Quest** (IconButton, ×7)
/// // ...
/// ```
class Scry {
  /// Creates a const [Scry].
  const Scry();

  /// Labels that indicate destructive / irreversible actions.
  ///
  /// Elements matching these patterns are marked as [ScryElement.gated],
  /// signaling the AI to ask for user permission before interacting.
  static const gatedPatterns = [
    'delete',
    'remove',
    'reset',
    'destroy',
    'erase',
    'clear all',
    'wipe',
    'revoke',
    'unlink',
    'disconnect',
    'terminate',
    'purge',
  ];

  /// Observe the current screen by parsing raw glyph data.
  ///
  /// Categorizes each glyph into a [ScryElement] with a [ScryElementKind]
  /// based on:
  /// - Widget type and semantic role
  /// - Interactivity flag
  /// - Ancestor chain (structural detection)
  /// - Label content (gated action detection)
  ///
  /// [glyphs] — raw glyph maps from Relay `/blueprint`.
  /// [route] — current route (from Tableau metadata), if available.
  ///
  /// ```dart
  /// const scry = Scry();
  /// final gaze = scry.observe(glyphs, route: '/quests');
  /// print(gaze.buttons.length); // number of tappable buttons
  /// ```
  ScryGaze observe(List<dynamic> glyphs, {String? route}) {
    final seen = <String, ScryElement>{};
    final interactiveLabels = <String>{};
    final navigationLabels = <String>{};
    final structuralLabels = <String>{};
    final fieldIds = <String, String>{};

    // --- Pass 1: Classify labels ---
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (label.startsWith('IconData(')) continue;
      // Skip PUA icons
      if (label.length == 1 && label.codeUnitAt(0) > 0xE000) continue;

      final isInteractive = glyph['ia'] == true;
      final wt = glyph['wt'] as String? ?? '';
      final wtLower = wt.toLowerCase();
      final fieldId = glyph['fid'] as String?;
      final ancestors = glyph['anc'] as List<dynamic>? ?? [];

      // Track interactive labels
      if (isInteractive) {
        interactiveLabels.add(label);
      }

      // Track field IDs
      if (fieldId != null && fieldId.isNotEmpty) {
        fieldIds[label] = fieldId;
      }

      // Detect navigation elements
      if (_isNavigationWidget(wtLower, ancestors)) {
        navigationLabels.add(label);
      }

      // Detect structural elements (AppBar, toolbar, etc.)
      if (_isStructuralWidget(wtLower, ancestors)) {
        structuralLabels.add(label);
      }
    }

    // --- Pass 2: Build unique elements ---
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (label.startsWith('IconData(')) continue;
      if (label.length == 1 && label.codeUnitAt(0) > 0xE000) continue;

      // Skip if already processed (dedup by label)
      if (seen.containsKey(label)) continue;

      final wt = glyph['wt'] as String? ?? '';
      final sr = glyph['sr'] as String?;
      final it = glyph['it'] as String?;
      final cv = glyph['cv'] as String?;
      final isEnabled = glyph['en'] as bool? ?? true;
      final fieldId = fieldIds[label];

      // Determine element kind
      final kind = _classifyElement(
        label: label,
        widgetType: wt,
        semanticRole: sr,
        fieldId: fieldId,
        isInteractive: interactiveLabels.contains(label),
        isNavigation: navigationLabels.contains(label),
        isStructural: structuralLabels.contains(label),
      );

      // Check if this action is gated (destructive)
      final gated =
          interactiveLabels.contains(label) && _isGatedAction(label);

      seen[label] = ScryElement(
        kind: kind,
        label: label,
        widgetType: wt,
        isInteractive: interactiveLabels.contains(label),
        fieldId: fieldId,
        currentValue: cv,
        semanticRole: sr,
        interactionType: it,
        isEnabled: isEnabled,
        gated: gated,
      );
    }

    return ScryGaze(
      elements: seen.values.toList(),
      route: route,
      glyphCount: glyphs.length,
    );
  }

  /// Format a [ScryGaze] as AI-friendly markdown.
  ///
  /// Produces a structured document that tells the AI exactly:
  /// - What's visible on screen
  /// - What can be interacted with
  /// - What requires permission
  /// - What actions are available
  ///
  /// ```dart
  /// const scry = Scry();
  /// final gaze = scry.observe(glyphs, route: '/quests');
  /// final md = scry.formatGaze(gaze);
  /// // Returns markdown with sections for buttons, fields, nav, content
  /// ```
  String formatGaze(ScryGaze gaze) {
    final buf = StringBuffer();

    buf.writeln('# Current Screen');
    buf.writeln();

    // Header line
    final parts = <String>[];
    if (gaze.route != null) parts.add('**Route**: ${gaze.route}');
    parts.add('${gaze.glyphCount} glyphs');
    buf.writeln(parts.join(' | '));

    if (gaze.isAuthScreen) {
      buf.writeln();
      buf.writeln('> **Login screen detected** — '
          'this screen has text fields and a login button.');
    }

    // Gated elements warning
    if (gaze.gated.isNotEmpty) {
      buf.writeln();
      buf.writeln('> ⚠️ **Permission required** — '
          '${gaze.gated.length} element(s) marked as potentially '
          'destructive. Ask the user before interacting:');
      for (final e in gaze.gated) {
        buf.writeln('>   - "${e.label}"');
      }
    }

    buf.writeln();

    // --- Fields (most important for input) ---
    if (gaze.fields.isNotEmpty) {
      buf.writeln('## 📝 Text Fields (${gaze.fields.length})');
      buf.writeln();
      for (final f in gaze.fields) {
        final parts = <String>[f.widgetType];
        if (f.fieldId != null) parts.add('fieldId: ${f.fieldId}');
        if (f.currentValue != null) {
          parts.add('value: "${f.currentValue}"');
        }
        if (!f.isEnabled) parts.add('disabled');
        buf.writeln('- **${f.label}** (${parts.join(', ')})');
      }
      buf.writeln();
    }

    // --- Buttons ---
    if (gaze.buttons.isNotEmpty) {
      buf.writeln('## 🔘 Buttons (${gaze.buttons.length})');
      buf.writeln();
      for (final b in gaze.buttons) {
        final suffix = b.gated ? ' ⚠️ requires permission' : '';
        final disabled = !b.isEnabled ? ' [disabled]' : '';
        buf.writeln('- **${b.label}** (${b.widgetType})$disabled$suffix');
      }
      buf.writeln();
    }

    // --- Navigation ---
    if (gaze.navigation.isNotEmpty) {
      buf.writeln('## 🗂️ Navigation (${gaze.navigation.length})');
      buf.writeln();
      for (final n in gaze.navigation) {
        buf.writeln('- **${n.label}**');
      }
      buf.writeln();
    }

    // --- Content ---
    if (gaze.content.isNotEmpty) {
      buf.writeln('## 📄 Content (${gaze.content.length})');
      buf.writeln();
      for (final c in gaze.content) {
        buf.writeln('- ${c.label}');
      }
      buf.writeln();
    }

    // --- Available Actions ---
    buf.writeln('## Available Actions');
    buf.writeln();
    buf.writeln('Use `scry_act` with these action types:');
    buf.writeln();
    if (gaze.buttons.isNotEmpty) {
      buf.writeln('- `tap` — tap a button by label');
    }
    if (gaze.fields.isNotEmpty) {
      buf.writeln('- `enterText` — type text into a field '
          '(use fieldId for targeting)');
      buf.writeln('- `clearText` — clear a text field');
    }
    if (gaze.navigation.isNotEmpty) {
      buf.writeln('- `tap` — switch to a navigation tab by label');
    }
    buf.writeln('- `scroll` — scroll the page');
    buf.writeln('- `back` — navigate back');
    buf.writeln('- `waitForElement` — wait for an element to appear');

    return buf.toString();
  }

  /// Build a 1-step Campaign JSON from a single action request.
  ///
  /// Wraps the action in a minimal Campaign structure that the
  /// Relay's `POST /campaign` endpoint can execute.
  ///
  /// [action] — one of: tap, enterText, clearText, scroll, back,
  ///   longPress, doubleTap, swipe, waitForElement, waitForElementGone,
  ///   navigate, pressKey, etc.
  /// [label] — target element label (for tap, longPress, etc.)
  /// [fieldId] — target field ID (for enterText, clearText)
  /// [value] — text to enter (for enterText) or navigation route
  ///   (for navigate)
  /// [timeout] — timeout in ms for wait actions (default: 5000)
  ///
  /// ```dart
  /// const scry = Scry();
  /// final campaign = scry.buildActionCampaign(
  ///   action: 'tap',
  ///   label: 'Sign Out',
  /// );
  /// // Produces a Campaign JSON with a single tap step
  /// ```
  Map<String, dynamic> buildActionCampaign({
    required String action,
    String? label,
    String? fieldId,
    String? value,
    int timeout = 5000,
  }) {
    final target = <String, dynamic>{};
    if (label != null) target['label'] = label;
    if (fieldId != null) target['fieldId'] = fieldId;

    // If no explicit target, use a dummy for navigation actions
    if (target.isEmpty && action != 'back' && action != 'navigate') {
      target['label'] = label ?? '';
    }

    final step = <String, dynamic>{
      'id': 1,
      'action': action,
      if (target.isNotEmpty) 'target': target,
      // ignore: use_null_aware_elements
      if (value != null) 'value': value,
      if (action == 'waitForElement' || action == 'waitForElementGone')
        'timeout': timeout,
    };

    // For back/navigate, add route
    if (action == 'navigate' && value != null) {
      step['target'] = {'route': value};
    }

    return {
      'name': '_scry_action',
      'entries': [
        {
          'stratagem': {
            'name': '_scry_step',
            'startRoute': '/',
            'steps': [step],
          },
        },
      ],
    };
  }

  /// Format the result of a `scry_act` execution.
  ///
  /// [action] — the action that was performed.
  /// [label] — the target element label.
  /// [result] — the raw campaign result from Relay.
  /// [newGaze] — the observed screen state after the action.
  ///
  /// Returns markdown summarizing the action result and new state.
  String formatActionResult({
    required String action,
    String? label,
    String? value,
    required Map<String, dynamic>? result,
    required ScryGaze newGaze,
  }) {
    final buf = StringBuffer();

    // Action result
    final passRate = result?['passRate'] as num?;
    final succeeded = passRate != null && passRate == 1.0;

    if (succeeded) {
      buf.writeln('# ✅ Action Succeeded');
    } else {
      buf.writeln('# ❌ Action Failed');
    }
    buf.writeln();

    // Describe what was done
    final target = label ?? value ?? '(no target)';
    buf.writeln('**Action**: `$action` on "$target"');
    if (value != null && action == 'enterText') {
      buf.writeln('**Value**: "$value"');
    }
    if (passRate != null) {
      buf.writeln('**Pass Rate**: $passRate');
    }

    // If failed, include error details
    if (!succeeded && result != null) {
      final verdicts = result['verdicts'] as List<dynamic>? ?? [];
      for (final v in verdicts) {
        final verdict = v as Map<String, dynamic>;
        final steps = verdict['steps'] as List<dynamic>? ?? [];
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          if (step['passed'] != true) {
            final error = step['error'] as String?;
            if (error != null) {
              buf.writeln('**Error**: $error');
            }
          }
        }
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // New screen state
    buf.write(formatGaze(newGaze));

    return buf.toString();
  }

  // -----------------------------------------------------------------------
  // Private helpers
  // -----------------------------------------------------------------------

  /// Classify a label into a [ScryElementKind].
  ScryElementKind _classifyElement({
    required String label,
    required String widgetType,
    String? semanticRole,
    String? fieldId,
    required bool isInteractive,
    required bool isNavigation,
    required bool isStructural,
  }) {
    // Fields first (text inputs)
    if (semanticRole == 'textField' ||
        fieldId != null ||
        _isTextInputWidget(widgetType)) {
      return ScryElementKind.field;
    }

    // Navigation elements
    if (isNavigation) {
      return ScryElementKind.navigation;
    }

    // Structural (AppBar titles, tooltips in structural containers)
    if (isStructural && !isInteractive) {
      return ScryElementKind.structural;
    }

    // Interactive = buttons
    if (isInteractive) {
      return ScryElementKind.button;
    }

    // Everything else = content
    return ScryElementKind.content;
  }

  /// Check if widget type is a text input.
  bool _isTextInputWidget(String widgetType) {
    final lower = widgetType.toLowerCase();
    return lower.contains('textfield') ||
        lower.contains('textformfield') ||
        lower.contains('editabletext');
  }

  /// Check if this is a navigation widget (tab, nav destination).
  bool _isNavigationWidget(String wtLower, List<dynamic> ancestors) {
    if (wtLower == 'navigationbar' ||
        wtLower == 'bottomnavigationbar' ||
        wtLower == 'tabbar' ||
        wtLower == 'navigationrail') {
      return true;
    }

    if (ancestors.isNotEmpty) {
      final ancestorStr = ancestors.join(' ').toLowerCase();
      if (ancestorStr.contains('navigationbar') ||
          ancestorStr.contains('navigationdestination') ||
          ancestorStr.contains('bottomnavigationbar') ||
          ancestorStr.contains('tabbar') ||
          ancestorStr.contains('navigationrail')) {
        return true;
      }
    }

    return false;
  }

  /// Check if this is a structural UI element (AppBar, toolbar, etc.).
  bool _isStructuralWidget(String wtLower, List<dynamic> ancestors) {
    if (wtLower == 'appbar' ||
        wtLower == 'toolbar' ||
        wtLower == 'drawer' ||
        wtLower == 'bottomsheet') {
      return true;
    }

    if (ancestors.isNotEmpty) {
      final ancestorStr = ancestors.join(' ').toLowerCase();
      if (ancestorStr.contains('appbar') ||
          ancestorStr.contains('toolbar') ||
          ancestorStr.contains('drawer')) {
        return true;
      }
    }

    return false;
  }

  /// Check if a label indicates a destructive/gated action.
  bool _isGatedAction(String label) {
    final lower = label.toLowerCase();
    return gatedPatterns.any((p) => lower.contains(p));
  }
}
