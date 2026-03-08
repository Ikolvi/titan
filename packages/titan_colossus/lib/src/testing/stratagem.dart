import 'dart:ui' show Offset;

import '../recording/glyph.dart';
import '../recording/tableau.dart';

// ---------------------------------------------------------------------------
// Stratagem — AI-Generated Test Blueprint
// ---------------------------------------------------------------------------

/// **Stratagem** — an AI-generated test blueprint.
///
/// Contains ordered steps that Colossus executes autonomously
/// against the live app. Steps use Glyph-based targeting (labels,
/// types, semantic roles) instead of coordinates.
///
/// AI generates Stratagems from natural language instructions like
/// "test the login flow" using the [templateDescription] schema.
///
/// ## Why "Stratagem"?
///
/// A masterful battle plan — the AI's scheme for testing the app,
/// step by step, with precision targeting and clear expectations.
///
/// ## Usage
///
/// ```dart
/// // AI writes this JSON, Colossus parses and executes it:
/// final stratagem = Stratagem.fromJson(stratagemJson);
/// final verdict = await Colossus.instance.executeStratagem(stratagem);
/// print(verdict.toReport());
/// ```
///
/// ## Label-Based Targeting
///
/// Unlike [Phantom] (coordinate-based replay), Stratagem targets
/// elements by **visible label** and **widget type**. This makes
/// tests:
/// - **Layout-resilient**: works if a button moves on screen
/// - **Device-independent**: works on any screen size
/// - **AI-writable**: AI knows labels, not coordinates
/// - **Human-readable**: each step reads like a story
///
/// ```json
/// {
///   "action": "tap",
///   "target": {"label": "Login", "type": "ElevatedButton"}
/// }
/// ```
class Stratagem {
  /// Unique name for this test plan.
  final String name;

  /// Human-readable description.
  final String description;

  /// Tags for categorization (e.g., `['auth', 'critical-path']`).
  final List<String> tags;

  /// Starting route — Colossus navigates here first.
  final String startRoute;

  /// Preconditions (informational + optional setup).
  ///
  /// Example: `{'authenticated': false, 'notes': 'User must be logged out'}`
  final Map<String, dynamic>? preconditions;

  /// Test data available to steps via `${testData.key}` references.
  ///
  /// Example: `{'email': 'test@example.com', 'password': 'Secret123!'}`
  final Map<String, dynamic>? testData;

  /// Ordered list of steps to execute.
  final List<StratagemStep> steps;

  /// Maximum total execution time.
  final Duration timeout;

  /// How to handle step failures.
  final StratagemFailurePolicy failurePolicy;

  /// Creates a [Stratagem] from its components.
  const Stratagem({
    required this.name,
    this.description = '',
    this.tags = const [],
    required this.startRoute,
    this.preconditions,
    this.testData,
    required this.steps,
    this.timeout = const Duration(seconds: 30),
    this.failurePolicy = StratagemFailurePolicy.abortOnFirst,
  });

  // -----------------------------------------------------------------------
  // TestData interpolation
  // -----------------------------------------------------------------------

  /// Interpolate `${testData.key}` references in a string value.
  ///
  /// Replaces occurrences of `${testData.someKey}` with the
  /// corresponding value from [testData]. Returns the original
  /// string if no test data is available or if the key is not found.
  ///
  /// ```dart
  /// final resolved = stratagem.interpolate(r'${testData.email}');
  /// // → "test@example.com"
  /// ```
  String interpolate(String value) {
    if (testData == null || testData!.isEmpty) return value;

    return value.replaceAllMapped(RegExp(r'\$\{testData\.(\w+)\}'), (match) {
      final key = match.group(1)!;
      return testData!.containsKey(key)
          ? testData![key].toString()
          : match.group(0)!;
    });
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map (compatible with AI output).
  Map<String, dynamic> toJson() => {
    r'$schema': 'titan://stratagem/v1',
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (tags.isNotEmpty) 'tags': tags,
    'startRoute': startRoute,
    if (preconditions != null) 'preconditions': preconditions,
    if (testData != null) 'testData': testData,
    'timeout': timeout.inMilliseconds,
    'failurePolicy': failurePolicy.name,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  /// Parse from JSON map (written by AI or loaded from file).
  ///
  /// Throws [FormatException] with a descriptive message if
  /// required fields are missing or have wrong types.
  factory Stratagem.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    if (json['name'] == null) {
      throw const FormatException(
        'Stratagem JSON missing required field "name" (String).',
      );
    }
    if (json['name'] is! String) {
      throw FormatException(
        'Stratagem "name" must be a String, '
        'got ${json['name'].runtimeType}.',
      );
    }
    if (json['startRoute'] == null) {
      throw FormatException(
        'Stratagem "${json['name']}" missing required field '
        '"startRoute" (String). Use "/" for the default route.',
      );
    }
    if (json['startRoute'] is! String) {
      throw FormatException(
        'Stratagem "${json['name']}" field "startRoute" must be '
        'a String, got ${json['startRoute'].runtimeType}.',
      );
    }

    return Stratagem(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      startRoute: json['startRoute'] as String,
      preconditions: json['preconditions'] as Map<String, dynamic>?,
      testData: json['testData'] as Map<String, dynamic>?,
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 30000),
      failurePolicy: _failurePolicyFromName(
        json['failurePolicy'] as String? ?? 'abortOnFirst',
      ),
      steps: (json['steps'] as List? ?? [])
          .map((e) => StratagemStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // -----------------------------------------------------------------------
  // Template — AI reads this to know how to write Stratagems
  // -----------------------------------------------------------------------

  /// Natural-language schema description for AI prompts.
  ///
  /// Send this to an AI agent so it knows the exact format for
  /// writing Stratagem JSON.
  static String get templateDescription => '''
Write a Stratagem JSON following this structure:

REQUIRED FIELDS:
- name: short identifier (e.g., "login_happy_path")
- startRoute: initial page route (e.g., "/login")
- steps: ordered list of actions

OPTIONAL FIELDS:
- description: what this test verifies
- tags: array of category strings
- testData: key-value object for variable interpolation
- timeout: total timeout in milliseconds (default: 30000)
- failurePolicy: "abortOnFirst" | "continueAll" | "skipDependents"

STEP STRUCTURE:
Each step has:
- id: sequential integer
- action: one of the action types below
- description: human-readable step description
- target: element to interact with (see TARGET)
- value: text to enter or select (for enterText, selectDropdown, etc.)
- expectations: expected state after action (see EXPECTATIONS)
- waitAfter: milliseconds to wait after action
- timeout: step-level timeout override

ACTIONS:
- "tap": tap an element
- "doubleTap": double-tap an element
- "longPress": long-press an element (~500ms)
- "enterText": enter text into a TextField (supports clearFirst)
- "clearText": clear a text field
- "submitField": submit via keyboard action
- "scroll": scroll by delta {dx, dy}
- "scrollUntilVisible": repeatedly scroll to find element
- "swipe": swipe from element in direction
- "drag": drag from point A to B
- "toggleSwitch": tap a Switch
- "toggleCheckbox": tap a Checkbox
- "selectRadio": tap a Radio button
- "adjustSlider": drag slider to target value
- "selectDropdown": open dropdown and tap item
- "selectDate": select from DatePicker
- "selectSegment": tap a SegmentedButton
- "navigate": programmatic navigation
- "back": navigate back (pop)
- "wait": wait a fixed duration
- "waitForElement": wait until element appears
- "waitForElementGone": wait until element disappears
- "verify": validate expectations without action
- "dismissKeyboard": dismiss soft keyboard
- "pressKey": press a physical key

TARGET:
Target elements by visible properties (NOT coordinates):
- label: the visible text on the element
- type: Flutter widget type (e.g., "ElevatedButton", "TextField")
- key: developer-assigned widget key
- semanticRole: accessibility role
- index: 0-based index when multiple matches exist
- ancestor: must be descendant of this widget type

Use \${testData.key} syntax to reference test data values.

EXPECTATIONS:
- route: expected route after action
- elementsPresent: array of targets that must be visible
- elementsAbsent: array of targets that must NOT be visible
- elementStates: array of {label, type, enabled, value, visible}
- settleTimeout: milliseconds to wait for expectations
''';

  /// Structured JSON schema template for AI consumption.
  ///
  /// Provides a machine-readable schema that AI agents can
  /// parse to understand the exact format.
  static Map<String, dynamic> get template => {
    r'$schema': 'titan://stratagem/v1',
    'name': '<string: unique test name>',
    'description': '<string: what this test verifies>',
    'tags': ['<string: category tags>'],
    'startRoute': '<string: starting route path>',
    'preconditions': {
      'authenticated': '<bool>',
      'notes': '<string: setup instructions>',
    },
    'testData': {'<key>': '<value>'},
    'timeout': '<int: total timeout ms>',
    'failurePolicy': 'abortOnFirst | continueAll | skipDependents',
    'steps': [
      {
        'id': '<int: sequential>',
        'action': '<StratagemAction>',
        'description': '<string>',
        'target': {
          'label': '<string>',
          'type': '<string: widget type>',
          'key': '<string: widget key>',
          'semanticRole': '<string>',
          'index': '<int: 0-based>',
          'ancestor': '<string: ancestor widget type>',
        },
        'value': r'<string or ${testData.key}>',
        'clearFirst': '<bool>',
        'expectations': {
          'route': '<string>',
          'elementsPresent': [
            {'label': '<string>', 'type': '<string>'},
          ],
          'elementsAbsent': [
            {'label': '<string>', 'type': '<string>'},
          ],
          'elementStates': [
            {
              'label': '<string>',
              'type': '<string>',
              'enabled': '<bool>',
              'value': '<string>',
              'visible': '<bool>',
            },
          ],
        },
        'waitAfter': '<int: ms>',
        'timeout': '<int: ms>',
        'scrollDelta': {'dx': '<double>', 'dy': '<double>'},
        'repeatCount': '<int: max scroll attempts>',
        'swipeDirection': 'left | right | up | down',
        'swipeDistance': '<double: pixels>',
        'navigateRoute': '<string: route path>',
        'keyId': '<string: physical key name>',
        'sliderRange': {'min': '<double>', 'max': '<double>'},
      },
    ],
  };

  @override
  String toString() =>
      'Stratagem($name, ${steps.length} steps, '
      'start: $startRoute)';

  static StratagemFailurePolicy _failurePolicyFromName(String name) {
    return switch (name) {
      'continueAll' => StratagemFailurePolicy.continueAll,
      'skipDependents' => StratagemFailurePolicy.skipDependents,
      _ => StratagemFailurePolicy.abortOnFirst,
    };
  }
}

// ---------------------------------------------------------------------------
// StratagemStep — A single step in a Stratagem
// ---------------------------------------------------------------------------

/// A single step in a [Stratagem].
///
/// Each step describes an action to perform, a target element to
/// interact with, and optionally what to expect after the action.
///
/// ```json
/// {
///   "id": 2,
///   "action": "enterText",
///   "description": "Enter email address",
///   "target": {"label": "Email", "type": "TextField"},
///   "value": "${testData.email}",
///   "clearFirst": true
/// }
/// ```
class StratagemStep {
  /// Sequential step identifier.
  final int id;

  /// The action to perform.
  final StratagemAction action;

  /// Human-readable description of this step.
  final String description;

  /// The UI element to interact with (null for verify/wait/back).
  final StratagemTarget? target;

  // --- Text Input ---

  /// Text to enter, dropdown item label, slider value, date value.
  ///
  /// Supports `${testData.key}` interpolation.
  final String? value;

  /// Whether to clear the field before entering text.
  final bool? clearFirst;

  // --- Expectations ---

  /// Expected state after this step executes.
  final StratagemExpectations? expectations;

  /// Wait duration after action (before validation).
  final Duration? waitAfter;

  // --- Scroll ---

  /// Scroll direction and distance in pixels.
  final Offset? scrollDelta;

  /// Maximum scroll attempts for `scrollUntilVisible`.
  final int? repeatCount;

  // --- Swipe / Drag ---

  /// Swipe direction: `'left'`, `'right'`, `'up'`, `'down'`.
  final String? swipeDirection;

  /// Swipe distance in pixels.
  final double? swipeDistance;

  /// Drag start point (for `drag` action).
  final Offset? dragFrom;

  /// Drag end point (for `drag` action).
  final Offset? dragTo;

  // --- Navigation ---

  /// Route path for `navigate` action.
  final String? navigateRoute;

  // --- Slider ---

  /// Slider range: `{'min': 0, 'max': 100}`.
  final Map<String, double>? sliderRange;

  // --- Key ---

  /// Physical key name for `pressKey` action.
  final String? keyId;

  // --- Timeout ---

  /// Step-level timeout override.
  final Duration? timeout;

  /// Creates a [StratagemStep].
  const StratagemStep({
    required this.id,
    required this.action,
    this.description = '',
    this.target,
    this.value,
    this.clearFirst,
    this.expectations,
    this.waitAfter,
    this.scrollDelta,
    this.repeatCount,
    this.swipeDirection,
    this.swipeDistance,
    this.dragFrom,
    this.dragTo,
    this.navigateRoute,
    this.sliderRange,
    this.keyId,
    this.timeout,
  });

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action.name,
    if (description.isNotEmpty) 'description': description,
    if (target != null) 'target': target!.toJson(),
    if (value != null) 'value': value,
    if (clearFirst != null) 'clearFirst': clearFirst,
    if (expectations != null) 'expectations': expectations!.toJson(),
    if (waitAfter != null) 'waitAfter': waitAfter!.inMilliseconds,
    if (scrollDelta != null)
      'scrollDelta': {'dx': scrollDelta!.dx, 'dy': scrollDelta!.dy},
    if (repeatCount != null) 'repeatCount': repeatCount,
    if (swipeDirection != null) 'swipeDirection': swipeDirection,
    if (swipeDistance != null) 'swipeDistance': swipeDistance,
    if (dragFrom != null) 'dragFrom': {'x': dragFrom!.dx, 'y': dragFrom!.dy},
    if (dragTo != null) 'dragTo': {'x': dragTo!.dx, 'y': dragTo!.dy},
    if (navigateRoute != null) 'navigateRoute': navigateRoute,
    if (sliderRange != null) 'sliderRange': sliderRange,
    if (keyId != null) 'keyId': keyId,
    if (timeout != null) 'timeout': timeout!.inMilliseconds,
  };

  /// Parse from JSON map.
  ///
  /// Throws [FormatException] with a descriptive message if
  /// required fields are missing or have wrong types.
  factory StratagemStep.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    if (json['id'] == null) {
      throw const FormatException(
        'StratagemStep JSON missing required field "id" (int).',
      );
    }
    if (json['id'] is! int) {
      throw FormatException(
        'StratagemStep "id" must be an int, '
        'got ${json['id'].runtimeType} (${json['id']}). '
        'Use sequential integers: 1, 2, 3, …',
      );
    }
    if (json['action'] == null) {
      throw FormatException(
        'StratagemStep #${json['id']} missing required field '
        '"action" (String). Valid actions: '
        '${StratagemAction.values.map((a) => a.name).join(', ')}.',
      );
    }
    if (json['action'] is! String) {
      throw FormatException(
        'StratagemStep #${json['id']} field "action" must be a '
        'String, got ${json['action'].runtimeType}.',
      );
    }

    return StratagemStep(
      id: json['id'] as int,
      action: _actionFromName(json['action'] as String),
      description: json['description'] as String? ?? '',
      target: json['target'] != null
          ? StratagemTarget.fromJson(json['target'] as Map<String, dynamic>)
          : null,
      value: json['value'] as String?,
      clearFirst: json['clearFirst'] as bool?,
      expectations: json['expectations'] != null
          ? StratagemExpectations.fromJson(
              json['expectations'] as Map<String, dynamic>,
            )
          : null,
      waitAfter: json['waitAfter'] != null
          ? Duration(milliseconds: json['waitAfter'] as int)
          : null,
      scrollDelta: json['scrollDelta'] != null
          ? Offset(
              (json['scrollDelta']['dx'] as num).toDouble(),
              (json['scrollDelta']['dy'] as num).toDouble(),
            )
          : null,
      repeatCount: json['repeatCount'] as int?,
      swipeDirection: json['swipeDirection'] as String?,
      swipeDistance: (json['swipeDistance'] as num?)?.toDouble(),
      dragFrom: json['dragFrom'] != null
          ? Offset(
              (json['dragFrom']['x'] as num).toDouble(),
              (json['dragFrom']['y'] as num).toDouble(),
            )
          : null,
      dragTo: json['dragTo'] != null
          ? Offset(
              (json['dragTo']['x'] as num).toDouble(),
              (json['dragTo']['y'] as num).toDouble(),
            )
          : null,
      navigateRoute: json['navigateRoute'] as String?,
      sliderRange: (json['sliderRange'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      keyId: json['keyId'] as String?,
      timeout: json['timeout'] != null
          ? Duration(milliseconds: json['timeout'] as int)
          : null,
    );
  }

  @override
  String toString() => 'StratagemStep(#$id, ${action.name}, "$description")';

  static StratagemAction _actionFromName(String name) {
    for (final action in StratagemAction.values) {
      if (action.name == name) return action;
    }
    throw FormatException(
      'Unknown StratagemAction: "$name". '
      'Valid actions: ${StratagemAction.values.map((a) => a.name).join(", ")}',
    );
  }
}

// ---------------------------------------------------------------------------
// StratagemTarget — How to find a UI element by Glyph properties
// ---------------------------------------------------------------------------

/// How to identify a UI element by its [Glyph] properties.
///
/// Targets use **labels and types** — not coordinates — making
/// tests resilient to layout changes and device differences.
///
/// ```json
/// {"label": "Login", "type": "ElevatedButton"}
/// ```
///
/// ## Disambiguation
///
/// When multiple elements match, use:
/// - [index]: 0-based position among matches
/// - [key]: developer-assigned widget key
/// - [ancestor]: must be descendant of this widget type
class StratagemTarget {
  /// Match by visible label text.
  final String? label;

  /// Match by Flutter widget type (e.g., `'ElevatedButton'`).
  final String? type;

  /// Match by semantic accessibility role.
  final String? semanticRole;

  /// Match by developer-assigned widget key.
  final String? key;

  /// When multiple elements match, take the Nth (0-based).
  final int? index;

  /// Must be a descendant of this widget type.
  final String? ancestor;

  /// Creates a [StratagemTarget].
  const StratagemTarget({
    this.label,
    this.type,
    this.semanticRole,
    this.key,
    this.index,
    this.ancestor,
  });

  /// Resolve this target against a live [Tableau].
  ///
  /// Returns the matching [Glyph] or `null` if not found.
  /// Matches are filtered by all non-null properties.
  ///
  /// When [preferInteractive] is `true` (default) and no explicit [type]
  /// filter is set, interactive candidates are ranked ahead of
  /// non-interactive ones. This avoids the common pitfall where a
  /// label-only target (e.g. `{"label": "Hero"}`) resolves to a
  /// non-interactive `Text` widget instead of its interactive parent
  /// `GestureDetector`.
  ///
  /// ```dart
  /// final glyph = target.resolve(tableau);
  /// if (glyph != null) {
  ///   // dispatch tap at glyph.centerX, glyph.centerY
  /// }
  /// ```
  Glyph? resolve(Tableau tableau, {bool preferInteractive = true}) {
    final candidates = tableau.glyphs.where((g) {
      if (label != null && g.label != label) return false;
      if (type != null && !g.widgetType.contains(type!)) return false;
      if (semanticRole != null && g.semanticRole != semanticRole) {
        return false;
      }
      if (key != null && g.key != key) return false;
      if (ancestor != null && !g.ancestors.contains(ancestor!)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    // When no explicit type filter is set, rank interactive candidates
    // first so label-only targets naturally land on tappable widgets.
    if (preferInteractive && type == null && candidates.length > 1) {
      candidates.sort((a, b) {
        if (a.isInteractive && !b.isInteractive) return -1;
        if (!a.isInteractive && b.isInteractive) return 1;
        return 0;
      });
    }

    final i = index ?? 0;
    if (i >= candidates.length) return null;
    return candidates[i];
  }

  /// Fuzzy resolve — tries exact match first, then partial label match.
  ///
  /// Used when the AI's label doesn't exactly match what's on screen
  /// (e.g., AI wrote "Login" but button says "Log In").
  ///
  /// Like [resolve], interactive candidates are preferred when no
  /// explicit [type] filter is set and [preferInteractive] is `true`.
  Glyph? fuzzyResolve(Tableau tableau, {bool preferInteractive = true}) {
    // Try exact match first
    final exact = resolve(tableau, preferInteractive: preferInteractive);
    if (exact != null) return exact;

    // Try partial label match (case-insensitive)
    if (label != null) {
      final partial = tableau.glyphs.where((g) {
        if (g.label == null) return false;
        final normalizedTarget = label!.toLowerCase();
        final normalizedLabel = g.label!.toLowerCase();
        // Check type if specified
        if (type != null && !g.widgetType.contains(type!)) return false;
        return normalizedLabel.contains(normalizedTarget) ||
            normalizedTarget.contains(normalizedLabel);
      }).toList();
      if (partial.isNotEmpty) {
        // Rank interactive candidates first when no type filter is set
        if (preferInteractive && type == null && partial.length > 1) {
          partial.sort((a, b) {
            if (a.isInteractive && !b.isInteractive) return -1;
            if (!a.isInteractive && b.isInteractive) return 1;
            return 0;
          });
        }
        final i = index ?? 0;
        if (i >= partial.length) return null;
        return partial[i];
      }
    }

    return null;
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    if (label != null) 'label': label,
    if (type != null) 'type': type,
    if (semanticRole != null) 'semanticRole': semanticRole,
    if (key != null) 'key': key,
    if (index != null) 'index': index,
    if (ancestor != null) 'ancestor': ancestor,
  };

  /// Parse from JSON map.
  factory StratagemTarget.fromJson(Map<String, dynamic> json) {
    return StratagemTarget(
      label: json['label'] as String?,
      type: json['type'] as String?,
      semanticRole: json['semanticRole'] as String?,
      key: json['key'] as String?,
      index: json['index'] as int?,
      ancestor: json['ancestor'] as String?,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (label != null) parts.add('label: "$label"');
    if (type != null) parts.add('type: $type');
    if (key != null) parts.add('key: $key');
    if (index != null) parts.add('index: $index');
    return 'StratagemTarget(${parts.join(', ')})';
  }
}

// ---------------------------------------------------------------------------
// StratagemExpectations — Expected state after a step
// ---------------------------------------------------------------------------

/// Expected state after a [StratagemStep] executes.
///
/// Used by the [StratagemRunner] to validate that each step
/// had the desired effect on the UI.
///
/// ```json
/// {
///   "route": "/dashboard",
///   "elementsPresent": [{"label": "Welcome"}],
///   "elementsAbsent": [{"label": "Login"}]
/// }
/// ```
class StratagemExpectations {
  /// Expected route path after the step.
  final String? route;

  /// Elements that must be present on screen.
  final List<StratagemTarget>? elementsPresent;

  /// Elements that must NOT be present on screen.
  final List<StratagemTarget>? elementsAbsent;

  /// Expected states of specific elements.
  final List<StratagemElementState>? elementStates;

  /// How long to wait for expectations to be met.
  final Duration? settleTimeout;

  /// Creates [StratagemExpectations].
  const StratagemExpectations({
    this.route,
    this.elementsPresent,
    this.elementsAbsent,
    this.elementStates,
    this.settleTimeout,
  });

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    if (route != null) 'route': route,
    if (elementsPresent != null)
      'elementsPresent': elementsPresent!.map((t) => t.toJson()).toList(),
    if (elementsAbsent != null)
      'elementsAbsent': elementsAbsent!.map((t) => t.toJson()).toList(),
    if (elementStates != null)
      'elementStates': elementStates!.map((s) => s.toJson()).toList(),
    if (settleTimeout != null) 'settleTimeout': settleTimeout!.inMilliseconds,
  };

  /// Parse from JSON map.
  factory StratagemExpectations.fromJson(Map<String, dynamic> json) {
    return StratagemExpectations(
      route: json['route'] as String?,
      elementsPresent: (json['elementsPresent'] as List?)
          ?.map((e) => StratagemTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
      elementsAbsent: (json['elementsAbsent'] as List?)
          ?.map((e) => StratagemTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
      elementStates: (json['elementStates'] as List?)
          ?.map(
            (e) => StratagemElementState.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      settleTimeout: json['settleTimeout'] != null
          ? Duration(milliseconds: json['settleTimeout'] as int)
          : null,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (route != null) parts.add('route: $route');
    if (elementsPresent != null) {
      parts.add('present: ${elementsPresent!.length}');
    }
    if (elementsAbsent != null) {
      parts.add('absent: ${elementsAbsent!.length}');
    }
    if (elementStates != null) {
      parts.add('states: ${elementStates!.length}');
    }
    return 'Expectations(${parts.join(', ')})';
  }
}

// ---------------------------------------------------------------------------
// StratagemElementState — Expected state of a specific element
// ---------------------------------------------------------------------------

/// Expected state of a specific element, validated after a step.
///
/// ```json
/// {"label": "Login", "type": "ElevatedButton", "enabled": true}
/// ```
class StratagemElementState {
  /// Label text of the target element.
  final String label;

  /// Widget type (optional, for disambiguation).
  final String? type;

  /// Expected enabled state.
  final bool? enabled;

  /// Expected current value.
  final String? value;

  /// Expected visibility.
  final bool? visible;

  /// Creates a [StratagemElementState].
  const StratagemElementState({
    required this.label,
    this.type,
    this.enabled,
    this.value,
    this.visible,
  });

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'label': label,
    if (type != null) 'type': type,
    if (enabled != null) 'enabled': enabled,
    if (value != null) 'value': value,
    if (visible != null) 'visible': visible,
  };

  /// Parse from JSON map.
  factory StratagemElementState.fromJson(Map<String, dynamic> json) {
    return StratagemElementState(
      label: json['label'] as String,
      type: json['type'] as String?,
      enabled: json['enabled'] as bool?,
      value: json['value'] as String?,
      visible: json['visible'] as bool?,
    );
  }

  @override
  String toString() =>
      'ElementState($label${type != null ? " : $type" : ""}'
      '${enabled != null ? ", enabled: $enabled" : ""}'
      '${value != null ? ", value: $value" : ""})';
}

// ---------------------------------------------------------------------------
// StratagemAction — Actions a Stratagem step can perform
// ---------------------------------------------------------------------------

/// Actions a [StratagemStep] can perform.
///
/// Every action [Phantom] can replay, Stratagem can command —
/// but by label instead of coordinates.
enum StratagemAction {
  // --- Core Interactions ---

  /// Tap an element (pointerDown → pointerUp at center).
  tap,

  /// Long-press an element (~500ms hold).
  longPress,

  /// Double-tap an element (two rapid taps).
  doubleTap,

  // --- Text Input ---

  /// Enter text into a TextField/TextFormField.
  enterText,

  /// Clear a text field completely.
  clearText,

  /// Submit the current text field (TextInputAction.done/next/go).
  submitField,

  // --- Scroll & Swipe ---

  /// Scroll by a delta (pixels). Uses PointerScrollEvent.
  scroll,

  /// Scroll until an element becomes visible.
  scrollUntilVisible,

  /// Swipe gesture — drag from element center in a direction.
  swipe,

  /// Drag from point A to point B.
  drag,

  // --- Toggle & Selection ---

  /// Toggle a Switch widget.
  toggleSwitch,

  /// Tap a Checkbox to toggle it.
  toggleCheckbox,

  /// Select a Radio button.
  selectRadio,

  /// Adjust a Slider to a specific value.
  adjustSlider,

  /// Select from a DropdownButton.
  selectDropdown,

  /// Select a date from DatePicker.
  selectDate,

  /// Select a SegmentedButton option.
  selectSegment,

  // --- Navigation ---

  /// Programmatic navigation (Atlas.go/push).
  navigate,

  /// Navigation back (pop).
  back,

  // --- Waiting ---

  /// Wait for a fixed duration.
  wait,

  /// Wait until an element appears on screen.
  waitForElement,

  /// Wait until an element disappears.
  waitForElementGone,

  // --- Verification ---

  /// Verify expectations without performing any action.
  verify,

  // --- Keyboard ---

  /// Dismiss the soft keyboard.
  dismissKeyboard,

  /// Type a physical key (for desktop/web).
  pressKey,
}

// ---------------------------------------------------------------------------
// StratagemFailurePolicy — How to handle failures
// ---------------------------------------------------------------------------

/// How to handle failures during [Stratagem] execution.
enum StratagemFailurePolicy {
  /// Stop execution on first failure.
  abortOnFirst,

  /// Continue executing remaining steps.
  continueAll,

  /// Continue but skip steps that depend on failed steps.
  skipDependents,
}
