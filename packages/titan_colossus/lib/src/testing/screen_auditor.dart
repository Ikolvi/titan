// ---------------------------------------------------------------------------
// ScreenAuditor — Automatic screen-state audit for data-binding bugs
// ---------------------------------------------------------------------------

import 'dart:math';

/// A single finding from a screen audit.
///
/// Represents an observed anomaly when comparing screen state
/// before and after a login with different credentials.
///
/// ## Severity Levels
///
/// - `bug` — Strong evidence of a defect (missing input, hardcoded data)
/// - `warning` — Suspicious pattern that warrants investigation
/// - `info` — Neutral observation (labels that changed between snapshots)
///
/// ## Categories
///
/// - `missing_input` — An entered value does not appear on screen
/// - `stale_data` — A previous value persists after credential change
/// - `data_binding` — Entered value missing AND old value persists
///   (combined evidence of a hardcoded/stale binding)
/// - `partial_match` — Input found only as a substring of another label
/// - `disappeared` — Labels present before but absent after re-login
/// - `appeared` — Labels absent before but present after re-login
///
/// ```dart
/// final finding = AuditFinding(
///   severity: 'bug',
///   category: 'data_binding',
///   message: 'Entered "Titan" but screen shows "Kael"',
///   expected: 'Titan',
///   actual: 'Kael',
/// );
/// ```
class AuditFinding {
  /// Creates an audit finding.
  const AuditFinding({
    required this.severity,
    required this.category,
    required this.message,
    this.expected,
    this.actual,
  });

  /// Severity level: `'bug'`, `'warning'`, or `'info'`.
  final String severity;

  /// Category of the finding.
  ///
  /// One of: `'missing_input'`, `'stale_data'`, `'data_binding'`,
  /// `'partial_match'`, `'disappeared'`, `'appeared'`.
  final String category;

  /// Human-readable description of the finding.
  final String message;

  /// Expected value on screen (if applicable).
  final String? expected;

  /// Actual value found on screen (if applicable).
  final String? actual;

  /// Serializes this finding to JSON.
  Map<String, dynamic> toJson() => {
    'severity': severity,
    'category': category,
    'message': message,
    if (expected != null) 'expected': expected,
    if (actual != null) 'actual': actual,
  };

  @override
  String toString() => 'AuditFinding($severity/$category: $message)';
}

/// Result of a screen audit comparing before/after login snapshots.
///
/// Contains all [findings] plus the raw label sets for further
/// analysis by AI consumers.
///
/// ## Example
///
/// ```dart
/// final report = const ScreenAuditor().compareScreens(
///   glyphsBefore: snapshot1,
///   glyphsAfter: snapshot2,
///   testInput: 'ProbeValue_abc',
/// );
///
/// if (report.hasBugs) {
///   for (final bug in report.bugs) {
///     print('BUG: ${bug.message}');
///   }
/// }
/// ```
class AuditReport {
  /// Creates an audit report.
  const AuditReport({
    required this.findings,
    required this.testInput,
    required this.labelsBefore,
    required this.labelsAfter,
  });

  /// All findings from the audit.
  final List<AuditFinding> findings;

  /// The test value that was entered at login.
  final String testInput;

  /// Display labels extracted from the "before" screen.
  final Set<String> labelsBefore;

  /// Display labels extracted from the "after" screen.
  final Set<String> labelsAfter;

  /// Whether any bug-severity findings exist.
  bool get hasBugs => findings.any((f) => f.severity == 'bug');

  /// Bug-severity findings only.
  List<AuditFinding> get bugs =>
      findings.where((f) => f.severity == 'bug').toList();

  /// Warning-severity findings only.
  List<AuditFinding> get warnings =>
      findings.where((f) => f.severity == 'warning').toList();

  /// Info-severity findings only.
  List<AuditFinding> get infos =>
      findings.where((f) => f.severity == 'info').toList();

  /// Labels present before but absent after re-login.
  Set<String> get disappeared => labelsBefore.difference(labelsAfter);

  /// Labels absent before but present after re-login.
  Set<String> get appeared => labelsAfter.difference(labelsBefore);

  /// Labels present in both snapshots.
  Set<String> get persisting => labelsBefore.intersection(labelsAfter);

  /// Serializes the report to JSON.
  Map<String, dynamic> toJson() => {
    'testInput': testInput,
    'hasBugs': hasBugs,
    'bugCount': bugs.length,
    'warningCount': warnings.length,
    'infoCount': infos.length,
    'findings': findings.map((f) => f.toJson()).toList(),
    'disappeared': disappeared.toList(),
    'appeared': appeared.toList(),
  };
}

/// **ScreenAuditor** — detects data-binding bugs by comparing
/// screen snapshots before and after login with different credentials.
///
/// The core algorithm:
///
/// 1. Extract display labels from both screen snapshots (before/after)
/// 2. Check if the entered test value appears on the post-login screen
/// 3. Check if old values persist when they should have changed
/// 4. Cross-reference missing inputs with stale values to identify
///    hardcoded data bindings
///
/// ## Usage
///
/// ```dart
/// const auditor = ScreenAuditor();
///
/// // Extract glyphs before and after login with different name
/// final report = auditor.compareScreens(
///   glyphsBefore: glyphsLoggedInAsKael,
///   glyphsAfter: glyphsLoggedInAsTitan,
///   testInput: 'Titan',
/// );
///
/// if (report.hasBugs) {
///   print('Found ${report.bugs.length} data-binding bugs!');
///   for (final bug in report.bugs) {
///     print('  ${bug.category}: ${bug.message}');
///   }
/// }
/// ```
///
/// Works with any app—not specific to any auth framework.
class ScreenAuditor {
  /// Creates a const [ScreenAuditor].
  const ScreenAuditor();

  /// Sign-out button label indicators (case-insensitive).
  ///
  /// Used by [detectSignOutButtons] to find logout actions.
  static const signOutIndicators = [
    'sign out',
    'log out',
    'logout',
    'sign off',
    'disconnect',
  ];

  /// Generate a unique probe value for audit testing.
  ///
  /// Returns a string like `'Probe_a7k3m9'` that is extremely
  /// unlikely to appear naturally in any app's UI, making it
  /// ideal for detecting whether entered values are properly
  /// displayed.
  ///
  /// ```dart
  /// final probe = ScreenAuditor.generateProbeValue();
  /// // e.g. 'Probe_a7k3m9'
  /// ```
  static String generateProbeValue() {
    final random = Random();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'Probe_$suffix';
  }

  /// Extract display-only text labels from screen glyphs.
  ///
  /// Returns non-icon text labels that could represent user data
  /// or content. Filters out structural UI elements like icons
  /// and single-character labels.
  ///
  /// [glyphs] — the `currentTableau.glyphs` array from Relay
  /// `/blueprint`.
  ///
  /// ```dart
  /// const auditor = ScreenAuditor();
  /// final labels = auditor.extractDisplayLabels(glyphs);
  /// print(labels); // {'Kael', 'Questboard', 'Slay the Bug Dragon', ...}
  /// ```
  Set<String> extractDisplayLabels(List<dynamic> glyphs) {
    final labels = <String>{};
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();

      if (label.isEmpty || label.length < 2) continue;

      // Skip icon-like labels (single Unicode symbols in PUA range)
      if (label.length == 1 && label.codeUnitAt(0) > 0xE000) continue;

      // Skip IconData(...) strings
      if (label.startsWith('IconData(')) continue;

      labels.add(label);
    }
    return labels;
  }

  /// Detect sign-out/logout buttons in screen glyphs.
  ///
  /// Returns deduplicated labels of interactive elements that
  /// match [signOutIndicators].
  ///
  /// ```dart
  /// const auditor = ScreenAuditor();
  /// final buttons = auditor.detectSignOutButtons(glyphs);
  /// // ['Sign Out']
  /// ```
  List<String> detectSignOutButtons(List<dynamic> glyphs) {
    final results = <String>[];
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final isInteractive = glyph['ia'] == true;
      final label = (glyph['l'] as String? ?? '').trim();

      if (!isInteractive || label.isEmpty) continue;

      if (isSignOutButton(label) && !results.contains(label)) {
        results.add(label);
      }
    }
    return results;
  }

  /// Check if [label] looks like a sign-out/logout button.
  ///
  /// Uses case-insensitive substring matching against
  /// [signOutIndicators].
  ///
  /// ```dart
  /// const auditor = ScreenAuditor();
  /// auditor.isSignOutButton('Sign Out'); // true
  /// auditor.isSignOutButton('Log Out');  // true
  /// auditor.isSignOutButton('Submit');   // false
  /// ```
  bool isSignOutButton(String label) {
    final lower = label.toLowerCase();
    return signOutIndicators.any((i) => lower.contains(i));
  }

  /// Compare two screen snapshots to detect data-binding bugs.
  ///
  /// [glyphsBefore] — widget glyphs from the screen while logged
  ///   in with the original identity (before sign-out).
  /// [glyphsAfter] — widget glyphs from the screen after login
  ///   with [testInput] as the new credential.
  /// [testInput] — the unique value entered at login for the audit.
  ///
  /// Returns an [AuditReport] with categorized findings:
  ///
  /// - `missing_input` (bug) — [testInput] not displayed anywhere
  /// - `stale_data` (warning) — old short labels persist unchanged
  /// - `data_binding` (bug) — input missing AND old value present
  /// - `partial_match` (info) — input found only as substring
  ///
  /// ## Algorithm
  ///
  /// ```text
  /// 1. Extract display labels from both snapshots
  /// 2. Check: is testInput in the "after" labels?
  ///    → No → BUG: missing_input
  ///    → Substring only → INFO: partial_match
  /// 3. Find labels that are ONLY in "before" (disappeared)
  /// 4. For each disappeared label that looks like a name:
  ///    → If testInput is missing → BUG: data_binding
  ///       (old name gone but new name not shown = hardcoded elsewhere)
  /// 5. Find short name-like labels in "after" that were also in "before"
  ///    → If testInput is missing → those are stale candidates
  /// ```
  ///
  /// ```dart
  /// const auditor = ScreenAuditor();
  /// final report = auditor.compareScreens(
  ///   glyphsBefore: snapshotAsKael,
  ///   glyphsAfter: snapshotAsTitan,
  ///   testInput: 'Titan',
  /// );
  /// print(report.hasBugs); // true if data-binding bug detected
  /// ```
  AuditReport compareScreens({
    required List<dynamic> glyphsBefore,
    required List<dynamic> glyphsAfter,
    required String testInput,
  }) {
    final findings = <AuditFinding>[];
    final before = extractDisplayLabels(glyphsBefore);
    final after = extractDisplayLabels(glyphsAfter);

    // --- Check 1: Is testInput visible on the post-login screen? ---
    final exactMatch = after.contains(testInput);
    final substringMatches =
        exactMatch
            ? <String>[]
            : after
                .where(
                  (l) => l.toLowerCase().contains(testInput.toLowerCase()),
                )
                .toList();

    if (!exactMatch && substringMatches.isEmpty) {
      findings.add(
        AuditFinding(
          severity: 'bug',
          category: 'missing_input',
          message:
              'Entered value "$testInput" is not displayed anywhere '
              'on screen after login',
          expected: testInput,
        ),
      );
    } else if (!exactMatch && substringMatches.isNotEmpty) {
      findings.add(
        AuditFinding(
          severity: 'info',
          category: 'partial_match',
          message:
              'Entered value "$testInput" found as substring in: '
              '${substringMatches.join(", ")}',
          expected: testInput,
          actual: substringMatches.first,
        ),
      );
    }

    // --- Check 2: Detect stale / hardcoded name-like labels ---
    // If testInput is missing, look for short name-like labels that
    // persist across login cycles (could be hardcoded).
    // Exclude structural UI labels (buttons, tabs, app bar titles)
    // to avoid false positives from UI chrome.
    final inputMissing = !exactMatch && substringMatches.isEmpty;

    if (inputMissing) {
      final persisting = before.intersection(after);
      final structural = _extractStructuralLabels(glyphsBefore)
          .union(_extractStructuralLabels(glyphsAfter));

      for (final label in persisting) {
        if (structural.contains(label)) continue;
        if (_looksLikeName(label)) {
          findings.add(
            AuditFinding(
              severity: 'bug',
              category: 'data_binding',
              message:
                  'Potential hardcoded value: "$label" persists on '
                  'screen after login as "$testInput" — value may be '
                  'hardcoded instead of bound to user input',
              expected: testInput,
              actual: label,
            ),
          );
        }
      }
    }

    // --- Check 3: Report disappeared and appeared labels ---
    final disappeared = before.difference(after);
    final appeared = after.difference(before);

    if (disappeared.isNotEmpty) {
      findings.add(
        AuditFinding(
          severity: 'info',
          category: 'disappeared',
          message:
              '${disappeared.length} label(s) disappeared after '
              're-login: ${_truncateSet(disappeared)}',
        ),
      );
    }

    if (appeared.isNotEmpty) {
      findings.add(
        AuditFinding(
          severity: 'info',
          category: 'appeared',
          message:
              '${appeared.length} label(s) appeared after '
              're-login: ${_truncateSet(appeared)}',
        ),
      );
    }

    return AuditReport(
      findings: findings,
      testInput: testInput,
      labelsBefore: before,
      labelsAfter: after,
    );
  }

  /// Identify labels that belong to structural UI elements.
  ///
  /// Returns labels from interactive controls (buttons, tabs,
  /// gesture detectors), app bar titles, navigation destinations,
  /// and other UI chrome. These labels represent the application's
  /// structural interface — not user-generated content — and should
  /// be excluded from data-binding comparisons.
  ///
  /// A label is considered structural if **any** glyph with that
  /// label matches one of:
  ///
  /// - Interactive (`ia == true`) — buttons, tabs, links
  /// - Widget type is a structural container (AppBar, NavigationBar,
  ///   Toolbar, Drawer, BottomSheet)
  /// - Ancestor chain contains structural containers (AppBar,
  ///   NavigationBar, NavigationDestination, TabBar, Toolbar, Drawer)
  ///
  /// ```dart
  /// const auditor = ScreenAuditor();
  /// final structural = auditor.extractStructuralLabels(glyphs);
  /// // {'Sign Out', 'About', 'Hero', 'Quests', 'Questboard', ...}
  /// ```
  Set<String> extractStructuralLabels(List<dynamic> glyphs) =>
      _extractStructuralLabels(glyphs);

  Set<String> _extractStructuralLabels(List<dynamic> glyphs) {
    final structural = <String>{};
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (label.startsWith('IconData(')) continue;

      // Interactive elements are UI controls, not user data
      if (glyph['ia'] == true) {
        structural.add(label);
        continue;
      }

      // Check widget type for structural containers
      final wt = (glyph['wt'] as String? ?? '').toLowerCase();
      if (wt == 'appbar' ||
          wt == 'navigationbar' ||
          wt == 'toolbar' ||
          wt == 'drawer' ||
          wt == 'bottomsheet') {
        structural.add(label);
        continue;
      }

      // Check ancestor chain for structural containers
      final ancestors = glyph['anc'] as List<dynamic>? ?? [];
      if (ancestors.isNotEmpty) {
        final ancestorStr = ancestors.join(' ').toLowerCase();
        if (ancestorStr.contains('appbar') ||
            ancestorStr.contains('navigationbar') ||
            ancestorStr.contains('navigationdestination') ||
            ancestorStr.contains('tabbar') ||
            ancestorStr.contains('toolbar') ||
            ancestorStr.contains('drawer')) {
          structural.add(label);
        }
      }
    }
    return structural;
  }

  /// Heuristic: does [label] look like a user name or short identity?
  ///
  /// Criteria:
  /// - 2 to 25 characters
  /// - Mostly alphabetic (≥ 70% letters)
  /// - Does not contain bullet separators (•), colons, or slashes
  /// - At most 3 words (names are typically 1–3 words)
  bool _looksLikeName(String label) {
    if (label.length < 2 || label.length > 25) return false;

    // Reject labels with structural punctuation
    if (label.contains('•') ||
        label.contains(':') ||
        label.contains('/') ||
        label.contains('(') ||
        label.contains(')')) {
      return false;
    }

    // Reject labels with more than 3 words (too long for a name)
    final words = label.split(RegExp(r'\s+'));
    if (words.length > 3) return false;

    // At least 70% of characters should be letters
    final letterCount = label.runes.where(_isLetter).length;
    final ratio = letterCount / label.length;
    return ratio >= 0.7;
  }

  /// Check if a Unicode code point is a letter.
  static bool _isLetter(int codePoint) {
    final char = String.fromCharCode(codePoint);
    return RegExp(r'\p{L}', unicode: true).hasMatch(char);
  }

  /// Truncate a set for display, showing at most [max] items.
  static String _truncateSet(Set<String> items, {int max = 5}) {
    final list = items.toList();
    if (list.length <= max) return list.join(', ');
    return '${list.take(max).join(', ')} (+${list.length - max} more)';
  }
}
