// ---------------------------------------------------------------------------
// AuthStratagemGenerator — Auto-generate authStratagem from Tableau glyphs
// ---------------------------------------------------------------------------

/// Result of [AuthStratagemGenerator.generate].
///
/// Contains the detected text fields, login buttons, and the
/// fully-formed `authStratagem` JSON ready for embedding in a
/// Campaign.
///
/// ## Example
///
/// ```dart
/// final generator = AuthStratagemGenerator();
/// final result = generator.generate(glyphs, defaultValue: 'Kael');
///
/// if (result.isAuthScreen) {
///   print(result.authStratagem); // Ready-to-use JSON map
/// }
/// ```
class AuthStratagemResult {
  /// Text field glyphs detected on the current screen.
  ///
  /// Each element is a compact glyph map with keys like
  /// `'wt'` (widgetType), `'l'` (label), `'ia'` (isInteractive), etc.
  final List<Map<String, dynamic>> textFields;

  /// Login button glyphs detected on the current screen.
  ///
  /// Identified by matching labels against
  /// [AuthStratagemGenerator.loginButtonIndicators].
  final List<Map<String, dynamic>> loginButtons;

  /// The generated `authStratagem` JSON map, or `null` if no
  /// auth screen was detected.
  ///
  /// When non-null, the structure matches what [Campaign.fromJson]
  /// expects:
  ///
  /// ```json
  /// {
  ///   "name": "_auth",
  ///   "description": "Auto-login — generated from live screen",
  ///   "startRoute": "",
  ///   "steps": [...]
  /// }
  /// ```
  final Map<String, dynamic>? authStratagem;

  /// Whether the current screen appears to be an auth/login screen.
  ///
  /// `true` when at least one text field or login button was detected.
  final bool isAuthScreen;

  /// Creates a result with detected elements and generated stratagem.
  AuthStratagemResult({
    required this.textFields,
    required this.loginButtons,
    required this.authStratagem,
  }) : isAuthScreen = true;

  /// Creates a result indicating no auth screen was detected.
  AuthStratagemResult.noAuthScreen()
    : textFields = const [],
      loginButtons = const [],
      authStratagem = null,
      isAuthScreen = false;
}

/// **AuthStratagemGenerator** — analyzes Tableau glyph data to
/// auto-generate `authStratagem` JSON for Campaign-based testing.
///
/// Inspects the compact glyph maps from the Relay `/blueprint`
/// endpoint (or from [Glyph.toMap]) and detects:
///
/// - **Text fields**: Interactive elements with `interactionType`
///   of `'textInput'` or `widgetType` of `'TextField'` /
///   `'TextFormField'`.
/// - **Login buttons**: Interactive tap/button elements whose labels
///   match common login indicators (sign in, log in, enter, etc.).
///
/// ## Usage
///
/// ```dart
/// // From Relay /blueprint response:
/// final data = jsonDecode(body) as Map<String, dynamic>;
/// final glyphs =
///     (data['currentTableau']?['glyphs'] as List<dynamic>?) ?? [];
///
/// final generator = AuthStratagemGenerator();
/// final result = generator.generate(glyphs, defaultValue: 'Kael');
///
/// if (result.isAuthScreen) {
///   // Embed in Campaign JSON
///   campaignJson['authStratagem'] = result.authStratagem;
/// }
/// ```
///
/// Works with any auth screen — Argus, Firebase, custom OAuth, etc.
class AuthStratagemGenerator {
  /// Creates an [AuthStratagemGenerator].
  const AuthStratagemGenerator();

  /// Login indicator labels — if a glyph's label contains one of these
  /// (case-insensitive), it is likely a login button.
  ///
  /// Covers common variants across locales and frameworks:
  /// `'sign in'`, `'log in'`, `'login'`, `'enter'`, `'submit'`,
  /// `'continue'`, `'get started'`.
  static const loginButtonIndicators = [
    'sign in',
    'log in',
    'login',
    'enter',
    'submit',
    'continue',
    'get started',
  ];

  /// Analyze [glyphs] and generate an `authStratagem`.
  ///
  /// [glyphs] should be the `currentTableau.glyphs` array from
  /// the Relay `/blueprint` response (compact glyph maps).
  ///
  /// [defaultValue] is the placeholder text used for detected
  /// text fields. Defaults to `'<fill_in_value>'`.
  ///
  /// Returns an [AuthStratagemResult] that is either:
  /// - An auth screen result with [AuthStratagemResult.isAuthScreen]
  ///   `true`, containing the generated JSON.
  /// - A no-auth-screen result when no text fields or login buttons
  ///   are found.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = const AuthStratagemGenerator().generate(
  ///   glyphs,
  ///   defaultValue: 'Kael',
  /// );
  ///
  /// if (result.isAuthScreen) {
  ///   print('Found ${result.textFields.length} text fields');
  ///   print('Found ${result.loginButtons.length} login buttons');
  ///   print(jsonEncode(result.authStratagem));
  /// }
  /// ```
  AuthStratagemResult generate(
    List<dynamic> glyphs, {
    String defaultValue = '<fill_in_value>',
  }) {
    // 1. Find interactive text fields
    final textFields = <Map<String, dynamic>>[];
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final isInteractive = glyph['ia'] == true;
      final interactionType = glyph['it'] as String? ?? '';
      final label = glyph['l'] as String? ?? '';
      final widgetType = glyph['wt'] as String? ?? '';

      if (isInteractive &&
          label.isNotEmpty &&
          (interactionType == 'textInput' ||
              widgetType == 'TextField' ||
              widgetType == 'TextFormField')) {
        // Deduplicate by label
        if (!textFields.any((t) => t['l'] == label)) {
          textFields.add(glyph);
        }
      }
    }

    // 2. Find login buttons (interactive with login-related labels)
    final loginButtons = <Map<String, dynamic>>[];
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final isInteractive = glyph['ia'] == true;
      final interactionType = glyph['it'] as String? ?? '';
      final label = glyph['l'] as String? ?? '';
      final semanticRole = glyph['sr'] as String? ?? '';

      if (isInteractive &&
          label.isNotEmpty &&
          (interactionType == 'tap' || semanticRole == 'button') &&
          isLoginButton(label)) {
        // Deduplicate by label
        if (!loginButtons.any((b) => b['l'] == label)) {
          loginButtons.add(glyph);
        }
      }
    }

    if (textFields.isEmpty && loginButtons.isEmpty) {
      return AuthStratagemResult.noAuthScreen();
    }

    // 3. Build authStratagem steps
    final steps = <Map<String, dynamic>>[];
    var stepId = 1;

    for (final field in textFields) {
      steps.add({
        'id': stepId++,
        'action': 'enterText',
        'target': {'label': field['l']},
        'value': defaultValue,
        'description': 'Enter value in "${field['l']}" field',
      });
    }

    for (final button in loginButtons) {
      steps.add({
        'id': stepId++,
        'action': 'tap',
        'target': {'label': button['l']},
        'description': 'Tap "${button['l']}" button',
      });
    }

    // 4. Build the complete authStratagem
    final authStratagem = {
      'name': '_auth',
      'description': 'Auto-login — generated from live screen',
      'startRoute': '',
      'steps': steps,
    };

    return AuthStratagemResult(
      textFields: textFields,
      loginButtons: loginButtons,
      authStratagem: authStratagem,
    );
  }

  /// Check if [label] looks like a login button.
  ///
  /// Performs a case-insensitive check against
  /// [loginButtonIndicators].
  ///
  /// ```dart
  /// const gen = AuthStratagemGenerator();
  /// gen.isLoginButton('Sign In');   // true
  /// gen.isLoginButton('Cancel');    // false
  /// gen.isLoginButton('Log In');    // true
  /// gen.isLoginButton('ENTER');     // true
  /// ```
  bool isLoginButton(String label) {
    final lower = label.toLowerCase();
    return loginButtonIndicators.any((ind) => lower.contains(ind));
  }
}
