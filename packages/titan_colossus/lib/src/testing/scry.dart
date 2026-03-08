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

// =========================================================================
// ScryScreenType — Screen classification for AI context
// =========================================================================

/// The detected type of the current screen.
///
/// Helps the AI understand what kind of screen it's looking at,
/// enabling smarter action selection without detailed screen analysis.
///
/// ```dart
/// final gaze = scry.observe(glyphs);
/// if (gaze.screenType == ScryScreenType.login) {
///   // Enter credentials and tap login
/// }
/// ```
enum ScryScreenType {
  /// Login / authentication screen (fields + login button).
  login,

  /// Form screen (multiple fields + submit button).
  form,

  /// List screen (many similar content items, repeating patterns).
  list,

  /// Detail screen (single item with labels + values, back button).
  detail,

  /// Settings screen (toggles, switches, dropdowns).
  settings,

  /// Empty state (very few content elements, no data).
  empty,

  /// Error screen (error messages visible).
  error,

  /// Dashboard (mixed content types, stats, navigation).
  dashboard,

  /// Cannot be classified into a specific type.
  unknown,
}

// =========================================================================
// ScryAlert — Detected warnings, errors, and status indicators
// =========================================================================

/// The severity of a detected screen alert.
///
/// Used by [ScryAlert] to indicate how critical the detected
/// condition is, helping the AI prioritize its response.
enum ScryAlertSeverity {
  /// Error condition (red text, error icon, failure message).
  error,

  /// Warning condition (yellow text, warning icon).
  warning,

  /// Informational notice (snackbar, toast, banner).
  info,

  /// Loading / in-progress state (spinner, progress bar).
  loading,
}

/// A detected alert condition on the screen.
///
/// Represents errors, warnings, loading indicators, and
/// informational messages that the AI should know about.
///
/// ```dart
/// for (final alert in gaze.alerts) {
///   if (alert.severity == ScryAlertSeverity.error) {
///     print('Error detected: ${alert.message}');
///   }
/// }
/// ```
class ScryAlert {
  /// Creates a [ScryAlert].
  const ScryAlert({
    required this.severity,
    required this.message,
    this.widgetType,
  });

  /// The severity level of this alert.
  final ScryAlertSeverity severity;

  /// Human-readable description of the alert (or the visible text).
  final String message;

  /// The widget type that triggered this detection.
  final String? widgetType;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'message': message,
    if (widgetType != null) 'widgetType': widgetType,
  };
}

// =========================================================================
// ScryKeyValue — Detected data pairs on screen
// =========================================================================

/// A key-value pair detected by proximity grouping.
///
/// When a content label appears near a data value (like "Class:" next
/// to "Scout"), Scry groups them into a [ScryKeyValue] for the AI
/// to understand structured data displays.
///
/// ```dart
/// for (final kv in gaze.dataFields) {
///   print('${kv.key}: ${kv.value}');
/// }
/// ```
class ScryKeyValue {
  /// Creates a [ScryKeyValue].
  const ScryKeyValue({required this.key, required this.value});

  /// The label / key text.
  final String key;

  /// The value text.
  final String value;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

// =========================================================================
// ScryDiff — State change detection between observations
// =========================================================================

/// The result of comparing two [ScryGaze] observations.
///
/// Used in the observe→act→observe loop to understand what
/// changed after an action was performed.
///
/// ```dart
/// final before = scry.observe(glyphsBefore);
/// // ... perform action ...
/// final after = scry.observe(glyphsAfter);
/// final diff = scry.diff(before, after);
///
/// if (diff.routeChanged) {
///   print('Navigated from ${diff.previousRoute} to ${diff.currentRoute}');
/// }
/// for (final e in diff.appeared) {
///   print('New: ${e.label}');
/// }
/// ```
class ScryDiff {
  /// Creates a [ScryDiff].
  const ScryDiff({
    required this.appeared,
    required this.disappeared,
    required this.changedValues,
    this.previousRoute,
    this.currentRoute,
    required this.previousScreenType,
    required this.currentScreenType,
  });

  /// Elements now visible that were not visible before.
  final List<ScryElement> appeared;

  /// Elements no longer visible that were visible before.
  final List<ScryElement> disappeared;

  /// Elements whose [ScryElement.currentValue] changed.
  ///
  /// Each entry maps the element label to `{'from': old, 'to': new}`.
  final Map<String, Map<String, String?>> changedValues;

  /// Route before the action.
  final String? previousRoute;

  /// Route after the action.
  final String? currentRoute;

  /// Screen type before the action.
  final ScryScreenType previousScreenType;

  /// Screen type after the action.
  final ScryScreenType currentScreenType;

  /// Whether the route changed.
  bool get routeChanged =>
      previousRoute != null &&
      currentRoute != null &&
      previousRoute != currentRoute;

  /// Whether the screen type changed.
  bool get screenTypeChanged => previousScreenType != currentScreenType;

  /// Whether anything changed at all.
  bool get hasChanges =>
      appeared.isNotEmpty ||
      disappeared.isNotEmpty ||
      changedValues.isNotEmpty ||
      routeChanged;

  /// Format as AI-readable markdown.
  String format() {
    final buf = StringBuffer();
    buf.writeln('## 🔄 What Changed');
    buf.writeln();

    if (!hasChanges) {
      buf.writeln('_No visible changes detected._');
      return buf.toString();
    }

    if (routeChanged) {
      buf.writeln('**Route**: `$previousRoute` → `$currentRoute`');
    }
    if (screenTypeChanged) {
      buf.writeln(
        '**Screen type**: ${previousScreenType.name}'
        ' → ${currentScreenType.name}',
      );
    }

    if (appeared.isNotEmpty) {
      buf.writeln();
      buf.writeln('### ➕ Appeared (${appeared.length})');
      for (final e in appeared) {
        final extra = <String>[];
        if (e.isInteractive) extra.add(e.kind.name);
        if (e.currentValue != null) extra.add('value: "${e.currentValue}"');
        final suffix = extra.isNotEmpty ? ' (${extra.join(', ')})' : '';
        buf.writeln('- **${e.label}**$suffix');
      }
    }

    if (disappeared.isNotEmpty) {
      buf.writeln();
      buf.writeln('### ➖ Disappeared (${disappeared.length})');
      for (final e in disappeared) {
        buf.writeln('- ~~${e.label}~~');
      }
    }

    if (changedValues.isNotEmpty) {
      buf.writeln();
      buf.writeln('### ✏️ Changed Values (${changedValues.length})');
      for (final entry in changedValues.entries) {
        final from = entry.value['from'] ?? '(empty)';
        final to = entry.value['to'] ?? '(empty)';
        buf.writeln('- **${entry.key}**: "$from" → "$to"');
      }
    }

    return buf.toString();
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (previousRoute != null) 'previousRoute': previousRoute,
    if (currentRoute != null) 'currentRoute': currentRoute,
    'routeChanged': routeChanged,
    'screenTypeChanged': screenTypeChanged,
    'previousScreenType': previousScreenType.name,
    'currentScreenType': currentScreenType.name,
    'appeared': appeared.map((e) => e.toJson()).toList(),
    'disappeared': disappeared.map((e) => e.toJson()).toList(),
    'changedValues': changedValues,
    'hasChanges': hasChanges,
  };
}

// =========================================================================
// ScryFormStatus — Form validation awareness
// =========================================================================

/// Describes the validation state of a form on screen.
///
/// Tracks which fields have values, which have validation errors,
/// and whether the form appears ready for submission.
///
/// ```dart
/// if (gaze.formStatus != null && gaze.formStatus!.isReady) {
///   // All fields filled, no errors — safe to submit
/// }
/// ```
class ScryFormStatus {
  /// Creates a [ScryFormStatus].
  const ScryFormStatus({
    required this.totalFields,
    required this.filledFields,
    required this.emptyFields,
    required this.validationErrors,
    required this.disabledFields,
  });

  /// Total number of text input fields.
  final int totalFields;

  /// Number of fields with a non-empty value.
  final int filledFields;

  /// Labels of fields with no value.
  final List<String> emptyFields;

  /// Detected validation error messages near fields.
  final List<ScryFieldError> validationErrors;

  /// Labels of disabled fields.
  final List<String> disabledFields;

  /// Whether all fields have values and no validation errors.
  bool get isReady =>
      emptyFields.isEmpty && validationErrors.isEmpty && totalFields > 0;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'totalFields': totalFields,
    'filledFields': filledFields,
    'emptyFields': emptyFields,
    'validationErrors': validationErrors.map((e) => e.toJson()).toList(),
    'disabledFields': disabledFields,
    'isReady': isReady,
  };
}

/// A validation error detected near a form field.
class ScryFieldError {
  /// Creates a [ScryFieldError].
  const ScryFieldError({required this.fieldLabel, required this.errorMessage});

  /// The label of the field with the validation error.
  final String fieldLabel;

  /// The error message text.
  final String errorMessage;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'fieldLabel': fieldLabel,
    'errorMessage': errorMessage,
  };
}

// =========================================================================
// ScryScreenRegion — Inferred spatial region of the screen
// =========================================================================

/// The inferred spatial region where an element is located.
///
/// Helps the AI understand the layout structure without
/// absolute pixel coordinates.
///
/// ```dart
/// final topElements = gaze.elements
///     .where((e) => e.region == ScryScreenRegion.topBar);
/// ```
enum ScryScreenRegion {
  /// Top bar area (AppBar, status bar, toolbar).
  topBar,

  /// Main scrollable content area.
  mainContent,

  /// Bottom navigation area (tabs, nav bar).
  bottomNav,

  /// Floating element (FAB, floating action button, overlay).
  floating,

  /// Cannot determine the region.
  unknown,
}

// =========================================================================
// ScryTargetStrategy — Recommended targeting approach
// =========================================================================

/// How an AI agent should target this element for interaction.
///
/// Higher-priority strategies are more resilient to i18n changes,
/// text updates, and dynamic content.
///
/// ```dart
/// if (element.targetStrategy == ScryTargetStrategy.key) {
///   // Use key for stable targeting
///   scryAct(action: 'tap', key: element.key!);
/// }
/// ```
enum ScryTargetStrategy {
  /// Target by developer-assigned widget Key — most stable.
  key,

  /// Target by field ID — stable for text fields.
  fieldId,

  /// Target by unique label — reliable when no duplicates.
  uniqueLabel,

  /// Target by label + occurrence index — least stable.
  indexedLabel,
}

// =========================================================================
// ScryFieldValueType — Expected input type for text fields
// =========================================================================

/// Inferred input type for a text field.
///
/// Helps the AI generate appropriate test data (e.g., a valid email
/// address instead of random text).
///
/// ```dart
/// switch (element.inputType) {
///   case ScryFieldValueType.email:
///     scryAct(action: 'enterText', label: element.label,
///         value: 'test@example.com');
///   case ScryFieldValueType.password:
///     scryAct(action: 'enterText', label: element.label,
///         value: 'P@ssw0rd123');
///   // ...
/// }
/// ```
enum ScryFieldValueType {
  /// Email address field.
  email,

  /// Password / secret field.
  password,

  /// Phone / telephone number field.
  phone,

  /// Numeric-only field.
  numeric,

  /// Date or date-time field.
  date,

  /// URL / web address field.
  url,

  /// Search query field.
  search,

  /// Free-form text (no specific type detected).
  freeText,
}

// =========================================================================
// ScryActionImpact — Predicted outcome of interacting with an element
// =========================================================================

/// Predicted outcome when the AI interacts with an element.
///
/// Helps the AI plan multi-step interactions by knowing in advance
/// what will likely happen when tapping a button or element.
///
/// ```dart
/// if (element.predictedImpact == ScryActionImpact.delete) {
///   // This is destructive — confirm with user first
/// }
/// ```
enum ScryActionImpact {
  /// Will navigate to another screen.
  navigate,

  /// Will submit a form or save data.
  submit,

  /// Will delete or remove something.
  delete,

  /// Will toggle a boolean state.
  toggle,

  /// Will expand or collapse a section.
  expand,

  /// Will dismiss a dialog or overlay.
  dismiss,

  /// Will open a modal, dialog, or picker.
  openModal,

  /// Impact cannot be predicted.
  unknown,
}

// =========================================================================
// ScryLayoutPattern — Dominant element arrangement
// =========================================================================

/// Detected layout pattern from spatial element positions.
///
/// Tells the AI whether it's looking at a scrollable list, a grid,
/// a single-detail view, etc.
///
/// ```dart
/// if (gaze.layoutPattern == ScryLayoutPattern.verticalList) {
///   // Scroll down to find more items
/// }
/// ```
enum ScryLayoutPattern {
  /// Elements stacked vertically (list-like).
  verticalList,

  /// Elements arranged in a regular grid.
  grid,

  /// Elements laid out horizontally in a row.
  horizontalRow,

  /// Single card or detail panel.
  singleCard,

  /// No clear pattern detected.
  freeform,
}

// =========================================================================
// ScryOverlayInfo — Structured overlay/modal description
// =========================================================================

/// Structured description of an active overlay (dialog, modal, picker).
///
/// When Scry detects elements behind overlays, this class describes
/// what the overlay itself is, so the AI can decide how to interact.
///
/// ```dart
/// if (gaze.overlay != null) {
///   print('Overlay: ${gaze.overlay!.type}');
///   print('Title: ${gaze.overlay!.title}');
///   print('Actions: ${gaze.overlay!.actions.map((a) => a.label)}');
/// }
/// ```
class ScryOverlayInfo {
  /// Creates a [ScryOverlayInfo].
  const ScryOverlayInfo({
    required this.type,
    this.title,
    this.actions = const [],
    this.canDismiss = false,
  });

  /// The overlay type (e.g., `'Dialog'`, `'BottomSheet'`, `'Snackbar'`).
  final String type;

  /// The overlay title (if a text element in the overlay is detected).
  final String? title;

  /// Interactive elements within the overlay.
  final List<ScryElement> actions;

  /// Whether the overlay can be dismissed (close/cancel button present).
  final bool canDismiss;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'type': type,
    if (title != null) 'title': title,
    if (actions.isNotEmpty) 'actions': actions.map((a) => a.label).toList(),
    'canDismiss': canDismiss,
  };
}

// =========================================================================
// ScryToggleSummary — Aggregate toggle/selection state
// =========================================================================

/// Summary of all toggle, checkbox, switch, and slider states on screen.
///
/// Gives the AI a quick snapshot of current selection states,
/// especially useful on settings/preferences screens.
///
/// ```dart
/// if (gaze.toggleSummary != null) {
///   for (final t in gaze.toggleSummary!.toggles) {
///     print('${t.label}: ${t.currentValue}');
///   }
/// }
/// ```
class ScryToggleSummary {
  /// Creates a [ScryToggleSummary].
  const ScryToggleSummary({required this.toggles});

  /// Individual toggle states.
  final List<ScryToggleState> toggles;

  /// Number of toggles currently "on" or "selected".
  int get activeCount => toggles.where((t) => t.isActive).length;

  /// Total number of toggles.
  int get totalCount => toggles.length;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'active': activeCount,
    'total': totalCount,
    'toggles': toggles.map((t) => t.toJson()).toList(),
  };
}

/// State of a single toggle/switch/checkbox element.
class ScryToggleState {
  /// Creates a [ScryToggleState].
  const ScryToggleState({
    required this.label,
    required this.widgetType,
    this.currentValue,
    this.isActive = false,
  });

  /// The toggle's visible label.
  final String label;

  /// Widget type (Switch, Checkbox, Radio, etc.).
  final String widgetType;

  /// Raw value string (e.g., 'true', 'false', 'on', 'off').
  final String? currentValue;

  /// Whether the toggle is in an "active" state.
  final bool isActive;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'label': label,
    'widgetType': widgetType,
    if (currentValue != null) 'value': currentValue,
    'isActive': isActive,
  };
}

// =========================================================================
// ScryScrollInfo — Viewport / scrollability analysis
// =========================================================================

/// Viewport and scroll analysis from element positions.
///
/// Helps the AI know whether more content exists offscreen
/// and whether scrolling is needed to reach certain elements.
///
/// ```dart
/// if (gaze.scrollInfo != null && gaze.scrollInfo!.canScrollDown) {
///   // There's more content below — scroll to see it
///   scryAct(action: 'scroll', value: 'down');
/// }
/// ```
class ScryScrollInfo {
  /// Creates a [ScryScrollInfo].
  const ScryScrollInfo({
    required this.viewportHeight,
    required this.contentMaxY,
    required this.visibleCount,
    required this.belowFoldCount,
  });

  /// Estimated viewport height in logical pixels.
  final double viewportHeight;

  /// The maximum Y + H of all elements (content extent).
  final double contentMaxY;

  /// Elements fully within the viewport.
  final int visibleCount;

  /// Elements partially or fully below the fold.
  final int belowFoldCount;

  /// Whether scrolling down would reveal more content.
  bool get canScrollDown => contentMaxY > viewportHeight;

  /// Estimated number of screens of content.
  double get contentScreens =>
      viewportHeight > 0 ? contentMaxY / viewportHeight : 1.0;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'viewportHeight': viewportHeight,
    'contentMaxY': contentMaxY,
    'visibleCount': visibleCount,
    'belowFoldCount': belowFoldCount,
    'canScrollDown': canScrollDown,
    'contentScreens': double.parse(contentScreens.toStringAsFixed(1)),
  };
}

// =========================================================================
// ScryElementGroup — Logical element clusters
// =========================================================================

/// A group of elements sharing a common ancestor container.
///
/// Instead of listing 35 flat elements, groups collapse related
/// items into logical clusters like "7 Cards with [title, subtitle,
/// Delete button]".
///
/// ```dart
/// for (final group in gaze.groups) {
///   print('${group.containerType}: ${group.elements.length} items');
/// }
/// ```
class ScryElementGroup {
  /// Creates a [ScryElementGroup].
  const ScryElementGroup({
    required this.containerType,
    required this.elements,
    this.containerLabel,
  });

  /// The ancestor container type (e.g., `'Card'`, `'ListTile'`).
  final String containerType;

  /// Optional container label (e.g., card title).
  final String? containerLabel;

  /// Elements within this group.
  final List<ScryElement> elements;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'containerType': containerType,
    if (containerLabel != null) 'containerLabel': containerLabel,
    'elementCount': elements.length,
    'elements': elements.map((e) => e.toJson()).toList(),
  };
}

// =========================================================================
// ScryLandmarks — Semantic page summary
// =========================================================================

/// Key semantic landmarks on the current screen.
///
/// Gives the AI a concise "page overview" before the detailed
/// element list: what page this is, what the main action is,
/// and how to navigate away.
///
/// ```dart
/// if (gaze.landmarks?.primaryAction != null) {
///   print('Main action: ${gaze.landmarks!.primaryAction!.label}');
/// }
/// ```
class ScryLandmarks {
  /// Creates [ScryLandmarks].
  const ScryLandmarks({
    this.pageTitle,
    this.primaryAction,
    this.backAvailable = false,
    this.searchAvailable = false,
  });

  /// The detected page title (from topBar structural elements).
  final String? pageTitle;

  /// The most prominent interactive action on screen.
  final ScryElement? primaryAction;

  /// Whether a back/close navigation action is available.
  final bool backAvailable;

  /// Whether a search field or search button is visible.
  final bool searchAvailable;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (pageTitle != null) 'pageTitle': pageTitle,
    if (primaryAction != null) 'primaryAction': primaryAction!.label,
    'backAvailable': backAvailable,
    'searchAvailable': searchAvailable,
  };
}

// =========================================================================
// ScryElementKind — Element classification
// =========================================================================

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
    this.x,
    this.y,
    this.w,
    this.h,
    this.depth,
    this.key,
    this.context,
    this.obscured = false,
    this.occurrenceIndex,
    this.totalOccurrences,
    this.region = ScryScreenRegion.unknown,
    this.targetScore = 0,
    this.targetStrategy = ScryTargetStrategy.uniqueLabel,
    this.reachable = true,
    this.prominence = 0.0,
    this.inputType,
    this.predictedImpact,
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

  /// The X position (left edge) in logical pixels.
  final double? x;

  /// The Y position (top edge) in logical pixels.
  final double? y;

  /// The width in logical pixels.
  final double? w;

  /// The height in logical pixels.
  final double? h;

  /// The element's tree depth (higher = deeper/on top).
  final int? depth;

  /// The developer-assigned widget Key (e.g., `ValueKey('hero_name')`).
  ///
  /// More stable than labels for targeting, since keys survive
  /// i18n changes and text updates.
  final String? key;

  /// The ancestor context (e.g., `'Dialog'`, `'Card'`, `'BottomSheet'`).
  ///
  /// Extracted from the ancestor chain to help the AI understand
  /// what container this element lives in.
  final String? context;

  /// Whether this element is visually obscured by a higher-depth overlay.
  ///
  /// When `true`, the AI should not try to interact with this element
  /// because a dialog, modal, or overlay is covering it.
  final bool obscured;

  /// The 0-based index of this element among identically-labeled siblings.
  ///
  /// When multiple elements share the same label (e.g., 7 "Delete"
  /// buttons in a list), this identifies which occurrence this is.
  /// `null` when the label is unique.
  final int? occurrenceIndex;

  /// The total number of elements sharing this label.
  ///
  /// `null` when the label is unique.
  final int? totalOccurrences;

  /// The inferred screen region where this element is located.
  final ScryScreenRegion region;

  /// Targeting reliability score (0–100).
  ///
  /// Higher scores mean more stable targeting:
  /// - 100: widget Key → survives i18n, text changes
  /// - 90: field ID → stable for text inputs
  /// - 70: unique label → reliable when no duplicates
  /// - 40: indexed label → fragile, depends on list order
  final int targetScore;

  /// Recommended targeting strategy for this element.
  final ScryTargetStrategy targetStrategy;

  /// Whether this element can actually be interacted with.
  ///
  /// `false` when the element is disabled, obscured by an overlay,
  /// or positioned offscreen (below the fold).
  final bool reachable;

  /// Visual prominence score (0.0–1.0).
  ///
  /// Based on bounding box area, screen region, and depth.
  /// Higher values indicate more visually prominent elements.
  final double prominence;

  /// Inferred input type for text fields.
  ///
  /// `null` for non-field elements. Helps the AI generate
  /// appropriate test data (valid email, phone number, etc.).
  final ScryFieldValueType? inputType;

  /// Predicted impact of interacting with this element.
  ///
  /// `null` for non-interactive elements. Helps the AI plan
  /// multi-step flows by knowing consequences before acting.
  final ScryActionImpact? predictedImpact;

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
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    if (w != null) 'w': w,
    if (h != null) 'h': h,
    if (depth != null) 'depth': depth,
    if (key != null) 'key': key,
    if (context != null) 'context': context,
    if (obscured) 'obscured': true,
    if (occurrenceIndex != null) 'occurrenceIndex': occurrenceIndex,
    if (totalOccurrences != null) 'totalOccurrences': totalOccurrences,
    if (region != ScryScreenRegion.unknown) 'region': region.name,
    if (isInteractive) 'targetScore': targetScore,
    if (isInteractive) 'targetStrategy': targetStrategy.name,
    if (!reachable) 'reachable': false,
    if (prominence > 0)
      'prominence': double.parse(prominence.toStringAsFixed(2)),
    if (inputType != null) 'inputType': inputType!.name,
    if (predictedImpact != null) 'predictedImpact': predictedImpact!.name,
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
    this.screenType = ScryScreenType.unknown,
    this.alerts = const [],
    this.dataFields = const [],
    this.suggestions = const [],
    this.formStatus,
    this.scrollInfo,
    this.groups = const [],
    this.landmarks,
    this.overlay,
    this.layoutPattern = ScryLayoutPattern.freeform,
    this.toggleSummary,
    this.tabOrder = const [],
  });

  /// All detected elements.
  final List<ScryElement> elements;

  /// Current route, if available.
  final String? route;

  /// Total number of raw glyphs analyzed.
  final int glyphCount;

  /// Detected screen type.
  final ScryScreenType screenType;

  /// Detected alerts (errors, warnings, loading indicators).
  final List<ScryAlert> alerts;

  /// Detected key-value data pairs on screen.
  final List<ScryKeyValue> dataFields;

  /// AI-generated action suggestions for the current screen.
  final List<String> suggestions;

  /// Form status (non-null when text fields are present).
  final ScryFormStatus? formStatus;

  /// Scroll / viewport analysis (non-null when spatial data is available).
  final ScryScrollInfo? scrollInfo;

  /// Logical element groups by ancestor container.
  final List<ScryElementGroup> groups;

  /// Key semantic landmarks on this page.
  final ScryLandmarks? landmarks;

  /// Active overlay/modal info (non-null when dialog/sheet detected).
  final ScryOverlayInfo? overlay;

  /// Detected layout pattern from spatial positions.
  final ScryLayoutPattern layoutPattern;

  /// Toggle/switch/checkbox state summary (non-null when toggles present).
  final ScryToggleSummary? toggleSummary;

  /// Text fields ordered by natural tab order (top-to-bottom, left-to-right).
  final List<String> tabOrder;

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
  List<ScryElement> get gated => elements.where((e) => e.gated).toList();

  /// Elements obscured by an overlay (dialog, modal, etc.).
  List<ScryElement> get obscured => elements.where((e) => e.obscured).toList();

  /// Elements that are actually reachable for interaction.
  List<ScryElement> get reachable =>
      elements.where((e) => e.isInteractive && e.reachable).toList();

  /// Whether this looks like an authentication/login screen.
  bool get isAuthScreen => screenType == ScryScreenType.login;

  static final _loginButtonPattern = RegExp(
    r'\b(log\s*in|sign\s*in|enter|submit|continue)\b',
  );

  /// Whether errors are present on screen.
  bool get hasErrors =>
      alerts.any((a) => a.severity == ScryAlertSeverity.error);

  /// Whether loading is in progress.
  bool get isLoading =>
      alerts.any((a) => a.severity == ScryAlertSeverity.loading);

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (route != null) 'route': route,
    'glyphCount': glyphCount,
    'screenType': screenType.name,
    'buttonCount': buttons.length,
    'fieldCount': fields.length,
    'navigationCount': navigation.length,
    'contentCount': content.length,
    if (obscured.isNotEmpty) 'obscuredCount': obscured.length,
    if (alerts.isNotEmpty) 'alerts': alerts.map((a) => a.toJson()).toList(),
    if (dataFields.isNotEmpty)
      'dataFields': dataFields.map((d) => d.toJson()).toList(),
    if (suggestions.isNotEmpty) 'suggestions': suggestions,
    if (formStatus != null) 'formStatus': formStatus!.toJson(),
    if (scrollInfo != null) 'scrollInfo': scrollInfo!.toJson(),
    if (groups.isNotEmpty) 'groups': groups.map((g) => g.toJson()).toList(),
    if (landmarks != null) 'landmarks': landmarks!.toJson(),
    if (overlay != null) 'overlay': overlay!.toJson(),
    if (layoutPattern != ScryLayoutPattern.freeform)
      'layoutPattern': layoutPattern.name,
    if (toggleSummary != null) 'toggleSummary': toggleSummary!.toJson(),
    if (tabOrder.isNotEmpty) 'tabOrder': tabOrder,
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
    final interactiveLabels = <String>{};
    final navigationLabels = <String>{};
    final structuralLabels = <String>{};
    final fieldIds = <String, String>{};
    final textInputLabels = <String>{};
    final preferredWidgetType = <String, String>{};
    final preferredInteractionType = <String, String>{};
    final preferredSemanticRole = <String, String>{};
    final preferredCurrentValue = <String, String>{};
    // Track interactive label counts for multiplicity.
    // Only interactive elements can be meaningfully repeated
    // (e.g. 7 "Delete" buttons in a list). Non-interactive duplicates
    // (like RichText + Tooltip for the same label) are alternate
    // representations and should be deduplicated.
    final interactiveLabelCounts = <String, int>{};

    // --- Early overlay detection from raw glyphs ---
    // Scan before label filtering since dialog widgets (AboutDialog,
    // AlertDialog) often have no text label and would be filtered out.
    String? rawOverlayType;
    int rawOverlayDepth = 0;
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final wt = glyph['wt'] as String? ?? '';
      if (_overlayTypes.contains(wt)) {
        rawOverlayType = wt;
        rawOverlayDepth = glyph['d'] as int? ?? 0;
        break;
      }
    }

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

      // Count interactive occurrences of each label
      if (isInteractive) {
        interactiveLabelCounts[label] =
            (interactiveLabelCounts[label] ?? 0) + 1;
      }

      // Track interactive labels
      if (isInteractive) {
        interactiveLabels.add(label);
      }

      // Track field IDs
      if (fieldId != null && fieldId.isNotEmpty) {
        fieldIds[label] = fieldId;
      }

      // Track text input widgets — these take classification priority
      if (_isTextInputWidget(wt)) {
        textInputLabels.add(label);
        preferredWidgetType[label] = wt;
        final it = glyph['it'] as String?;
        if (it != null) preferredInteractionType[label] = it;
        final sr = glyph['sr'] as String?;
        if (sr != null) preferredSemanticRole[label] = sr;
        final cv = glyph['cv'] as String?;
        if (cv != null) preferredCurrentValue[label] = cv;
      }

      // Track interactive widgets as preferred (if no text input yet)
      if (isInteractive && !preferredWidgetType.containsKey(label)) {
        preferredWidgetType[label] = wt;
        final it = glyph['it'] as String?;
        if (it != null) preferredInteractionType[label] = it;
        final sr = glyph['sr'] as String?;
        if (sr != null) preferredSemanticRole[label] = sr;
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

    // --- Pass 2: Build elements with spatial/key/depth data ---
    // For labels that appear only once interactively, dedup as before.
    // For labels with multiple interactive glyphs, create indexed entries.
    final elementList = <ScryElement>[];
    final seenUnique = <String>{};
    final labelOccurrence = <String, int>{};

    // Find max depth across all glyphs for overlay detection
    var maxDepth = 0;
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final d = glyph['d'] as int? ?? 0;
      if (d > maxDepth) maxDepth = d;
    }

    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (label.startsWith('IconData(')) continue;
      if (label.length == 1 && label.codeUnitAt(0) > 0xE000) continue;

      final isInteractive = glyph['ia'] == true;
      final totalInteractive = interactiveLabelCounts[label] ?? 0;
      final isRepeated = totalInteractive > 1;

      // Multiplicity: only keep multiple instances for interactive elements
      // with >1 interactive occurrence. Non-interactive duplicates dedup.
      if (isRepeated && isInteractive) {
        // Allow multiple interactive elements with indices
      } else {
        // Dedup: first occurrence wins
        if (seenUnique.contains(label)) continue;
        seenUnique.add(label);
      }

      // Track occurrence index for repeated interactive labels
      final occurrenceIdx = isRepeated && isInteractive
          ? (labelOccurrence[label] ?? 0)
          : null;
      if (isRepeated && isInteractive) {
        labelOccurrence[label] = (occurrenceIdx ?? 0) + 1;
      }

      // Use the preferred widget type from Pass 1.
      final wt = preferredWidgetType[label] ?? (glyph['wt'] as String? ?? '');
      final sr = preferredSemanticRole[label] ?? (glyph['sr'] as String?);
      final it = preferredInteractionType[label] ?? (glyph['it'] as String?);
      final cv = preferredCurrentValue[label] ?? (glyph['cv'] as String?);
      final isEnabled = glyph['en'] as bool? ?? true;
      final fieldId = fieldIds[label];
      final isTextField = textInputLabels.contains(label);

      // Spatial data
      final x = (glyph['x'] as num?)?.toDouble();
      final y = (glyph['y'] as num?)?.toDouble();
      final w = (glyph['w'] as num?)?.toDouble();
      final h = (glyph['h'] as num?)?.toDouble();
      final depth = glyph['d'] as int?;
      final key = glyph['k'] as String?;
      final ancestors = glyph['anc'] as List<dynamic>? ?? [];

      // Extract ancestor context
      final context = _extractAncestorContext(ancestors);

      // Determine element kind
      final kind = _classifyElement(
        label: label,
        widgetType: wt,
        semanticRole: sr,
        fieldId: fieldId,
        isInteractive: interactiveLabels.contains(label),
        isNavigation: navigationLabels.contains(label),
        isStructural: structuralLabels.contains(label),
        isTextField: isTextField,
      );

      // Check if this action is gated (destructive)
      final gated = interactiveLabels.contains(label) && _isGatedAction(label);

      // Infer screen region from Y position
      final region = _inferRegion(y: y, h: h, ancestors: ancestors);

      elementList.add(
        ScryElement(
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
          x: x,
          y: y,
          w: w,
          h: h,
          depth: depth,
          key: key,
          context: context,
          occurrenceIndex: isRepeated && isInteractive ? occurrenceIdx : null,
          totalOccurrences: isRepeated && isInteractive
              ? totalInteractive
              : null,
          region: region,
        ),
      );
    }

    // --- Pass 3: Overlap/occlusion detection ---
    _detectOverlaps(elementList, maxDepth);

    // --- Pass 4: Intelligence layer ---
    final alerts = _detectAlerts(glyphs);
    final dataFields = _extractKeyValuePairs(glyphs);
    final screenType = _classifyScreen(elementList, alerts, dataFields);
    final suggestions = _generateSuggestions(elementList, screenType, alerts);
    final formStatus = _analyzeFormStatus(elementList, glyphs);

    // --- Pass 5: Scoring & analysis ---
    _applyTargetScoring(elementList);
    _applyReachability(elementList);
    _applyProminence(elementList);
    _applyInputTypes(elementList);
    _applyActionImpacts(elementList);
    final scrollInfo = _analyzeScroll(elementList);
    final groups = _groupElements(elementList, glyphs);
    final landmarks = _detectLandmarks(elementList, screenType);
    final overlay = _analyzeOverlay(
      elementList,
      rawOverlayType: rawOverlayType,
      rawOverlayDepth: rawOverlayDepth,
    );
    final layoutPattern = _detectLayoutPattern(elementList);
    final toggleSummary = _buildToggleSummary(elementList);
    final tabOrder = _computeTabOrder(elementList);

    return ScryGaze(
      elements: elementList,
      route: route,
      glyphCount: glyphs.length,
      screenType: screenType,
      alerts: alerts,
      dataFields: dataFields,
      suggestions: suggestions,
      formStatus: formStatus,
      scrollInfo: scrollInfo,
      groups: groups,
      landmarks: landmarks,
      overlay: overlay,
      layoutPattern: layoutPattern,
      toggleSummary: toggleSummary,
      tabOrder: tabOrder,
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

    // Header line with screen type
    final parts = <String>[];
    if (gaze.route != null) parts.add('**Route**: ${gaze.route}');
    parts.add('**Type**: ${gaze.screenType.name}');
    if (gaze.layoutPattern != ScryLayoutPattern.freeform) {
      parts.add('**Layout**: ${gaze.layoutPattern.name}');
    }
    parts.add('${gaze.glyphCount} glyphs');
    buf.writeln(parts.join(' | '));

    // --- Landmarks (concise page summary) ---
    if (gaze.landmarks != null) {
      final lm = gaze.landmarks!;
      buf.writeln();
      final lmParts = <String>[];
      if (lm.pageTitle != null) lmParts.add('**Page**: ${lm.pageTitle}');
      if (lm.primaryAction != null) {
        lmParts.add('**Primary action**: ${lm.primaryAction!.label}');
      }
      if (lm.backAvailable) lmParts.add('← Back');
      if (lm.searchAvailable) lmParts.add('🔍 Search');
      if (lmParts.isNotEmpty) buf.writeln(lmParts.join(' | '));
    }

    // --- Scroll Info ---
    if (gaze.scrollInfo != null && gaze.scrollInfo!.canScrollDown) {
      buf.writeln();
      final si = gaze.scrollInfo!;
      buf.writeln(
        '> 📜 **Scrollable** — content extends to '
        '${si.contentMaxY.toStringAsFixed(0)}px '
        '(viewport: ${si.viewportHeight.toStringAsFixed(0)}px). '
        '${si.belowFoldCount} element(s) below fold. '
        'Scroll down for more.',
      );
    }

    // --- Overlay Info ---
    if (gaze.overlay != null) {
      buf.writeln();
      final ov = gaze.overlay!;
      final ovParts = <String>['**${ov.type}**'];
      if (ov.title != null) ovParts.add('"${ov.title}"');
      if (ov.actions.isNotEmpty) {
        final labels = ov.actions.map((a) => a.label).join(', ');
        ovParts.add('actions: $labels');
      }
      if (ov.canDismiss) ovParts.add('dismissible');
      buf.writeln('> 🪟 **Overlay active** — ${ovParts.join(' | ')}');
    }

    if (gaze.isAuthScreen) {
      buf.writeln();
      buf.writeln(
        '> **Login screen detected** — '
        'this screen has text fields and a login button.',
      );
    }

    // --- Alerts (errors, warnings, loading) ---
    if (gaze.alerts.isNotEmpty) {
      buf.writeln();
      for (final alert in gaze.alerts) {
        final icon = switch (alert.severity) {
          ScryAlertSeverity.error => '🔴',
          ScryAlertSeverity.warning => '🟡',
          ScryAlertSeverity.info => '🔵',
          ScryAlertSeverity.loading => '⏳',
        };
        buf.writeln('> $icon **${alert.severity.name}**: ${alert.message}');
      }
    }

    // Gated elements warning
    if (gaze.gated.isNotEmpty) {
      buf.writeln();
      buf.writeln(
        '> ⚠️ **Permission required** — '
        '${gaze.gated.length} element(s) marked as potentially '
        'destructive. Ask the user before interacting:',
      );
      for (final e in gaze.gated) {
        buf.writeln('>   - "${e.label}"');
      }
    }

    buf.writeln();

    // --- Suggestions (context-aware) ---
    if (gaze.suggestions.isNotEmpty) {
      buf.writeln('## 💡 Suggestions');
      buf.writeln();
      for (final s in gaze.suggestions) {
        buf.writeln('- $s');
      }
      buf.writeln();
    }

    // --- Data Fields (key-value pairs) ---
    if (gaze.dataFields.isNotEmpty) {
      buf.writeln('## 📊 Data (${gaze.dataFields.length})');
      buf.writeln();
      for (final kv in gaze.dataFields) {
        buf.writeln('- **${kv.key}**: ${kv.value}');
      }
      buf.writeln();
    }

    // --- Element Groups ---
    if (gaze.groups.isNotEmpty) {
      buf.writeln('## 🗂️ Groups (${gaze.groups.length})');
      buf.writeln();
      for (final group in gaze.groups) {
        final title = group.containerLabel != null
            ? '${group.containerType} "${group.containerLabel}"'
            : group.containerType;
        final labels = group.elements.map((e) => e.label).join(', ');
        buf.writeln('- **$title** (${group.elements.length}): $labels');
      }
      buf.writeln();
    }

    // --- Form Status ---
    if (gaze.formStatus != null) {
      final fs = gaze.formStatus!;
      buf.writeln('## 📋 Form Status');
      buf.writeln();
      buf.writeln('- **Fields**: ${fs.filledFields}/${fs.totalFields} filled');
      if (fs.emptyFields.isNotEmpty) {
        buf.writeln(
          '- **Empty**: ${fs.emptyFields.map((f) => '"$f"').join(', ')}',
        );
      }
      if (fs.disabledFields.isNotEmpty) {
        buf.writeln(
          '- **Disabled**: '
          '${fs.disabledFields.map((f) => '"$f"').join(', ')}',
        );
      }
      if (fs.validationErrors.isNotEmpty) {
        buf.writeln('- **Validation Errors**:');
        for (final ve in fs.validationErrors) {
          buf.writeln('  - "${ve.fieldLabel}": ${ve.errorMessage}');
        }
      }
      if (fs.isReady) {
        buf.writeln('- ✅ **Form is ready to submit**');
      }
      buf.writeln();
    }

    // --- Toggle Summary ---
    if (gaze.toggleSummary != null) {
      final ts = gaze.toggleSummary!;
      buf.writeln('## 🔀 Toggles (${ts.activeCount}/${ts.totalCount} active)');
      buf.writeln();
      for (final t in ts.toggles) {
        final state = t.isActive ? '✅ on' : '⬜ off';
        buf.writeln('- **${t.label}** (${t.widgetType}): $state');
      }
      buf.writeln();
    }

    // --- Fields (most important for input) ---
    if (gaze.fields.isNotEmpty) {
      buf.writeln('## 📝 Text Fields (${gaze.fields.length})');
      buf.writeln();
      buf.writeln(
        'Use `scry_act(action: "enterText", label: "<label>", '
        'value: "<text>")` to type into a field.',
      );
      buf.writeln();
      for (final f in gaze.fields) {
        final parts = <String>[f.widgetType];
        if (f.fieldId != null) parts.add('fieldId: ${f.fieldId}');
        if (f.key != null) parts.add('key: ${f.key}');
        if (f.inputType != null) parts.add('expects: ${f.inputType!.name}');
        if (f.currentValue != null) {
          parts.add('value: "${f.currentValue}"');
        }
        if (!f.isEnabled) parts.add('disabled');
        if (f.obscured) parts.add('⛔ obscured');
        if (f.context != null) parts.add('in ${f.context}');
        buf.writeln('- **${f.label}** (${parts.join(', ')})');
      }
      if (gaze.tabOrder.length > 1) {
        buf.writeln();
        buf.writeln('**Tab order**: ${gaze.tabOrder.join(' → ')}');
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
        final obscured = b.obscured ? ' ⛔ obscured' : '';
        final multi = b.totalOccurrences != null
            ? ' (×${b.totalOccurrences}, #${b.occurrenceIndex! + 1})'
            : '';
        final ctx = b.context != null ? ' [in ${b.context}]' : '';
        buf.writeln(
          '- **${b.label}** (${b.widgetType})'
          '$multi$ctx$disabled$obscured$suffix',
        );
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
        final ctx = c.context != null ? ' [in ${c.context}]' : '';
        buf.writeln('- ${c.label}$ctx');
      }
      buf.writeln();
    }

    // --- Obscured Elements ---
    if (gaze.obscured.isNotEmpty) {
      buf.writeln('## ⛔ Obscured (${gaze.obscured.length})');
      buf.writeln();
      buf.writeln(
        '_These elements are hidden behind an overlay '
        '(dialog, modal, bottom sheet). Do not interact with them._',
      );
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
      buf.writeln(
        '- `enterText` — type text into a field '
        '(use fieldId for targeting)',
      );
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

  /// Resolve a `fieldId` to its display label from live glyphs.
  ///
  /// When the AI targets a text field by `fieldId` (e.g.
  /// `scry_act(fieldId: 'hero_name')`), this method finds the
  /// matching glyph and returns its label for use in campaign
  /// targeting (since [StratagemTarget] resolves by label, not fieldId).
  ///
  /// Returns `null` if no glyph matches the given [fieldId].
  String? resolveFieldLabel(List<dynamic> glyphs, String fieldId) {
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      if (glyph['fid'] == fieldId) {
        return glyph['l'] as String?;
      }
    }
    return null;
  }

  /// Text-entry actions that require keyboard dismissal afterwards.
  static const _textActions = {'enterText', 'clearText', 'submitField'};

  /// Build a Campaign JSON from a single action request.
  ///
  /// Wraps the action in a minimal Campaign structure that the
  /// Relay's `POST /campaign` endpoint can execute. For text-entry
  /// actions (`enterText`, `clearText`, `submitField`), a
  /// `dismissKeyboard` step is automatically appended so the
  /// keyboard doesn't block the follow-up screen observation.
  ///
  /// [action] — one of: tap, enterText, clearText, scroll, back,
  ///   longPress, doubleTap, swipe, waitForElement, waitForElementGone,
  ///   navigate, pressKey, submitField, dismissKeyboard, etc.
  /// [label] — target element label (for tap, enterText, clearText, etc.)
  /// [value] — text to enter (for enterText) or navigation route
  ///   (for navigate)
  /// [key] — widget key for stable targeting (preferred over label)
  /// [timeout] — timeout in ms for wait actions (default: 5000)
  ///
  /// ```dart
  /// const scry = Scry();
  /// final campaign = scry.buildActionCampaign(
  ///   action: 'enterText',
  ///   label: 'Hero Name',
  ///   value: 'Kael',
  /// );
  /// // Produces a Campaign with enterText + dismissKeyboard steps
  /// ```
  Map<String, dynamic> buildActionCampaign({
    required String action,
    String? label,
    String? value,
    String? key,
    int timeout = 5000,
  }) {
    final target = <String, dynamic>{};
    if (key != null) {
      target['key'] = key;
    } else if (label != null) {
      target['label'] = label;
    }

    // If no explicit target, use a dummy for navigation actions
    if (target.isEmpty && action != 'back' && action != 'navigate') {
      target['label'] = label ?? '';
    }

    var stepId = 1;

    final steps = <Map<String, dynamic>>[];

    // For text-entry actions, add a waitForElement step first to ensure
    // the target field is present and the screen has settled. This
    // prevents silent failures when the screen is mid-transition
    // (e.g. IgnorePointer blocking events during route animation).
    if (_textActions.contains(action) && target.isNotEmpty) {
      steps.add({
        'id': stepId++,
        'action': 'waitForElement',
        'target': Map<String, dynamic>.from(target),
        'timeout': timeout,
      });
    }

    final step = <String, dynamic>{
      'id': stepId++,
      'action': action,
      if (target.isNotEmpty) 'target': target,
      // ignore: use_null_aware_elements
      if (value != null) 'value': value,
      if (action == 'enterText') 'clearFirst': true,
      if (action == 'waitForElement' || action == 'waitForElementGone')
        'timeout': timeout,
    };

    // For back/navigate, add route
    if (action == 'navigate' && value != null) {
      step['target'] = {'route': value};
    }

    steps.add(step);

    // Auto-dismiss keyboard after text actions so observation isn't blocked
    if (_textActions.contains(action)) {
      steps.add({'id': stepId, 'action': 'dismissKeyboard'});
    }

    return {
      'name': '_scry_action',
      'entries': [
        {
          'stratagem': {'name': '_scry_step', 'startRoute': '', 'steps': steps},
        },
      ],
    };
  }

  /// Build a Campaign JSON from multiple action requests.
  ///
  /// Combines several actions into a single Campaign structure.
  /// Each action in [actions] is a map with:
  /// - `action` (required) — the action type
  /// - `label` (optional) — target element label
  /// - `value` (optional) — text value or route
  /// - `key` (optional) — widget key for stable targeting
  ///
  /// Text-entry actions automatically get `waitForElement` pre-steps
  /// and `dismissKeyboard` post-steps, just like [buildActionCampaign].
  ///
  /// ```dart
  /// const scry = Scry();
  /// final campaign = scry.buildMultiActionCampaign([
  ///   {'action': 'enterText', 'label': 'Hero Name', 'value': 'Kael'},
  ///   {'action': 'tap', 'label': 'Enter the Questboard'},
  /// ]);
  /// ```
  Map<String, dynamic> buildMultiActionCampaign(
    List<Map<String, dynamic>> actions, {
    int timeout = 5000,
  }) {
    var stepId = 1;
    final steps = <Map<String, dynamic>>[];

    for (final entry in actions) {
      final action = entry['action'] as String;
      final label = entry['label'] as String?;
      final value = entry['value'] as String?;
      final key = entry['key'] as String?;

      final target = <String, dynamic>{};
      if (key != null) {
        target['key'] = key;
      } else if (label != null) {
        target['label'] = label;
      }

      if (target.isEmpty && action != 'back' && action != 'navigate') {
        target['label'] = label ?? '';
      }

      // Pre-step: waitForElement for text actions
      if (_textActions.contains(action) && target.isNotEmpty) {
        steps.add({
          'id': stepId++,
          'action': 'waitForElement',
          'target': Map<String, dynamic>.from(target),
          'timeout': timeout,
        });
      }

      final step = <String, dynamic>{
        'id': stepId++,
        'action': action,
        if (target.isNotEmpty) 'target': target,
        // ignore: use_null_aware_elements
        if (value != null) 'value': value,
        if (action == 'enterText') 'clearFirst': true,
        if (action == 'waitForElement' || action == 'waitForElementGone')
          'timeout': timeout,
      };

      if (action == 'navigate' && value != null) {
        step['target'] = {'route': value};
      }

      steps.add(step);

      // Post-step: dismissKeyboard for text actions
      if (_textActions.contains(action)) {
        steps.add({'id': stepId++, 'action': 'dismissKeyboard'});
      }
    }

    return {
      'name': '_scry_multi_action',
      'entries': [
        {
          'stratagem': {
            'name': '_scry_steps',
            'startRoute': '',
            'steps': steps,
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

  /// Format the result of a multi-action `scry_act` execution.
  ///
  /// Similar to [formatActionResult] but lists all actions performed.
  String formatMultiActionResult({
    required List<Map<String, dynamic>> actions,
    required Map<String, dynamic>? result,
    required ScryGaze newGaze,
  }) {
    final buf = StringBuffer();

    final passRate = result?['passRate'] as num?;
    final succeeded = passRate != null && passRate == 1.0;

    if (succeeded) {
      buf.writeln('# ✅ All Actions Succeeded');
    } else {
      buf.writeln('# ❌ Actions Failed');
    }
    buf.writeln();

    // List all actions
    buf.writeln('**Actions performed** (${actions.length}):');
    for (var i = 0; i < actions.length; i++) {
      final a = actions[i];
      final action = a['action'] as String;
      final label = a['label'] as String?;
      final value = a['value'] as String?;
      final target = label ?? value ?? '';
      final detail = value != null && action == 'enterText'
          ? ' → "$value"'
          : '';
      buf.writeln(
        '${i + 1}. `$action`'
        '${target.isNotEmpty ? ' on "$target"' : ''}'
        '$detail',
      );
    }
    buf.writeln();

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
              buf.writeln('**Error** (step ${step['id']}): $error');
            }
          }
        }
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    buf.write(formatGaze(newGaze));

    return buf.toString();
  }

  // -----------------------------------------------------------------------
  // Diff — State change detection
  // -----------------------------------------------------------------------

  /// Compare two [ScryGaze] observations to detect changes.
  ///
  /// Returns a [ScryDiff] describing what appeared, disappeared,
  /// or changed between the [before] and [after] observations.
  ///
  /// This is the key enabler for the observe→act→observe agent loop:
  /// the AI performs an action, then diffs the before/after states
  /// to verify the action had the expected effect.
  ///
  /// ```dart
  /// const scry = Scry();
  /// final before = scry.observe(glyphsBefore);
  /// // ... perform action ...
  /// final after = scry.observe(glyphsAfter);
  /// final diff = scry.diff(before, after);
  ///
  /// if (diff.routeChanged) {
  ///   print('Navigation detected!');
  /// }
  /// ```
  ScryDiff diff(ScryGaze before, ScryGaze after) {
    final beforeLabels = <String, ScryElement>{
      for (final e in before.elements) e.label: e,
    };
    final afterLabels = <String, ScryElement>{
      for (final e in after.elements) e.label: e,
    };

    // Elements that appeared (in after, not in before)
    final appeared = <ScryElement>[
      for (final e in after.elements)
        if (!beforeLabels.containsKey(e.label)) e,
    ];

    // Elements that disappeared (in before, not in after)
    final disappeared = <ScryElement>[
      for (final e in before.elements)
        if (!afterLabels.containsKey(e.label)) e,
    ];

    // Values that changed (element exists in both, but value differs)
    final changedValues = <String, Map<String, String?>>{};
    for (final e in after.elements) {
      final prev = beforeLabels[e.label];
      if (prev != null && prev.currentValue != e.currentValue) {
        changedValues[e.label] = {
          'from': prev.currentValue,
          'to': e.currentValue,
        };
      }
    }

    return ScryDiff(
      appeared: appeared,
      disappeared: disappeared,
      changedValues: changedValues,
      previousRoute: before.route,
      currentRoute: after.route,
      previousScreenType: before.screenType,
      currentScreenType: after.screenType,
    );
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
    bool isTextField = false,
  }) {
    // Fields first (text inputs) — includes labels that have a
    // text input widget anywhere in their glyph set, even if the
    // first glyph seen was a non-input (e.g. RichText label).
    if (isTextField ||
        semanticRole == 'textField' ||
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
        wtLower == 'navigationdestination' ||
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

  // -----------------------------------------------------------------------
  // Intelligence: Screen type detection
  // -----------------------------------------------------------------------

  /// Regex patterns for error-like text content.
  static final _errorTextPattern = RegExp(
    r'\b(error|failed|failure|invalid|denied|unauthorized|forbidden'
    r'|not found|exception|could not|unable to|something went wrong'
    r'|oops|try again|cannot)\b',
    caseSensitive: false,
  );

  /// Regex patterns for loading indicator widget types.
  static final _loadingWidgetPattern = RegExp(
    r'CircularProgressIndicator|LinearProgressIndicator'
    r'|RefreshProgressIndicator|CupertinoActivityIndicator'
    r'|Shimmer|Skeleton',
    caseSensitive: false,
  );

  /// Regex patterns for snackbar / toast / banner widgets.
  ///
  /// Avoids matching `NotificationListener` or other Flutter framework
  /// types that contain "Notification" — those are not visible notices.
  static final _noticeWidgetPattern = RegExp(
    r'SnackBar|MaterialBanner|Toast(?!Transition)',
    caseSensitive: false,
  );

  /// Classifications for the login button pattern.
  static final _submitButtonPattern = RegExp(
    r'\b(submit|save|confirm|apply|update|create|done|send'
    r'|register|sign up|next|finish|complete)\b',
    caseSensitive: false,
  );

  /// Classify the screen type from elements and context.
  ScryScreenType _classifyScreen(
    List<ScryElement> elements,
    List<ScryAlert> alerts,
    List<ScryKeyValue> dataFields,
  ) {
    final buttons = elements
        .where((e) => e.kind == ScryElementKind.button)
        .toList();
    final fields = elements
        .where((e) => e.kind == ScryElementKind.field)
        .toList();
    final nav = elements
        .where((e) => e.kind == ScryElementKind.navigation)
        .toList();
    final content = elements
        .where((e) => e.kind == ScryElementKind.content)
        .toList();

    // Error screen — error alerts present
    if (alerts.any((a) => a.severity == ScryAlertSeverity.error)) {
      return ScryScreenType.error;
    }

    // Login screen — fields + login button
    if (fields.isNotEmpty &&
        buttons.any(
          (b) => ScryGaze._loginButtonPattern.hasMatch(b.label.toLowerCase()),
        )) {
      return ScryScreenType.login;
    }

    // Settings screen — toggles, switches, dropdowns
    final toggleCount = elements.where((e) {
      final it = e.interactionType;
      return it == 'checkbox' ||
          it == 'radio' ||
          it == 'switch' ||
          it == 'slider' ||
          it == 'dropdown';
    }).length;
    if (toggleCount >= 2) {
      return ScryScreenType.settings;
    }

    // Form screen — multiple fields + submit/save button
    if (fields.length >= 2 &&
        buttons.any((b) => _submitButtonPattern.hasMatch(b.label))) {
      return ScryScreenType.form;
    }

    // Empty state — very few elements, no meaningful content
    if (content.isEmpty && fields.isEmpty && buttons.length <= 1) {
      return ScryScreenType.empty;
    }

    // List screen — many similar content items
    if (content.length >= 5 && fields.isEmpty && dataFields.isEmpty) {
      return ScryScreenType.list;
    }

    // Detail screen — data fields + limited buttons, possible back action
    if (dataFields.length >= 2 && fields.isEmpty) {
      return ScryScreenType.detail;
    }

    // Dashboard — mix of navigation, content, and buttons
    if (nav.length >= 2 && content.length >= 3 && buttons.isNotEmpty) {
      return ScryScreenType.dashboard;
    }

    return ScryScreenType.unknown;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Alert detection
  // -----------------------------------------------------------------------

  /// Detect errors, warnings, loading states, and notices from raw glyphs.
  List<ScryAlert> _detectAlerts(List<dynamic> glyphs) {
    final alerts = <ScryAlert>[];
    final seenMessages = <String>{};

    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final wt = glyph['wt'] as String? ?? '';
      final label = (glyph['l'] as String? ?? '').trim();
      final ancestors = glyph['anc'] as List<dynamic>? ?? [];
      final ancestorStr = ancestors.join(' ');

      // Loading indicators (by widget type)
      if (_loadingWidgetPattern.hasMatch(wt)) {
        final msg = label.isNotEmpty ? label : 'Loading indicator ($wt)';
        if (seenMessages.add(msg)) {
          alerts.add(
            ScryAlert(
              severity: ScryAlertSeverity.loading,
              message: msg,
              widgetType: wt,
            ),
          );
        }
        continue;
      }

      // Snackbar / MaterialBanner / Toast (by widget type or ancestor)
      if (_noticeWidgetPattern.hasMatch(wt) ||
          _noticeWidgetPattern.hasMatch(ancestorStr)) {
        if (label.isNotEmpty && seenMessages.add(label)) {
          // Classify as error if text contains error keywords
          final severity = _errorTextPattern.hasMatch(label)
              ? ScryAlertSeverity.error
              : ScryAlertSeverity.info;
          alerts.add(
            ScryAlert(severity: severity, message: label, widgetType: wt),
          );
        }
        continue;
      }

      // Error text detection (by content keywords)
      // Only if the text is short enough to be a message (not paragraphs)
      if (label.isNotEmpty &&
          label.length < 200 &&
          _errorTextPattern.hasMatch(label)) {
        // Only flag as error if it's clearly an error message, not
        // random content containing the word "error".
        final lower = label.toLowerCase();
        final isLikelyError =
            lower.startsWith('error') ||
            lower.startsWith('failed') ||
            lower.startsWith('invalid') ||
            lower.contains('try again') ||
            lower.contains('went wrong') ||
            lower.contains('could not') ||
            lower.contains('unable to');

        if (isLikelyError && seenMessages.add(label)) {
          alerts.add(
            ScryAlert(
              severity: ScryAlertSeverity.warning,
              message: label,
              widgetType: wt,
            ),
          );
        }
      }
    }

    return alerts;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Key-value pair extraction
  // -----------------------------------------------------------------------

  /// Pattern for labels that look like "Key: Value" pairs.
  static final _kvInlinePattern = RegExp(r'^(.+?):\s+(.+)$');

  /// Extract key-value pairs from raw glyphs using two strategies:
  ///
  /// 1. **Inline** — "Class: Scout" is a single label with ": " separator.
  /// 2. **Proximity** — "Class" at (x1, y1) and "Scout" at (x2, y2) where
  ///    they share the same Y band (same row) and x2 > x1.
  /// Pattern for icon codepoint labels (e.g., "IconData(U+0E596)").
  static final _iconDataPattern = RegExp(r'^IconData\(U\+[0-9A-Fa-f]+\)$');

  /// Pattern for raw Unicode private-use-area glyphs (single emoji-like chars).
  static final _rawGlyphPattern = RegExp(r'^[\uE000-\uF8FF\uDB80-\uDBFF]');

  List<ScryKeyValue> _extractKeyValuePairs(List<dynamic> glyphs) {
    final pairs = <ScryKeyValue>[];
    final usedLabels = <String>{};
    final seenPairs = <String>{};

    // --- Strategy 1: Inline "Key: Value" patterns ---
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty) continue;

      // Only consider non-interactive, non-structural text
      if (glyph['ia'] == true) continue;

      final match = _kvInlinePattern.firstMatch(label);
      if (match != null) {
        final key = match.group(1)!.trim();
        final value = match.group(2)!.trim();
        // Skip if key is too long (probably not a label:value pair)
        if (key.length <= 30 && value.isNotEmpty) {
          final pairKey = '$key\x00$value';
          if (seenPairs.add(pairKey)) {
            pairs.add(ScryKeyValue(key: key, value: value));
          }
          usedLabels
            ..add(label)
            ..add(key)
            ..add(value);
        }
      }
    }

    // --- Strategy 2: Proximity-based pairing ---
    // Collect non-interactive text glyphs with positions
    final positioned = <({String label, double x, double y, double w})>[];
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (glyph['ia'] == true) continue;
      if (usedLabels.contains(label)) continue;

      // Skip icon codepoint labels — not useful as data
      if (_iconDataPattern.hasMatch(label)) continue;
      if (_rawGlyphPattern.hasMatch(label)) continue;

      final x = (glyph['x'] as num?)?.toDouble();
      final y = (glyph['y'] as num?)?.toDouble();
      final w = (glyph['w'] as num?)?.toDouble();
      if (x == null || y == null || w == null) continue;

      positioned.add((label: label, x: x, y: y, w: w));
    }

    // Sort by y (rows), then x (left to right)
    positioned.sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });

    // Find pairs where two labels share the same Y band
    // and the "key" label is short (< 25 chars) and ends with ":"
    for (var i = 0; i < positioned.length - 1; i++) {
      final left = positioned[i];
      final right = positioned[i + 1];

      // Same row? Y within 8 logical pixels
      if ((left.y - right.y).abs() > 8) continue;
      // Right is to the right of left?
      if (right.x <= left.x + left.w - 5) continue;

      // Key candidate: short, possibly ends with ":"
      final keyLabel = left.label;
      final valueLabel = right.label;

      if (keyLabel.length <= 25 &&
          !usedLabels.contains(keyLabel) &&
          !usedLabels.contains(valueLabel)) {
        // Strip trailing colon if present
        final cleanKey = keyLabel.endsWith(':')
            ? keyLabel.substring(0, keyLabel.length - 1).trim()
            : keyLabel;
        if (cleanKey.isNotEmpty && valueLabel.isNotEmpty) {
          final pairKey = '$cleanKey\x00$valueLabel';
          if (seenPairs.add(pairKey)) {
            pairs.add(ScryKeyValue(key: cleanKey, value: valueLabel));
          }
          usedLabels
            ..add(keyLabel)
            ..add(valueLabel);
        }
      }
    }

    return pairs;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Action suggestions
  // -----------------------------------------------------------------------

  /// Generate context-aware action suggestions.
  List<String> _generateSuggestions(
    List<ScryElement> elements,
    ScryScreenType screenType,
    List<ScryAlert> alerts,
  ) {
    final suggestions = <String>[];

    // Alert-driven suggestions
    if (alerts.any((a) => a.severity == ScryAlertSeverity.error)) {
      suggestions.add(
        'An error is visible — check the error message and '
        'consider navigating back or retrying the action.',
      );
    }
    if (alerts.any((a) => a.severity == ScryAlertSeverity.loading)) {
      suggestions.add(
        'The screen is loading — wait for the loading '
        'indicator to disappear before interacting.',
      );
    }

    final fields = elements
        .where((e) => e.kind == ScryElementKind.field)
        .toList();
    final buttons = elements
        .where((e) => e.kind == ScryElementKind.button)
        .toList();
    final nav = elements
        .where((e) => e.kind == ScryElementKind.navigation)
        .toList();

    switch (screenType) {
      case ScryScreenType.login:
        final loginField = fields.isNotEmpty ? fields.first.label : 'the field';
        final loginBtn = buttons
            .where(
              (b) =>
                  ScryGaze._loginButtonPattern.hasMatch(b.label.toLowerCase()),
            )
            .firstOrNull;
        suggestions.add(
          'Enter credentials in "$loginField" and tap '
          '"${loginBtn?.label ?? 'the login button'}".',
        );

      case ScryScreenType.form:
        final fieldNames = fields.map((f) => '"${f.label}"').join(', ');
        final submitBtn = buttons
            .where((b) => _submitButtonPattern.hasMatch(b.label))
            .firstOrNull;
        suggestions.add(
          'Fill in $fieldNames, then tap '
          '"${submitBtn?.label ?? 'Submit'}".',
        );

      case ScryScreenType.list:
        suggestions.add(
          'Tap an item to see its details, or use navigation '
          'tabs to switch sections.',
        );
        if (nav.isNotEmpty) {
          final tabNames = nav.map((n) => '"${n.label}"').join(', ');
          suggestions.add('Available tabs: $tabNames.');
        }

      case ScryScreenType.detail:
        suggestions.add(
          'Review the data displayed. Use the back button to '
          'return, or tap available actions.',
        );

      case ScryScreenType.settings:
        suggestions.add(
          'Toggle settings as needed. Changes may be applied '
          'immediately or require a save action.',
        );

      case ScryScreenType.empty:
        suggestions.add(
          'The screen appears empty. Try navigating to a '
          'different section or triggering an action.',
        );

      case ScryScreenType.error:
        suggestions.add(
          'The screen shows an error. Note the error message '
          'and navigate back or retry.',
        );

      case ScryScreenType.dashboard:
        if (nav.isNotEmpty) {
          final tabNames = nav.map((n) => '"${n.label}"').join(', ');
          suggestions.add('Navigate to: $tabNames.');
        }
        if (buttons.isNotEmpty) {
          suggestions.add(
            'Available actions: '
            '${buttons.map((b) => '"${b.label}"').take(5).join(', ')}.',
          );
        }

      case ScryScreenType.unknown:
        if (fields.isNotEmpty) {
          suggestions.add(
            'Text fields available: '
            '${fields.map((f) => '"${f.label}"').join(', ')}.',
          );
        }
        if (buttons.isNotEmpty) {
          suggestions.add(
            'Buttons available: '
            '${buttons.map((b) => '"${b.label}"').take(5).join(', ')}.',
          );
        }
        if (nav.isNotEmpty) {
          suggestions.add(
            'Navigation: '
            '${nav.map((n) => '"${n.label}"').join(', ')}.',
          );
        }
    }

    return suggestions;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Ancestor context extraction
  // -----------------------------------------------------------------------

  /// Known container widgets that provide useful context.
  static const _contextContainers = [
    'AboutDialog',
    'AlertDialog',
    'SimpleDialog',
    'Dialog',
    'ModalBottomSheet',
    'BottomSheet',
    'Card',
    'ExpansionTile',
    'ListTile',
    'Drawer',
    'PopupMenuButton',
    'DropdownButton',
    'Tooltip',
  ];

  /// Extract the nearest meaningful ancestor container context.
  ///
  /// Returns a human-readable context string like `'Dialog'`,
  /// `'Card'`, `'BottomSheet'`, or `null` if no notable ancestor.
  String? _extractAncestorContext(List<dynamic> ancestors) {
    if (ancestors.isEmpty) return null;

    final ancestorStr = ancestors.join(' ');
    for (final container in _contextContainers) {
      if (ancestorStr.contains(container)) return container;
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Screen region inference
  // -----------------------------------------------------------------------

  /// Standard Material Design breakpoints for region inference.
  static const _topBarMaxY = 100.0;
  static const _bottomNavMinY = 700.0;

  /// Infer the screen region from position and ancestor data.
  ScryScreenRegion _inferRegion({
    double? y,
    double? h,
    required List<dynamic> ancestors,
  }) {
    final ancestorStr = ancestors.join(' ').toLowerCase();

    // Ancestor-based (most reliable)
    if (ancestorStr.contains('appbar') || ancestorStr.contains('toolbar')) {
      return ScryScreenRegion.topBar;
    }
    if (ancestorStr.contains('navigationbar') ||
        ancestorStr.contains('bottomnavigationbar') ||
        ancestorStr.contains('navigationrail')) {
      return ScryScreenRegion.bottomNav;
    }
    if (ancestorStr.contains('floatingactionbutton')) {
      return ScryScreenRegion.floating;
    }

    // Position-based fallback
    if (y != null) {
      if (y < _topBarMaxY) return ScryScreenRegion.topBar;
      if (y > _bottomNavMinY) return ScryScreenRegion.bottomNav;
      return ScryScreenRegion.mainContent;
    }

    return ScryScreenRegion.unknown;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Overlap / occlusion detection
  // -----------------------------------------------------------------------

  /// Detect elements obscured by higher-depth overlays.
  ///
  /// A Dialog or modal at depth 50 obscures elements at depth 10
  /// if their bounding boxes overlap. This mutates element list
  /// in place by replacing obscured elements with copies.
  void _detectOverlaps(List<ScryElement> elements, int maxDepth) {
    // Find the overlay threshold — elements inside Dialog/BottomSheet
    // are typically much deeper than background content.
    // We use the context field to identify overlay elements.
    final overlayElements = elements
        .where(
          (e) =>
              e.context == 'Dialog' ||
              e.context == 'AlertDialog' ||
              e.context == 'SimpleDialog' ||
              e.context == 'BottomSheet' ||
              e.context == 'ModalBottomSheet',
        )
        .toList();

    if (overlayElements.isEmpty) return;

    // Compute the bounding box of the overlay
    double? overlayMinX, overlayMinY, overlayMaxX, overlayMaxY;
    var overlayMinDepth = maxDepth;

    for (final o in overlayElements) {
      if (o.x != null && o.y != null && o.w != null && o.h != null) {
        final ox = o.x!;
        final oy = o.y!;
        final ow = o.w!;
        final oh = o.h!;

        overlayMinX = overlayMinX == null
            ? ox
            : (ox < overlayMinX ? ox : overlayMinX);
        overlayMinY = overlayMinY == null
            ? oy
            : (oy < overlayMinY ? oy : overlayMinY);
        overlayMaxX = overlayMaxX == null
            ? ox + ow
            : (ox + ow > overlayMaxX ? ox + ow : overlayMaxX);
        overlayMaxY = overlayMaxY == null
            ? oy + oh
            : (oy + oh > overlayMaxY ? oy + oh : overlayMaxY);
      }
      if (o.depth != null && o.depth! < overlayMinDepth) {
        overlayMinDepth = o.depth!;
      }
    }

    // No spatial data → can't detect overlaps
    if (overlayMinX == null ||
        overlayMinY == null ||
        overlayMaxX == null ||
        overlayMaxY == null) {
      return;
    }

    // Mark non-overlay elements as obscured if they overlap spatially
    // and have lower depth than the overlay.
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (e.context == 'Dialog' ||
          e.context == 'AlertDialog' ||
          e.context == 'SimpleDialog' ||
          e.context == 'BottomSheet' ||
          e.context == 'ModalBottomSheet') {
        continue; // Don't mark overlay elements themselves
      }

      if (e.depth != null &&
          e.depth! < overlayMinDepth &&
          e.x != null &&
          e.y != null) {
        // Check spatial overlap
        final ex = e.x!;
        final ey = e.y!;
        final ew = e.w ?? 0;
        final eh = e.h ?? 0;

        final overlaps =
            ex < overlayMaxX &&
            ex + ew > overlayMinX &&
            ey < overlayMaxY &&
            ey + eh > overlayMinY;

        if (overlaps) {
          // Replace with an obscured copy
          elements[i] = _copyWith(e, obscured: true);
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Intelligence: Form validation awareness
  // -----------------------------------------------------------------------

  /// Pattern for validation error text near form fields.
  static final _validationErrorPattern = RegExp(
    r'\b(required|must be|cannot be empty|invalid|too short|too long'
    r'|at least|no more than|does not match|already taken'
    r'|please enter|please provide|is required)\b',
    caseSensitive: false,
  );

  /// Analyze form field status — fill state, validation, readiness.
  ScryFormStatus? _analyzeFormStatus(
    List<ScryElement> elements,
    List<dynamic> glyphs,
  ) {
    final fields = elements
        .where((e) => e.kind == ScryElementKind.field)
        .toList();

    if (fields.isEmpty) return null;

    final emptyFields = <String>[];
    final disabledFields = <String>[];
    var filledCount = 0;

    for (final f in fields) {
      if (!f.isEnabled) {
        disabledFields.add(f.label);
      }
      if (f.currentValue == null || f.currentValue!.isEmpty) {
        emptyFields.add(f.label);
      } else {
        filledCount++;
      }
    }

    // Detect validation errors by finding error-like text near fields
    final validationErrors = <ScryFieldError>[];

    for (final f in fields) {
      if (f.y == null) continue;

      // Look for error helper text below each field (within ~50px)
      for (final g in glyphs) {
        final glyph = g as Map<String, dynamic>;
        final label = (glyph['l'] as String? ?? '').trim();
        if (label.isEmpty) continue;
        if (glyph['ia'] == true) continue; // Skip interactive elements

        final gy = (glyph['y'] as num?)?.toDouble();
        if (gy == null) continue;

        // Error text is typically directly below the field
        final dy = gy - f.y!;
        if (dy < 5 || dy > 50) continue;

        // Check X proximity too
        if (f.x != null) {
          final gx = (glyph['x'] as num?)?.toDouble();
          if (gx != null && (gx - f.x!).abs() > 20) continue;
        }

        if (_validationErrorPattern.hasMatch(label)) {
          validationErrors.add(
            ScryFieldError(fieldLabel: f.label, errorMessage: label),
          );
        }
      }
    }

    return ScryFormStatus(
      totalFields: fields.length,
      filledFields: filledCount,
      emptyFields: emptyFields,
      validationErrors: validationErrors,
      disabledFields: disabledFields,
    );
  }

  // -----------------------------------------------------------------------
  // Pass 5: Target stability scoring
  // -----------------------------------------------------------------------

  /// Score each element's targeting reliability and recommend strategy.
  ///
  /// Mutates [elements] in place by replacing each with a scored copy.
  void _applyTargetScoring(List<ScryElement> elements) {
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (!e.isInteractive) continue;

      final (score, strategy) = _scoreTarget(e);
      elements[i] = _copyWith(e, targetScore: score, targetStrategy: strategy);
    }
  }

  /// Compute targeting score and strategy for a single element.
  (int, ScryTargetStrategy) _scoreTarget(ScryElement e) {
    if (e.key != null) return (100, ScryTargetStrategy.key);
    if (e.fieldId != null) return (90, ScryTargetStrategy.fieldId);
    if (e.totalOccurrences == null) return (70, ScryTargetStrategy.uniqueLabel);
    return (40, ScryTargetStrategy.indexedLabel);
  }

  // -----------------------------------------------------------------------
  // Pass 5: Reachability analysis
  // -----------------------------------------------------------------------

  /// Typical viewport height for reachability checks.
  static const _defaultViewportHeight = 800.0;

  /// Assess whether each interactive element can actually be reached.
  ///
  /// An element is unreachable if it is disabled, obscured, or
  /// positioned offscreen (Y > viewport height).
  void _applyReachability(List<ScryElement> elements) {
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (!e.isInteractive) continue;

      final reachable =
          e.isEnabled &&
          !e.obscured &&
          (e.y == null || e.y! < _defaultViewportHeight);

      if (!reachable) {
        elements[i] = _copyWith(e, reachable: false);
      }
    }
  }

  // -----------------------------------------------------------------------
  // Pass 5: Visual prominence scoring
  // -----------------------------------------------------------------------

  /// Region weight multipliers for prominence scoring.
  static const _regionWeights = <ScryScreenRegion, double>{
    ScryScreenRegion.floating: 1.5,
    ScryScreenRegion.topBar: 1.2,
    ScryScreenRegion.mainContent: 1.0,
    ScryScreenRegion.bottomNav: 0.8,
    ScryScreenRegion.unknown: 0.5,
  };

  /// Score each element's visual prominence (0.0–1.0).
  ///
  /// Based on bounding box area relative to the largest element,
  /// screen region, and depth.
  void _applyProminence(List<ScryElement> elements) {
    // Find max area for normalization
    var maxArea = 1.0;
    for (final e in elements) {
      final area = (e.w ?? 0) * (e.h ?? 0);
      if (area > maxArea) maxArea = area;
    }

    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      final area = (e.w ?? 0) * (e.h ?? 0);
      final normalized = area / maxArea; // 0.0-1.0
      final regionWeight = _regionWeights[e.region] ?? 1.0;
      final prominence = (normalized * regionWeight).clamp(0.0, 1.0);

      if (prominence > 0) {
        elements[i] = _copyWith(e, prominence: prominence);
      }
    }
  }

  // -----------------------------------------------------------------------
  // Pass 5: Scroll / viewport analysis
  // -----------------------------------------------------------------------

  /// Analyze viewport and scrollability from element positions.
  ScryScrollInfo? _analyzeScroll(List<ScryElement> elements) {
    // Need spatial data
    final withY = elements.where((e) => e.y != null).toList();
    if (withY.isEmpty) return null;

    var contentMaxY = 0.0;
    var belowFold = 0;
    var visible = 0;

    for (final e in withY) {
      final bottom = e.y! + (e.h ?? 0);
      if (bottom > contentMaxY) contentMaxY = bottom;

      if (e.y! >= _defaultViewportHeight) {
        belowFold++;
      } else {
        visible++;
      }
    }

    return ScryScrollInfo(
      viewportHeight: _defaultViewportHeight,
      contentMaxY: contentMaxY,
      visibleCount: visible,
      belowFoldCount: belowFold,
    );
  }

  // -----------------------------------------------------------------------
  // Pass 5: Element grouping by container
  // -----------------------------------------------------------------------

  /// Known container types for grouping.
  static const _groupContainers = [
    'Card',
    'ListTile',
    'ExpansionTile',
    'Dismissible',
  ];

  /// Group elements by shared ancestor container.
  List<ScryElementGroup> _groupElements(
    List<ScryElement> elements,
    List<dynamic> glyphs,
  ) {
    // Build a mapping from element label to its ancestors
    final labelAncestors = <String, List<dynamic>>{};
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty) continue;
      final anc = glyph['anc'] as List<dynamic>? ?? [];
      // Keep first (most interactive) for dedup
      labelAncestors.putIfAbsent(label, () => anc);
    }

    // Group: find elements whose ancestors contain a group container
    final groups = <String, List<ScryElement>>{};
    for (final e in elements) {
      final ancestors = labelAncestors[e.label] ?? [];
      final ancestorStr = ancestors.join(' ');
      for (final container in _groupContainers) {
        if (ancestorStr.contains(container)) {
          groups.putIfAbsent(container, () => []).add(e);
          break; // Only first match
        }
      }
    }

    return groups.entries
        .where((e) => e.value.length >= 2) // Only groups with 2+ elements
        .map((e) => ScryElementGroup(containerType: e.key, elements: e.value))
        .toList();
  }

  // -----------------------------------------------------------------------
  // Pass 5: Semantic landmark detection
  // -----------------------------------------------------------------------

  /// Back/close button patterns.
  static final _backPattern = RegExp(
    r'\b(back|close|cancel|return|arrow_back|chevron_left)\b',
    caseSensitive: false,
  );

  /// Search patterns.
  static final _searchPattern = RegExp(
    r'\b(search|find|filter|lookup)\b',
    caseSensitive: false,
  );

  /// Detect key semantic landmarks on the screen.
  ScryLandmarks _detectLandmarks(
    List<ScryElement> elements,
    ScryScreenType screenType,
  ) {
    // Page title: structural element in topBar region
    String? pageTitle;
    for (final e in elements) {
      if (e.kind == ScryElementKind.structural &&
          e.region == ScryScreenRegion.topBar) {
        pageTitle = e.label;
        break;
      }
    }

    // Primary action: the most prominent interactive element.
    // Prefer FABs, then the largest (highest prominence) button.
    ScryElement? primaryAction;
    for (final e in elements) {
      if (e.kind == ScryElementKind.button && e.reachable) {
        if (e.region == ScryScreenRegion.floating) {
          primaryAction = e;
          break;
        }
        if (primaryAction == null || e.prominence > primaryAction.prominence) {
          primaryAction = e;
        }
      }
    }

    // Back / close availability
    final backAvailable = elements.any(
      (e) =>
          e.isInteractive &&
          (_backPattern.hasMatch(e.label) ||
              e.semanticRole == 'button' &&
                  _backPattern.hasMatch(e.label.toLowerCase())),
    );

    // Search availability
    final searchAvailable = elements.any(
      (e) => _searchPattern.hasMatch(e.label),
    );

    return ScryLandmarks(
      pageTitle: pageTitle,
      primaryAction: primaryAction,
      backAvailable: backAvailable,
      searchAvailable: searchAvailable,
    );
  }

  // -----------------------------------------------------------------------
  // Helper: copy ScryElement with overridden fields
  // -----------------------------------------------------------------------

  /// Create a copy of [e] with specified fields overridden.
  ScryElement _copyWith(
    ScryElement e, {
    bool? obscured,
    int? targetScore,
    ScryTargetStrategy? targetStrategy,
    bool? reachable,
    double? prominence,
    ScryFieldValueType? inputType,
    ScryActionImpact? predictedImpact,
  }) => ScryElement(
    kind: e.kind,
    label: e.label,
    widgetType: e.widgetType,
    isInteractive: e.isInteractive,
    fieldId: e.fieldId,
    currentValue: e.currentValue,
    semanticRole: e.semanticRole,
    interactionType: e.interactionType,
    isEnabled: e.isEnabled,
    gated: e.gated,
    x: e.x,
    y: e.y,
    w: e.w,
    h: e.h,
    depth: e.depth,
    key: e.key,
    context: e.context,
    obscured: obscured ?? e.obscured,
    occurrenceIndex: e.occurrenceIndex,
    totalOccurrences: e.totalOccurrences,
    region: e.region,
    targetScore: targetScore ?? e.targetScore,
    targetStrategy: targetStrategy ?? e.targetStrategy,
    reachable: reachable ?? e.reachable,
    prominence: prominence ?? e.prominence,
    inputType: inputType ?? e.inputType,
    predictedImpact: predictedImpact ?? e.predictedImpact,
  );

  // -----------------------------------------------------------------------
  // Pass 5: Field input type inference
  // -----------------------------------------------------------------------

  /// Patterns for detecting field input types from labels and fieldIds.
  static final _emailPattern = RegExp(
    r'\b(e-?mail|correo|courriel)\b',
    caseSensitive: false,
  );
  static final _passwordPattern = RegExp(
    r'\b(password|passwd|secret|pin|passcode|contraseña|mot.de.passe)\b',
    caseSensitive: false,
  );
  static final _phonePattern = RegExp(
    r'\b(phone|tel|mobile|cell|número|telefon)\b',
    caseSensitive: false,
  );
  static final _numericPattern = RegExp(
    r'\b(amount|price|cost|quantity|qty|age|count|number|total|sum)\b',
    caseSensitive: false,
  );
  static final _datePattern = RegExp(
    r'\b(date|birth|dob|deadline|expir|calendar|fecha)\b',
    caseSensitive: false,
  );
  static final _urlPattern = RegExp(
    r'\b(url|website|link|href|domain|homepage)\b',
    caseSensitive: false,
  );

  /// Infer the expected input type for each text field element.
  void _applyInputTypes(List<ScryElement> elements) {
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (e.kind != ScryElementKind.field) continue;

      final type = _inferFieldType(e);
      if (type != null) {
        elements[i] = _copyWith(e, inputType: type);
      }
    }
  }

  /// Determine the input type from label, fieldId, and value patterns.
  ScryFieldValueType? _inferFieldType(ScryElement e) {
    final text = '${e.label} ${e.fieldId ?? ''}';

    if (_emailPattern.hasMatch(text)) return ScryFieldValueType.email;
    if (_passwordPattern.hasMatch(text)) return ScryFieldValueType.password;
    if (_phonePattern.hasMatch(text)) return ScryFieldValueType.phone;
    if (_numericPattern.hasMatch(text)) return ScryFieldValueType.numeric;
    if (_datePattern.hasMatch(text)) return ScryFieldValueType.date;
    if (_urlPattern.hasMatch(text)) return ScryFieldValueType.url;
    if (_searchPattern.hasMatch(text)) return ScryFieldValueType.search;

    // Check current value patterns
    final cv = e.currentValue ?? '';
    if (cv.contains('@') && cv.contains('.')) return ScryFieldValueType.email;

    return null; // freeText is the default, no need to set explicitly
  }

  // -----------------------------------------------------------------------
  // Pass 5: Action impact prediction
  // -----------------------------------------------------------------------

  /// Patterns for predicting action outcomes.
  static final _navigatePattern = RegExp(
    r'\b(view|details|open|go|show|see|more|info|profile|settings)\b',
    caseSensitive: false,
  );
  static final _submitPattern = RegExp(
    r'\b(save|submit|send|apply|confirm|ok|done|create|post|update)\b',
    caseSensitive: false,
  );
  static final _deletePattern = RegExp(
    r'\b(delete|remove|trash|clear|erase|destroy|discard)\b',
    caseSensitive: false,
  );
  static final _expandPattern = RegExp(
    r'\b(expand|collapse|toggle|show more|show less|accordion)\b',
    caseSensitive: false,
  );
  static final _dismissPattern = RegExp(
    r'\b(close|cancel|dismiss|back|return|exit|no)\b',
    caseSensitive: false,
  );

  /// Predict the impact of interacting with each interactive element.
  void _applyActionImpacts(List<ScryElement> elements) {
    for (var i = 0; i < elements.length; i++) {
      final e = elements[i];
      if (!e.isInteractive) continue;

      final impact = _predictImpact(e);
      elements[i] = _copyWith(e, predictedImpact: impact);
    }
  }

  /// Predict what will happen when the user interacts with this element.
  ScryActionImpact _predictImpact(ScryElement e) {
    final label = e.label.toLowerCase();
    final wt = e.widgetType.toLowerCase();

    // Toggle widgets
    if (wt.contains('switch') ||
        wt.contains('checkbox') ||
        wt.contains('radio') ||
        e.interactionType == 'toggle') {
      return ScryActionImpact.toggle;
    }

    // ExpansionTile / accordion
    if (wt.contains('expansiontile') || _expandPattern.hasMatch(label)) {
      return ScryActionImpact.expand;
    }

    // Overlay-opening widgets
    if (wt.contains('popupmenu') ||
        wt.contains('dropdownbutton') ||
        label.contains('menu') && e.kind == ScryElementKind.button) {
      return ScryActionImpact.openModal;
    }

    // Label-based predictions (order matters)
    if (_deletePattern.hasMatch(label)) return ScryActionImpact.delete;
    if (_dismissPattern.hasMatch(label)) return ScryActionImpact.dismiss;
    if (_submitPattern.hasMatch(label)) return ScryActionImpact.submit;
    if (_navigatePattern.hasMatch(label)) return ScryActionImpact.navigate;

    // Navigation elements default to navigate
    if (e.kind == ScryElementKind.navigation) return ScryActionImpact.navigate;

    return ScryActionImpact.unknown;
  }

  // -----------------------------------------------------------------------
  // Pass 5: Overlay / modal content analysis
  // -----------------------------------------------------------------------

  /// Overlay container types to detect.
  static const _overlayTypes = [
    'AboutDialog',
    'AlertDialog',
    'Dialog',
    'SimpleDialog',
    'BottomSheet',
    'ModalBottomSheet',
    'Snackbar',
    'DatePicker',
    'TimePicker',
  ];

  /// Analyze overlay structure when elements are obscured.
  ///
  /// Detects overlays in three ways:
  /// 1. Elements whose ancestor context matches an overlay type
  /// 2. Elements whose widgetType is itself an overlay type
  /// 3. Raw glyph pre-scan (catches overlay widgets with no label
  ///    that were filtered out during element creation)
  ScryOverlayInfo? _analyzeOverlay(
    List<ScryElement> elements, {
    String? rawOverlayType,
    int rawOverlayDepth = 0,
  }) {
    // Strategy 1: elements with overlay ancestor context
    var overlayElements = elements
        .where((e) => _overlayTypes.contains(e.context))
        .toList();

    // Strategy 2: check for captured overlay widgets directly.
    String? detectedType;
    if (overlayElements.isEmpty) {
      for (final typeName in _overlayTypes) {
        final match = elements.where((e) => e.widgetType == typeName).toList();
        if (match.isNotEmpty) {
          detectedType = typeName;
          final overlayDepth = match.first.depth ?? 0;
          overlayElements = elements
              .where((e) => (e.depth ?? 0) >= overlayDepth)
              .toList();
          break;
        }
      }
    }

    // Strategy 3: raw glyph pre-scan detected an overlay widget that
    // was filtered out (no label). Use depth to identify overlay content.
    if (overlayElements.isEmpty && rawOverlayType != null) {
      detectedType = rawOverlayType;
      overlayElements = elements
          .where((e) => (e.depth ?? 0) >= rawOverlayDepth)
          .toList();
    }
    if (overlayElements.isEmpty) return null;

    // Determine the overlay type
    final type =
        detectedType ??
        overlayElements.firstWhere((e) => e.context != null).context!;

    // Find title: first structural or content element in the overlay
    String? title;
    for (final e in overlayElements) {
      if (e.kind == ScryElementKind.structural ||
          e.kind == ScryElementKind.content) {
        title = e.label;
        break;
      }
    }

    // Find action buttons in the overlay
    final actions = overlayElements
        .where((e) => e.kind == ScryElementKind.button)
        .toList();

    // Check for dismiss capability
    final canDismiss = overlayElements.any(
      (e) => e.isInteractive && _dismissPattern.hasMatch(e.label.toLowerCase()),
    );

    return ScryOverlayInfo(
      type: type,
      title: title,
      actions: actions,
      canDismiss: canDismiss,
    );
  }

  // -----------------------------------------------------------------------
  // Pass 5: Layout pattern detection
  // -----------------------------------------------------------------------

  /// Detect the dominant layout pattern from element positions.
  ScryLayoutPattern _detectLayoutPattern(List<ScryElement> elements) {
    final withPos = elements.where((e) => e.x != null && e.y != null).toList();
    if (withPos.length < 3) return ScryLayoutPattern.freeform;

    // Collect unique X and Y positions (rounded to nearest 10px)
    final xPositions = <int>{};
    final yPositions = <int>{};
    for (final e in withPos) {
      xPositions.add((e.x! / 10).round());
      yPositions.add((e.y! / 10).round());
    }

    final uniqueX = xPositions.length;
    final uniqueY = yPositions.length;

    // Grid: multiple distinct X AND Y positions (rows × columns)
    if (uniqueX >= 2 && uniqueY >= 2 && withPos.length >= uniqueX * 2) {
      return ScryLayoutPattern.grid;
    }

    // If most elements share the same X (±10px), it's a vertical list
    if (uniqueX <= 2 && uniqueY >= 3) return ScryLayoutPattern.verticalList;

    // If most elements share the same Y, it's a horizontal row
    if (uniqueY <= 2 && uniqueX >= 3) return ScryLayoutPattern.horizontalRow;

    // Very few elements may be a single card
    if (withPos.length <= 4 && uniqueY <= 3) {
      return ScryLayoutPattern.singleCard;
    }

    return ScryLayoutPattern.freeform;
  }

  // -----------------------------------------------------------------------
  // Pass 5: Toggle / selection state summary
  // -----------------------------------------------------------------------

  /// Toggle interaction types.
  static const _toggleInteractionTypes = {
    'toggle',
    'checkbox',
    'switch',
    'radio',
  };

  /// Toggle widget type patterns.
  static final _toggleWidgetPattern = RegExp(
    r'switch|checkbox|radio|togglebutton',
    caseSensitive: false,
  );

  /// Build a summary of all toggle/switch/checkbox states.
  ScryToggleSummary? _buildToggleSummary(List<ScryElement> elements) {
    final toggles = <ScryToggleState>[];

    for (final e in elements) {
      if (!e.isInteractive) continue;

      final isToggle =
          _toggleInteractionTypes.contains(e.interactionType) ||
          _toggleWidgetPattern.hasMatch(e.widgetType);

      if (!isToggle) continue;

      final cv = (e.currentValue ?? '').toLowerCase();
      final isActive =
          cv == 'true' || cv == 'on' || cv == '1' || cv == 'selected';

      toggles.add(
        ScryToggleState(
          label: e.label,
          widgetType: e.widgetType,
          currentValue: e.currentValue,
          isActive: isActive,
        ),
      );
    }

    return toggles.isEmpty ? null : ScryToggleSummary(toggles: toggles);
  }

  // -----------------------------------------------------------------------
  // Pass 5: Field tab order
  // -----------------------------------------------------------------------

  /// Compute the natural tab order for text fields (top→bottom, left→right).
  List<String> _computeTabOrder(List<ScryElement> elements) {
    final fields = elements
        .where((e) => e.kind == ScryElementKind.field)
        .toList();
    if (fields.length < 2) {
      return fields.map((e) => e.label).toList();
    }

    // Sort by Y first, then X for same-row fields
    fields.sort((a, b) {
      final yCompare = (a.y ?? 0).compareTo(b.y ?? 0);
      if (yCompare != 0) return yCompare;
      return (a.x ?? 0).compareTo(b.x ?? 0);
    });

    return fields.map((e) => e.label).toList();
  }
}
