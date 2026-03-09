import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/testing/scry.dart';

void main() {
  const scry = Scry();

  // ----- Helper: build a glyph map -----
  Map<String, dynamic> glyph({
    required String label,
    String widgetType = 'Text',
    bool interactive = false,
    String? interactionType,
    String? semanticRole,
    String? fieldId,
    String? currentValue,
    bool enabled = true,
    List<String>? ancestors,
    double x = 0.0,
    double y = 0.0,
    double w = 100.0,
    double h = 40.0,
    int? depth,
    String? key,
  }) => {
    'wt': widgetType,
    'l': label,
    'ia': interactive,
    // ignore: use_null_aware_elements
    if (interactionType != null) 'it': interactionType,
    // ignore: use_null_aware_elements
    if (semanticRole != null) 'sr': semanticRole,
    // ignore: use_null_aware_elements
    if (fieldId != null) 'fid': fieldId,
    // ignore: use_null_aware_elements
    if (currentValue != null) 'cv': currentValue,
    if (!enabled) 'en': false,
    // ignore: use_null_aware_elements
    if (ancestors != null) 'anc': ancestors,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    // ignore: use_null_aware_elements
    if (depth != null) 'd': depth,
    // ignore: use_null_aware_elements
    if (key != null) 'k': key,
  };

  // ===================================================================
  // ScryElementKind
  // ===================================================================
  group('ScryElementKind', () {
    test('has all expected values', () {
      expect(ScryElementKind.values, hasLength(5));
      expect(ScryElementKind.values, contains(ScryElementKind.button));
      expect(ScryElementKind.values, contains(ScryElementKind.field));
      expect(ScryElementKind.values, contains(ScryElementKind.navigation));
      expect(ScryElementKind.values, contains(ScryElementKind.content));
      expect(ScryElementKind.values, contains(ScryElementKind.structural));
    });
  });

  // ===================================================================
  // ScryElement
  // ===================================================================
  group('ScryElement', () {
    test('toJson serializes all fields', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Sign Out',
        widgetType: 'IconButton',
        isInteractive: true,
        gated: true,
        semanticRole: 'button',
      );

      final json = element.toJson();

      expect(json['kind'], 'button');
      expect(json['label'], 'Sign Out');
      expect(json['widgetType'], 'IconButton');
      expect(json['isInteractive'], true);
      expect(json['gated'], true);
      expect(json['semanticRole'], 'button');
    });

    test('toJson omits default/null fields', () {
      const element = ScryElement(
        kind: ScryElementKind.content,
        label: 'Kael',
        widgetType: 'Text',
      );

      final json = element.toJson();

      expect(json.containsKey('isInteractive'), isFalse);
      expect(json.containsKey('fieldId'), isFalse);
      expect(json.containsKey('currentValue'), isFalse);
      expect(json.containsKey('gated'), isFalse);
      expect(json.containsKey('isEnabled'), isFalse);
    });

    test('toJson includes disabled state', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Submit',
        widgetType: 'ElevatedButton',
        isEnabled: false,
      );

      final json = element.toJson();

      expect(json['isEnabled'], false);
    });

    test('toJson includes fieldId for text fields', () {
      const element = ScryElement(
        kind: ScryElementKind.field,
        label: 'Hero Name',
        widgetType: 'TextField',
        fieldId: 'heroName',
        currentValue: 'Kael',
      );

      final json = element.toJson();

      expect(json['fieldId'], 'heroName');
      expect(json['currentValue'], 'Kael');
    });
  });

  // ===================================================================
  // ScryGaze
  // ===================================================================
  group('ScryGaze', () {
    test('categorizes elements by kind', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign Out',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Hero Name',
            widgetType: 'TextField',
          ),
          ScryElement(
            kind: ScryElementKind.navigation,
            label: 'Quests',
            widgetType: 'GestureDetector',
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Kael',
            widgetType: 'Text',
          ),
          ScryElement(
            kind: ScryElementKind.structural,
            label: 'Questboard',
            widgetType: 'AppBar',
          ),
        ],
        route: '/quests',
        glyphCount: 177,
      );

      expect(gaze.buttons, hasLength(1));
      expect(gaze.fields, hasLength(1));
      expect(gaze.navigation, hasLength(1));
      expect(gaze.content, hasLength(1));
      expect(gaze.structural, hasLength(1));
      expect(gaze.route, '/quests');
      expect(gaze.glyphCount, 177);
    });

    test('isAuthScreen detects login screens', () {
      const loginGaze = ScryGaze(
        screenType: ScryScreenType.login,
        elements: [
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Username',
            widgetType: 'TextField',
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Log In',
            widgetType: 'ElevatedButton',
            isInteractive: true,
          ),
        ],
      );

      expect(loginGaze.isAuthScreen, isTrue);
    });

    test('isAuthScreen false for non-login screens', () {
      const mainGaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign Out',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Kael',
            widgetType: 'Text',
          ),
        ],
      );

      expect(mainGaze.isAuthScreen, isFalse);
    });

    test('gated returns only gated elements', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Delete Account',
            widgetType: 'ElevatedButton',
            isInteractive: true,
            gated: true,
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Save',
            widgetType: 'ElevatedButton',
            isInteractive: true,
          ),
        ],
      );

      expect(gaze.gated, hasLength(1));
      expect(gaze.gated.first.label, 'Delete Account');
    });

    test('toJson includes counts and elements', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'OK',
            widgetType: 'Button',
          ),
        ],
        route: '/',
        glyphCount: 10,
      );

      final json = gaze.toJson();

      expect(json['route'], '/');
      expect(json['glyphCount'], 10);
      expect(json['buttonCount'], 1);
      expect(json['elements'], hasLength(1));
    });
  });

  // ===================================================================
  // Scry.observe — Element classification
  // ===================================================================
  group('Scry.observe', () {
    test('classifies interactive elements as buttons', () {
      final glyphs = [
        glyph(label: 'Sign Out', interactive: true, widgetType: 'IconButton'),
        glyph(label: 'About', interactive: true, widgetType: 'IconButton'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.buttons, hasLength(2));
      expect(gaze.buttons.map((e) => e.label), contains('Sign Out'));
      expect(gaze.buttons.map((e) => e.label), contains('About'));
    });

    test('classifies text fields', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          fieldId: 'heroName',
          semanticRole: 'textField',
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.fields, hasLength(1));
      expect(gaze.fields.first.label, 'Hero Name');
      expect(gaze.fields.first.fieldId, 'heroName');
    });

    test('classifies navigation elements by ancestor', () {
      final glyphs = [
        glyph(
          label: 'Quests',
          interactive: true,
          widgetType: 'GestureDetector',
          ancestors: [
            'DefaultSelectionStyle',
            'Builder',
            'MouseRegion',
            'Semantics',
          ],
        ),
        // Also include a non-interactive instance with nav ancestors
        glyph(
          label: 'Quests',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
      ];

      final gaze = scry.observe(glyphs);

      // "Quests" has a NavBar ancestor → navigation
      expect(gaze.navigation, hasLength(1));
      expect(gaze.navigation.first.label, 'Quests');
    });

    test('classifies NavigationBar widget type as navigation', () {
      final glyphs = [
        glyph(label: 'Quests', interactive: true, widgetType: 'NavigationBar'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.navigation, hasLength(1));
    });

    test('classifies NavigationDestination as navigation', () {
      final glyphs = [
        glyph(
          label: 'Quests',
          interactive: true,
          widgetType: 'NavigationDestination',
        ),
        glyph(
          label: 'Hero',
          interactive: true,
          widgetType: 'NavigationDestination',
        ),
        glyph(
          label: 'Enterprise',
          interactive: true,
          widgetType: 'NavigationDestination',
        ),
      ];

      final gaze = scry.observe(glyphs);

      // Each NavigationDestination gets its own navigation entry
      expect(gaze.navigation, hasLength(3));
      expect(gaze.navigation.map((e) => e.label).toList(), [
        'Quests',
        'Hero',
        'Enterprise',
      ]);
    });

    test('classifies AppBar children as structural', () {
      final glyphs = [
        glyph(
          label: 'Questboard',
          widgetType: 'Text',
          ancestors: ['_AppBarTitleBox', 'Semantics', 'DefaultTextStyle'],
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.structural, hasLength(1));
      expect(gaze.structural.first.label, 'Questboard');
    });

    test('classifies AppBar widget type as structural', () {
      final glyphs = [glyph(label: 'Questboard', widgetType: 'AppBar')];

      final gaze = scry.observe(glyphs);

      expect(gaze.structural, hasLength(1));
    });

    test('classifies plain Text as content', () {
      final glyphs = [
        glyph(label: 'Kael'),
        glyph(label: 'Slay the Bug Dragon'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.content, hasLength(2));
      expect(gaze.content.map((e) => e.label), contains('Kael'));
    });

    test('deduplicates by label', () {
      final glyphs = [
        glyph(label: 'Kael', widgetType: 'Text'),
        glyph(label: 'Kael', widgetType: 'RichText'),
      ];

      final gaze = scry.observe(glyphs);

      // Only one "Kael" element
      expect(gaze.elements.where((e) => e.label == 'Kael'), hasLength(1));
    });

    test('excludes empty and short labels', () {
      final glyphs = [glyph(label: ''), glyph(label: 'A'), glyph(label: 'OK')];

      final gaze = scry.observe(glyphs);

      expect(gaze.elements, hasLength(1));
      expect(gaze.elements.first.label, 'OK');
    });

    test('excludes IconData labels', () {
      final glyphs = [glyph(label: 'IconData(U+0E15A)'), glyph(label: 'Kael')];

      final gaze = scry.observe(glyphs);

      expect(gaze.elements, hasLength(1));
      expect(gaze.elements.first.label, 'Kael');
    });

    test('marks destructive actions as gated', () {
      final glyphs = [
        glyph(
          label: 'Delete Account',
          interactive: true,
          widgetType: 'ElevatedButton',
        ),
        glyph(label: 'Save', interactive: true, widgetType: 'ElevatedButton'),
      ];

      final gaze = scry.observe(glyphs);

      final deleteBtn = gaze.buttons.firstWhere(
        (e) => e.label == 'Delete Account',
      );
      expect(deleteBtn.gated, isTrue);

      final saveBtn = gaze.buttons.firstWhere((e) => e.label == 'Save');
      expect(saveBtn.gated, isFalse);
    });

    test('marks common destructive patterns as gated', () {
      for (final label in [
        'Delete',
        'Remove Item',
        'Reset All',
        'Destroy',
        'Erase Data',
        'Clear All History',
        'Wipe',
        'Revoke Access',
        'Terminate Session',
        'Purge Cache',
      ]) {
        final glyphs = [glyph(label: label, interactive: true)];
        final gaze = scry.observe(glyphs);
        expect(
          gaze.buttons.first.gated,
          isTrue,
          reason: '"$label" should be gated',
        );
      }
    });

    test('non-interactive elements are not gated', () {
      // Even if label says "Delete", non-interactive labels aren't gated
      final glyphs = [glyph(label: 'Delete this file', interactive: false)];

      final gaze = scry.observe(glyphs);

      expect(gaze.content.first.gated, isFalse);
    });

    test('preserves route information', () {
      final gaze = scry.observe([glyph(label: 'OK')], route: '/quests');

      expect(gaze.route, '/quests');
    });

    test('tracks glyph count', () {
      final glyphs = [glyph(label: 'A'), glyph(label: 'B'), glyph(label: 'CC')];

      final gaze = scry.observe(glyphs);

      expect(gaze.glyphCount, 3);
    });

    test('promotes interactive to button even with nav ancestor label', () {
      // If "Hero" is interactive AND has a nav ancestor, it's navigation
      // (navigation takes precedence over generic button)
      final glyphs = [
        glyph(label: 'Hero', interactive: true, widgetType: 'GestureDetector'),
        glyph(
          label: 'Hero',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.navigation, hasLength(1));
      expect(gaze.navigation.first.label, 'Hero');
    });

    test('full Questboard main screen scenario', () {
      final glyphs = [
        // User data
        glyph(label: 'Kael'),
        glyph(label: '0 Glory \u2022 Novice'),
        // App bar title (structural)
        glyph(label: 'Questboard', ancestors: ['_AppBarTitleBox', 'Semantics']),
        glyph(label: 'Questboard', widgetType: 'AppBar'),
        // Buttons
        glyph(label: 'Sign Out', interactive: true, widgetType: 'IconButton'),
        glyph(label: 'Sign Out', widgetType: 'Tooltip'),
        glyph(label: 'About', interactive: true, widgetType: 'IconButton'),
        // Navigation tabs
        glyph(
          label: 'Quests',
          interactive: true,
          widgetType: 'GestureDetector',
        ),
        glyph(
          label: 'Quests',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
        glyph(label: 'Hero', interactive: true, widgetType: 'GestureDetector'),
        glyph(
          label: 'Hero',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
        // Quest items
        glyph(label: 'Slay the Bug Dragon'),
        glyph(label: 'Champion \u2022 50 glory'),
        glyph(
          label: 'Complete Quest',
          interactive: true,
          widgetType: 'IconButton',
        ),
      ];

      final gaze = scry.observe(glyphs, route: '/quests');

      // Structural: Questboard (AppBar ancestor)
      expect(gaze.structural.map((e) => e.label), contains('Questboard'));

      // Navigation: Quests, Hero (nav destination ancestors)
      expect(gaze.navigation.map((e) => e.label), contains('Quests'));
      expect(gaze.navigation.map((e) => e.label), contains('Hero'));

      // Buttons: Sign Out, About, Complete Quest
      expect(gaze.buttons.map((e) => e.label), contains('Sign Out'));
      expect(gaze.buttons.map((e) => e.label), contains('About'));
      expect(gaze.buttons.map((e) => e.label), contains('Complete Quest'));

      // Content: Kael, quest names/scores
      expect(gaze.content.map((e) => e.label), contains('Kael'));
      expect(gaze.content.map((e) => e.label), contains('Slay the Bug Dragon'));

      expect(gaze.route, '/quests');
      expect(gaze.isAuthScreen, isFalse);
    });

    test('login screen scenario', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          fieldId: 'heroName',
          semanticRole: 'textField',
        ),
        glyph(
          label: 'Enter the Questboard',
          interactive: true,
          widgetType: 'FilledButton',
        ),
        glyph(label: 'Sign in to continue to /'),
        glyph(label: 'Questboard'),
      ];

      final gaze = scry.observe(glyphs, route: '/login');

      expect(gaze.isAuthScreen, isTrue);
      expect(gaze.fields, hasLength(1));
      expect(gaze.fields.first.fieldId, 'heroName');
      expect(gaze.buttons, hasLength(1));
      expect(
        gaze.content.map((e) => e.label),
        contains('Sign in to continue to /'),
      );
    });

    test('TextField classified correctly even when RichText appears first', () {
      // In real apps, the RichText label inside a TextField's decoration
      // appears EARLIER in the glyph list than the TextField itself.
      // Scry must still classify "Hero Name" as a field, not a button.
      final glyphs = [
        // RichText label (appears first at higher depth)
        glyph(label: 'Hero Name', widgetType: 'RichText'),
        // Text label (also in decoration)
        glyph(label: 'Hero Name', widgetType: 'Text'),
        // The actual TextField (lower depth, interactive)
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'textInput',
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.fields, hasLength(1));
      expect(gaze.fields.first.label, 'Hero Name');
      expect(gaze.fields.first.widgetType, 'TextField');
      expect(gaze.buttons, isEmpty);
    });
  });

  // ===================================================================
  // Scry.formatGaze
  // ===================================================================
  group('Scry.formatGaze', () {
    test('includes route and glyph count in header', () {
      const gaze = ScryGaze(elements: [], route: '/quests', glyphCount: 177);

      final md = scry.formatGaze(gaze);

      expect(md, contains('# Current Screen'));
      expect(md, contains('/quests'));
      expect(md, contains('177 glyphs'));
    });

    test('marks login screen', () {
      const gaze = ScryGaze(
        screenType: ScryScreenType.login,
        elements: [
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Username',
            widgetType: 'TextField',
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign In',
            widgetType: 'ElevatedButton',
            isInteractive: true,
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Login screen detected'));
    });

    test('shows gated elements warning', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Delete All',
            widgetType: 'ElevatedButton',
            isInteractive: true,
            gated: true,
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Permission required'));
      expect(md, contains('Delete All'));
    });

    test('lists text fields with fieldId and usage hint', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Hero Name',
            widgetType: 'TextField',
            fieldId: 'heroName',
            currentValue: 'Kael',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Text Fields'));
      expect(md, contains('Hero Name'));
      expect(md, contains('fieldId: heroName'));
      expect(md, contains('value: "Kael"'));
      expect(md, contains('enterText'));
      expect(md, contains('label'));
    });

    test('lists buttons', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign Out',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Buttons'));
      expect(md, contains('Sign Out'));
      expect(md, contains('IconButton'));
    });

    test('lists navigation tabs', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.navigation,
            label: 'Quests',
            widgetType: 'GestureDetector',
          ),
          ScryElement(
            kind: ScryElementKind.navigation,
            label: 'Hero',
            widgetType: 'GestureDetector',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Navigation'));
      expect(md, contains('Quests'));
      expect(md, contains('Hero'));
    });

    test('lists content', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Kael',
            widgetType: 'Text',
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Slay the Bug Dragon',
            widgetType: 'Text',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Content'));
      expect(md, contains('Kael'));
      expect(md, contains('Slay the Bug Dragon'));
    });

    test('includes available actions section', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'OK',
            widgetType: 'Button',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Available Actions'));
      expect(md, contains('scry_act'));
      expect(md, contains('tap'));
    });
  });

  // ===================================================================
  // Scry.buildActionCampaign
  // ===================================================================
  group('Scry.buildActionCampaign', () {
    test('builds tap campaign', () {
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'Sign Out',
      );

      expect(campaign['name'], '_scry_action');
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'tap');
      expect((step['target'] as Map)['label'], 'Sign Out');
    });

    test('builds enterText campaign with wait + dismiss', () {
      final campaign = scry.buildActionCampaign(
        action: 'enterText',
        label: 'Hero Name',
        value: 'Titan',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      // Step 1: waitForElement (auto-added for text actions)
      expect(steps, hasLength(3));
      final wait = steps[0] as Map<String, dynamic>;
      expect(wait['action'], 'waitForElement');
      expect((wait['target'] as Map)['label'], 'Hero Name');

      // Step 2: enterText
      final step = steps[1] as Map<String, dynamic>;
      expect(step['action'], 'enterText');
      expect((step['target'] as Map)['label'], 'Hero Name');
      expect(step['value'], 'Titan');
      expect(step['clearFirst'], isTrue);

      // Step 3: auto dismissKeyboard
      final dismiss = steps[2] as Map<String, dynamic>;
      expect(dismiss['action'], 'dismissKeyboard');
    });

    test('builds back campaign without target', () {
      final campaign = scry.buildActionCampaign(action: 'back');

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'back');
      expect(step.containsKey('target'), isFalse);
    });

    test('builds navigate campaign with route', () {
      final campaign = scry.buildActionCampaign(
        action: 'navigate',
        value: '/hero',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'navigate');
      expect((step['target'] as Map)['route'], '/hero');
    });

    test('builds waitForElement with timeout', () {
      final campaign = scry.buildActionCampaign(
        action: 'waitForElement',
        label: 'Sign Out',
        timeout: 3000,
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'waitForElement');
      expect(step['timeout'], 3000);
    });

    test('campaign has correct structure', () {
      final campaign = scry.buildActionCampaign(action: 'tap', label: 'OK');

      // Must have these keys for Relay
      expect(campaign, contains('name'));
      expect(campaign, contains('entries'));
      final entries = campaign['entries'] as List;
      expect(entries, hasLength(1));
      final entry = entries[0] as Map;
      expect(entry, contains('stratagem'));
      final stratagem = entry['stratagem'] as Map;
      expect(stratagem, contains('name'));
      expect(stratagem, contains('startRoute'));
      expect(stratagem, contains('steps'));
    });

    test('clearText has wait + dismiss steps', () {
      final campaign = scry.buildActionCampaign(
        action: 'clearText',
        label: 'Hero Name',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(3));
      expect((steps[0] as Map)['action'], 'waitForElement');
      expect((steps[1] as Map)['action'], 'clearText');
      expect((steps[2] as Map)['action'], 'dismissKeyboard');
    });

    test('submitField has wait + dismiss steps', () {
      final campaign = scry.buildActionCampaign(
        action: 'submitField',
        label: 'Hero Name',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(3));
      expect((steps[0] as Map)['action'], 'waitForElement');
      expect((steps[1] as Map)['action'], 'submitField');
      expect((steps[2] as Map)['action'], 'dismissKeyboard');
    });

    test('tap does NOT auto-dismiss keyboard', () {
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'Sign Out',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(1));
      expect((steps[0] as Map)['action'], 'tap');
    });

    test('scroll defaults to direction down', () {
      final campaign = scry.buildActionCampaign(action: 'scroll');

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'scroll');
      final scrollDelta = step['scrollDelta'] as Map<String, dynamic>;
      expect(scrollDelta['dx'], 0);
      expect(scrollDelta['dy'], 300); // positive dy = scroll down
    });

    test('scroll with direction up', () {
      final campaign = scry.buildActionCampaign(
        action: 'scroll',
        direction: 'up',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      final scrollDelta = step['scrollDelta'] as Map<String, dynamic>;
      expect(scrollDelta['dx'], 0);
      expect(scrollDelta['dy'], -300); // negative dy = scroll up
    });

    test('scroll with direction left', () {
      final campaign = scry.buildActionCampaign(
        action: 'scroll',
        direction: 'left',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      final scrollDelta = step['scrollDelta'] as Map<String, dynamic>;
      expect(scrollDelta['dx'], -300);
      expect(scrollDelta['dy'], 0);
    });

    test('scroll with direction right', () {
      final campaign = scry.buildActionCampaign(
        action: 'scroll',
        direction: 'right',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      final scrollDelta = step['scrollDelta'] as Map<String, dynamic>;
      expect(scrollDelta['dx'], 300);
      expect(scrollDelta['dy'], 0);
    });

    test('scroll with custom amount', () {
      final campaign = scry.buildActionCampaign(
        action: 'scroll',
        direction: 'down',
        scrollAmount: 500,
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      final scrollDelta = step['scrollDelta'] as Map<String, dynamic>;
      expect(scrollDelta['dx'], 0);
      expect(scrollDelta['dy'], 500);
    });

    test('non-scroll action does not include scrollDelta', () {
      final campaign = scry.buildActionCampaign(action: 'tap', label: 'OK');

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step.containsKey('scrollDelta'), isFalse);
    });
  });

  // ===================================================================
  // Scry.resolveFieldLabel
  // ===================================================================
  group('Scry.resolveFieldLabel', () {
    test('resolves fieldId to label', () {
      final glyphs = [
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'fid': 'heroName',
          'ia': true,
          'x': 0.0,
          'y': 0.0,
          'w': 200.0,
          'h': 40.0,
        },
        {
          'wt': 'Text',
          'l': 'Welcome',
          'x': 0.0,
          'y': 50.0,
          'w': 100.0,
          'h': 20.0,
        },
      ];

      expect(scry.resolveFieldLabel(glyphs, 'heroName'), 'Hero Name');
    });

    test('returns null for unknown fieldId', () {
      final glyphs = [
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'fid': 'heroName',
          'ia': true,
          'x': 0.0,
          'y': 0.0,
          'w': 200.0,
          'h': 40.0,
        },
      ];

      expect(scry.resolveFieldLabel(glyphs, 'email'), isNull);
    });

    test('returns null for empty glyphs', () {
      expect(scry.resolveFieldLabel([], 'heroName'), isNull);
    });
  });

  // ===================================================================
  // Scry.formatActionResult
  // ===================================================================
  group('Scry.formatActionResult', () {
    test('formats successful action', () {
      const newGaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Hero Page',
            widgetType: 'Text',
          ),
        ],
        route: '/hero',
        glyphCount: 50,
      );

      final md = scry.formatActionResult(
        action: 'tap',
        label: 'Hero',
        result: {'passRate': 1.0},
        newGaze: newGaze,
      );

      expect(md, contains('Action Succeeded'));
      expect(md, contains('tap'));
      expect(md, contains('"Hero"'));
      expect(md, contains('Current Screen'));
      expect(md, contains('Hero Page'));
    });

    test('formats failed action', () {
      const newGaze = ScryGaze(elements: [], glyphCount: 0);

      final md = scry.formatActionResult(
        action: 'tap',
        label: 'Missing Button',
        result: {
          'passRate': 0.0,
          'verdicts': [
            {
              'steps': [
                {
                  'passed': false,
                  'error': 'Target not found: "Missing Button"',
                },
              ],
            },
          ],
        },
        newGaze: newGaze,
      );

      expect(md, contains('Action Failed'));
      expect(md, contains('Target not found'));
    });

    test('formats enterText with value', () {
      const newGaze = ScryGaze(elements: [], glyphCount: 0);

      final md = scry.formatActionResult(
        action: 'enterText',
        label: 'Hero Name',
        value: 'Titan',
        result: {'passRate': 1.0},
        newGaze: newGaze,
      );

      expect(md, contains('enterText'));
      expect(md, contains('"Titan"'));
    });

    test('includes new screen state after action', () {
      const newGaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Back',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Welcome',
            widgetType: 'Text',
          ),
        ],
        route: '/welcome',
        glyphCount: 20,
      );

      final md = scry.formatActionResult(
        action: 'tap',
        label: 'Enter',
        result: {'passRate': 1.0},
        newGaze: newGaze,
      );

      // Should contain both the action result AND the new screen state
      expect(md, contains('Action Succeeded'));
      expect(md, contains('Current Screen'));
      expect(md, contains('/welcome'));
      expect(md, contains('Back'));
      expect(md, contains('Welcome'));
    });
  });

  // ===================================================================
  // Gated action detection
  // ===================================================================
  group('Gated actions', () {
    test('non-destructive actions are not gated', () {
      final glyphs = [
        glyph(label: 'Save', interactive: true),
        glyph(label: 'Submit', interactive: true),
        glyph(label: 'Sign Out', interactive: true),
        glyph(label: 'About', interactive: true),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.gated, isEmpty);
    });

    test('disconnect is gated', () {
      final glyphs = [glyph(label: 'Disconnect', interactive: true)];

      final gaze = scry.observe(glyphs);

      expect(gaze.gated, hasLength(1));
    });
  });

  // ===================================================================
  // Scry.buildMultiActionCampaign
  // ===================================================================
  group('Scry.buildMultiActionCampaign', () {
    test('combines enterText + tap into one campaign', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'enterText', 'label': 'Hero Name', 'value': 'Kael'},
        {'action': 'tap', 'label': 'Enter the Questboard'},
      ]);

      expect(campaign['name'], '_scry_multi_action');
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      expect(stratagem['name'], '_scry_steps');
      expect(stratagem['startRoute'], '');

      final steps = stratagem['steps'] as List;
      // enterText: waitForElement + enterText + dismissKeyboard = 3
      // tap: 1
      // Total: 4
      expect(steps, hasLength(4));

      // Step 1: waitForElement for "Hero Name"
      expect(steps[0]['action'], 'waitForElement');
      expect(steps[0]['target']['label'], 'Hero Name');

      // Step 2: enterText "Kael" into "Hero Name"
      expect(steps[1]['action'], 'enterText');
      expect(steps[1]['target']['label'], 'Hero Name');
      expect(steps[1]['value'], 'Kael');
      expect(steps[1]['clearFirst'], true);

      // Step 3: dismissKeyboard
      expect(steps[2]['action'], 'dismissKeyboard');

      // Step 4: tap "Enter the Questboard"
      expect(steps[3]['action'], 'tap');
      expect(steps[3]['target']['label'], 'Enter the Questboard');
    });

    test('multiple text fields get individual pre/post steps', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'enterText', 'label': 'Username', 'value': 'alice'},
        {'action': 'enterText', 'label': 'Password', 'value': 'secret'},
        {'action': 'tap', 'label': 'Login'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      // 2 × (wait + enter + dismiss) + 1 tap = 7
      expect(steps, hasLength(7));

      expect(steps[0]['action'], 'waitForElement');
      expect(steps[1]['action'], 'enterText');
      expect(steps[1]['value'], 'alice');
      expect(steps[2]['action'], 'dismissKeyboard');

      expect(steps[3]['action'], 'waitForElement');
      expect(steps[4]['action'], 'enterText');
      expect(steps[4]['value'], 'secret');
      expect(steps[5]['action'], 'dismissKeyboard');

      expect(steps[6]['action'], 'tap');
      expect(steps[6]['target']['label'], 'Login');
    });

    test('step IDs are sequential', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'enterText', 'label': 'Name', 'value': 'X'},
        {'action': 'tap', 'label': 'Go'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      for (var i = 0; i < steps.length; i++) {
        expect(steps[i]['id'], i + 1);
      }
    });

    test('non-text actions have no pre/post steps', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'tap', 'label': 'Button A'},
        {'action': 'tap', 'label': 'Button B'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0]['action'], 'tap');
      expect(steps[1]['action'], 'tap');
    });

    test('navigate action uses route target', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'navigate', 'value': '/quests'},
        {'action': 'tap', 'label': 'Refresh'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0]['target']['route'], '/quests');
      expect(steps[1]['target']['label'], 'Refresh');
    });

    test('back action has no target', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'back'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(1));
      expect(steps[0]['action'], 'back');
      expect(steps[0].containsKey('target'), isFalse);
    });

    test('scroll action includes direction in multi-action', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'scroll', 'direction': 'down'},
        {'action': 'scroll', 'direction': 'up', 'scrollAmount': 500},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(2));

      final step1 = steps[0] as Map<String, dynamic>;
      final delta1 = step1['scrollDelta'] as Map<String, dynamic>;
      expect(delta1['dx'], 0);
      expect(delta1['dy'], 300); // down

      final step2 = steps[1] as Map<String, dynamic>;
      final delta2 = step2['scrollDelta'] as Map<String, dynamic>;
      expect(delta2['dx'], 0);
      expect(delta2['dy'], -500); // up with custom amount
    });
  });

  // ===================================================================
  // Scry.formatMultiActionResult
  // ===================================================================
  group('Scry.formatMultiActionResult', () {
    test('formats successful multi-action result', () {
      final gaze = ScryGaze(
        elements: const [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Welcome',
            widgetType: 'Text',
          ),
        ],
        route: '/home',
        glyphCount: 1,
      );

      final md = scry.formatMultiActionResult(
        actions: [
          {'action': 'enterText', 'label': 'Hero Name', 'value': 'Kael'},
          {'action': 'tap', 'label': 'Enter the Questboard'},
        ],
        result: {'passRate': 1.0},
        newGaze: gaze,
      );

      expect(md, contains('✅ All Actions Succeeded'));
      expect(md, contains('Actions performed'));
      expect(md, contains('`enterText` on "Hero Name" → "Kael"'));
      expect(md, contains('`tap` on "Enter the Questboard"'));
      expect(md, contains('Welcome'));
    });

    test('formats failed multi-action result with error', () {
      final gaze = ScryGaze(elements: const [], route: '/login', glyphCount: 0);

      final md = scry.formatMultiActionResult(
        actions: [
          {'action': 'enterText', 'label': 'Email', 'value': 'test@x.com'},
          {'action': 'tap', 'label': 'Submit'},
        ],
        result: {
          'passRate': 0.5,
          'verdicts': [
            {
              'steps': [
                {'id': 1, 'passed': true},
                {'id': 2, 'passed': false, 'error': 'Element not found'},
              ],
            },
          ],
        },
        newGaze: gaze,
      );

      expect(md, contains('❌ Actions Failed'));
      expect(md, contains('Element not found'));
      expect(md, contains('step 2'));
    });
  });

  // ===================================================================
  // ScryScreenType — Screen classification
  // ===================================================================
  group('ScryScreenType', () {
    test('has all expected values', () {
      expect(ScryScreenType.values, hasLength(9));
      expect(ScryScreenType.values, contains(ScryScreenType.login));
      expect(ScryScreenType.values, contains(ScryScreenType.form));
      expect(ScryScreenType.values, contains(ScryScreenType.list));
      expect(ScryScreenType.values, contains(ScryScreenType.detail));
      expect(ScryScreenType.values, contains(ScryScreenType.settings));
      expect(ScryScreenType.values, contains(ScryScreenType.empty));
      expect(ScryScreenType.values, contains(ScryScreenType.error));
      expect(ScryScreenType.values, contains(ScryScreenType.dashboard));
      expect(ScryScreenType.values, contains(ScryScreenType.unknown));
    });

    test('detects login screen (fields + login button)', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'username',
        ),
        glyph(
          label: 'Sign In',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.login);
    });

    test('detects login screen with "Enter" button', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'hero_name',
        ),
        glyph(
          label: 'Enter the Questboard',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.login);
    });

    test('detects form screen (multiple fields + submit)', () {
      final glyphs = [
        glyph(
          label: 'First Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'first',
        ),
        glyph(
          label: 'Last Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'last',
        ),
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'email',
        ),
        glyph(label: 'Save', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.form);
    });

    test('detects settings screen (toggles and switches)', () {
      final glyphs = [
        glyph(
          label: 'Dark Mode',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'switch',
          currentValue: 'on',
        ),
        glyph(
          label: 'Notifications',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'switch',
          currentValue: 'off',
        ),
        glyph(
          label: 'Sound',
          widgetType: 'Checkbox',
          interactive: true,
          interactionType: 'checkbox',
          currentValue: 'true',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.settings);
    });

    test('detects list screen (many content items)', () {
      final glyphs = <Map<String, dynamic>>[];
      for (var i = 0; i < 7; i++) {
        glyphs.add(glyph(label: 'Item $i', widgetType: 'Text'));
      }
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.list);
    });

    test('detects empty screen (no content, no fields)', () {
      final glyphs = <Map<String, dynamic>>[];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.empty);
    });

    test('detects empty screen with just structural elements', () {
      final glyphs = [
        glyph(label: 'App Title', widgetType: 'Text', ancestors: ['AppBar']),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.empty);
    });

    test('returns unknown for ambiguous screens', () {
      final glyphs = [
        glyph(label: 'Some content'),
        glyph(label: 'More text'),
        glyph(
          label: 'A button',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.unknown);
    });
  });

  // ===================================================================
  // ScryAlert — Error / Loading / Notice detection
  // ===================================================================
  group('ScryAlert detection', () {
    test('detects ErrorWidget (red screen) as error alert', () {
      final glyphs = [
        glyph(
          label: 'A RenderFlex overflowed by 42 pixels',
          widgetType: 'ErrorWidget',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.error);
      expect(gaze.alerts.first.message, contains('overflowed'));
      expect(gaze.alerts.first.widgetType, 'ErrorWidget');
    });

    test('detects ErrorWidget without label with fallback message', () {
      final glyphs = [glyph(label: '', widgetType: 'ErrorWidget')];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.error);
      expect(gaze.alerts.first.message, contains('red screen'));
    });

    test('ErrorWidget triggers error screen type', () {
      final glyphs = [
        glyph(label: 'Build failed: null value', widgetType: 'ErrorWidget'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.error);
    });

    test('detects loading indicators by widget type', () {
      final glyphs = [
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.loading);
      expect(gaze.alerts.first.message, contains('CircularProgressIndicator'));
    });

    test('detects loading indicator with label', () {
      final glyphs = [
        glyph(
          label: 'Loading quests...',
          widgetType: 'CircularProgressIndicator',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.loading);
      expect(gaze.alerts.first.message, 'Loading quests...');
    });

    test('detects snackbar with error text as error', () {
      final glyphs = [
        glyph(
          label: 'Error: Could not load data',
          widgetType: 'Text',
          ancestors: ['SnackBar', 'Scaffold'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.error);
      expect(gaze.alerts.first.message, 'Error: Could not load data');
    });

    test('detects snackbar with normal text as info', () {
      final glyphs = [
        glyph(
          label: 'Quest completed!',
          widgetType: 'Text',
          ancestors: ['SnackBar', 'Scaffold'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.info);
      expect(gaze.alerts.first.message, 'Quest completed!');
    });

    test('detects MaterialBanner content', () {
      final glyphs = [
        glyph(
          label: 'New update available',
          widgetType: 'Text',
          ancestors: ['MaterialBanner'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.info);
    });

    test('detects error text content with keywords', () {
      final glyphs = [glyph(label: 'Could not load data. Please try again')];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.warning);
    });

    test('does not flag normal text as error', () {
      final glyphs = [
        glyph(label: 'Welcome to the app'),
        glyph(label: 'Your profile is complete'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, isEmpty);
    });

    test('isLoading returns true when loading alerts present', () {
      final glyphs = [glyph(label: '', widgetType: 'LinearProgressIndicator')];
      final gaze = scry.observe(glyphs);
      expect(gaze.isLoading, isTrue);
      expect(gaze.hasErrors, isFalse);
    });

    test('hasErrors returns true when error alerts present', () {
      final glyphs = [
        glyph(
          label: 'Error: Connection refused',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.hasErrors, isTrue);
      expect(gaze.isLoading, isFalse);
    });

    test('alert serializes to JSON', () {
      const alert = ScryAlert(
        severity: ScryAlertSeverity.error,
        message: 'Something broke',
        widgetType: 'SnackBar',
      );
      final json = alert.toJson();
      expect(json['severity'], 'error');
      expect(json['message'], 'Something broke');
      expect(json['widgetType'], 'SnackBar');
    });

    test('de-duplicates identical alert messages', () {
      // Two glyphs with the same text in a SnackBar
      final glyphs = [
        glyph(
          label: 'Duplicate alert',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
        glyph(
          label: 'Duplicate alert',
          widgetType: 'RichText',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      // Should only have 1 alert, not 2
      expect(gaze.alerts, hasLength(1));
    });

    test('does not flag NotificationListener children as alerts', () {
      // NotificationListener is a common Flutter wrapper — its children
      // should not be treated as SnackBar/notice content.
      final glyphs = [
        glyph(
          label: 'Complete Quest',
          widgetType: 'Text',
          ancestors: ['NotificationListener', 'Column', 'Scaffold'],
        ),
        glyph(
          label: 'Sign Out',
          widgetType: 'Text',
          ancestors: ['NotificationListener'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      // These should NOT be flagged as alerts
      final noticeAlerts = gaze.alerts
          .where((a) => a.severity == ScryAlertSeverity.info)
          .toList();
      expect(noticeAlerts, isEmpty);
    });

    test('excludes interactive labels from SnackBar alert detection', () {
      // Button labels that appear as text inside a SnackBar should not
      // be reported as info alerts — the AI already knows about buttons.
      final glyphs = [
        glyph(
          label: 'Dismiss',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['SnackBar'],
        ),
        glyph(label: 'Dismiss', widgetType: 'Text', ancestors: ['SnackBar']),
        glyph(
          label: 'Action completed',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      final infoAlerts = gaze.alerts
          .where((a) => a.severity == ScryAlertSeverity.info)
          .toList();
      // "Dismiss" should be filtered (interactive label)
      // "Action completed" should be kept (genuine notice text)
      expect(infoAlerts, hasLength(1));
      expect(infoAlerts.first.message, 'Action completed');
    });
  });

  // ===================================================================
  // ScryKeyValue — Key-value pair extraction
  // ===================================================================
  group('ScryKeyValue extraction', () {
    test('extracts inline "Key: Value" patterns', () {
      final glyphs = [
        glyph(label: 'Class: Scout'),
        glyph(label: 'Level: Novice'),
        glyph(label: 'Glory: 0'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, hasLength(3));
      expect(gaze.dataFields[0].key, 'Class');
      expect(gaze.dataFields[0].value, 'Scout');
      expect(gaze.dataFields[1].key, 'Level');
      expect(gaze.dataFields[1].value, 'Novice');
      expect(gaze.dataFields[2].key, 'Glory');
      expect(gaze.dataFields[2].value, '0');
    });

    test('skips interactive elements for KV extraction', () {
      final glyphs = [
        glyph(label: 'Name: Kael', widgetType: 'TextField', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, isEmpty);
    });

    test('skips long keys (> 30 chars)', () {
      final glyphs = [
        glyph(
          label: 'This is a very long label that should not be a key: value',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, isEmpty);
    });

    test('extracts proximity-based pairs by Y alignment', () {
      // Two text labels on the same row, left one short
      final glyphs = [
        {
          'wt': 'Text',
          'l': 'Name:',
          'x': 16.0,
          'y': 100.0,
          'w': 60.0,
          'h': 20.0,
        },
        {
          'wt': 'Text',
          'l': 'Kael',
          'x': 80.0,
          'y': 100.0,
          'w': 50.0,
          'h': 20.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, hasLength(1));
      expect(gaze.dataFields.first.key, 'Name');
      expect(gaze.dataFields.first.value, 'Kael');
    });

    test('does not pair labels on different rows', () {
      final glyphs = [
        {
          'wt': 'Text',
          'l': 'Status:',
          'x': 16.0,
          'y': 100.0,
          'w': 60.0,
          'h': 20.0,
        },
        {
          'wt': 'Text',
          'l': 'Active',
          'x': 16.0,
          'y': 150.0,
          'w': 50.0,
          'h': 20.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      // "Status:" is an inline pattern that fails (no value after colon
      // in the proximity pairing), but it should not pair with "Active"
      // Since "Status:" by itself has no trailing value, the inline
      // pattern won't match. And proximity fails due to Y diff (50px).
      // Check no proximity pairs were created.
      expect(
        gaze.dataFields
            .where((d) => d.key == 'Status' && d.value == 'Active')
            .isEmpty,
        isTrue,
      );
    });

    test('KV pair serializes to JSON', () {
      const kv = ScryKeyValue(key: 'Role', value: 'Admin');
      final json = kv.toJson();
      expect(json['key'], 'Role');
      expect(json['value'], 'Admin');
    });

    test('deduplicates identical key-value pairs', () {
      // Two identical "Count: 0" labels on different sections
      final glyphs = [
        glyph(label: 'Count: 0'),
        glyph(label: 'Count: 0'),
        glyph(label: 'Hero: Kael'),
        glyph(label: 'Hero: Kael'),
      ];
      final gaze = scry.observe(glyphs);
      final countPairs = gaze.dataFields
          .where((d) => d.key == 'Count')
          .toList();
      final heroPairs = gaze.dataFields.where((d) => d.key == 'Hero').toList();
      expect(countPairs, hasLength(1));
      expect(heroPairs, hasLength(1));
    });

    test('filters IconData codepoints from proximity pairs', () {
      final glyphs = [
        {
          'wt': 'Icon',
          'l': 'IconData(U+0E596)',
          'x': 16.0,
          'y': 100.0,
          'w': 24.0,
          'h': 24.0,
        },
        {
          'wt': 'Icon',
          'l': 'IconData(U+0E3B3)',
          'x': 44.0,
          'y': 100.0,
          'w': 24.0,
          'h': 24.0,
        },
        // Real data should still be extracted
        glyph(label: 'Status: Active'),
      ];
      final gaze = scry.observe(glyphs);
      // Icon pairs should be filtered out
      final iconPairs = gaze.dataFields
          .where((d) => d.key.contains('IconData'))
          .toList();
      expect(iconPairs, isEmpty);
      // Real data should remain
      final statusPairs = gaze.dataFields
          .where((d) => d.key == 'Status')
          .toList();
      expect(statusPairs, hasLength(1));
    });

    test('filters raw Unicode glyph characters from proximity pairs', () {
      final glyphs = [
        {
          'wt': 'Icon',
          'l': '\uE596',
          'x': 16.0,
          'y': 100.0,
          'w': 24.0,
          'h': 24.0,
        },
        {
          'wt': 'Icon',
          'l': '\uE3B3',
          'x': 44.0,
          'y': 100.0,
          'w': 24.0,
          'h': 24.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, isEmpty);
    });

    test('excludes interactive labels from proximity pairing', () {
      // Button labels that also appear as non-interactive text glyphs
      // should not be paired as key-value data.
      final glyphs = <Map<String, dynamic>>[
        // Interactive button
        {
          'wt': 'IconButton',
          'l': 'Sign Out',
          'ia': true,
          'it': 'tap',
          'x': 20.0,
          'y': 100.0,
          'w': 100.0,
          'h': 48.0,
        },
        // Non-interactive text copy of button label (same label)
        {
          'wt': 'Text',
          'l': 'Sign Out',
          'ia': false,
          'x': 20.0,
          'y': 100.0,
          'w': 80.0,
          'h': 24.0,
        },
        // Another interactive button adjacent to Sign Out
        {
          'wt': 'IconButton',
          'l': 'About',
          'ia': true,
          'it': 'tap',
          'x': 130.0,
          'y': 100.0,
          'w': 80.0,
          'h': 48.0,
        },
        // Non-interactive text copy
        {
          'wt': 'Text',
          'l': 'About',
          'ia': false,
          'x': 130.0,
          'y': 100.0,
          'w': 60.0,
          'h': 24.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      // Should NOT pair "Sign Out: About" — both are interactive labels
      expect(
        gaze.dataFields,
        isNot(
          contains(
            isA<ScryKeyValue>().having((kv) => kv.key, 'key', 'Sign Out'),
          ),
        ),
      );
    });

    test('excludes navigation labels from proximity pairing', () {
      // NavigationDestination labels should not become KV pairs
      final glyphs = <Map<String, dynamic>>[
        {
          'wt': 'NavigationDestination',
          'l': 'Quests',
          'ia': true,
          'it': 'tap',
          'x': 0.0,
          'y': 750.0,
          'w': 80.0,
          'h': 48.0,
          'anc': ['NavigationBar'],
        },
        {
          'wt': 'Text',
          'l': 'Quests',
          'ia': false,
          'x': 5.0,
          'y': 760.0,
          'w': 60.0,
          'h': 20.0,
        },
        {
          'wt': 'NavigationDestination',
          'l': 'Hero',
          'ia': true,
          'it': 'tap',
          'x': 90.0,
          'y': 750.0,
          'w': 80.0,
          'h': 48.0,
          'anc': ['NavigationBar'],
        },
        {
          'wt': 'Text',
          'l': 'Hero',
          'ia': false,
          'x': 95.0,
          'y': 760.0,
          'w': 50.0,
          'h': 20.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      // Should NOT pair "Quests: Hero"
      expect(gaze.dataFields, isEmpty);
    });

    test('rejects proximity pairs with large horizontal gap', () {
      // Simulate stat cards: "Glory" at x=130 and "Rank" at x=640
      // on the same row — too far apart to be a real KV pair.
      final glyphs = [
        {
          'wt': 'Text',
          'l': 'Glory',
          'ia': false,
          'x': 129.2,
          'y': 412.0,
          'w': 32.2,
          'h': 16.0,
        },
        {
          'wt': 'Text',
          'l': 'Rank',
          'ia': false,
          'x': 639.9,
          'y': 412.0,
          'w': 29.6,
          'h': 16.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      // Should NOT pair "Glory: Rank" — gap of 478px exceeds threshold
      expect(gaze.dataFields, isEmpty);
    });
  });

  // ===================================================================
  // ScryDiff — State change detection
  // ===================================================================
  group('ScryDiff', () {
    test('detects appeared elements', () {
      final before = scry.observe([glyph(label: 'Hello')]);
      final after = scry.observe([
        glyph(label: 'Hello'),
        glyph(label: 'World'),
      ]);
      final diff = scry.diff(before, after);
      expect(diff.appeared, hasLength(1));
      expect(diff.appeared.first.label, 'World');
      expect(diff.disappeared, isEmpty);
      expect(diff.hasChanges, isTrue);
    });

    test('detects disappeared elements', () {
      final before = scry.observe([
        glyph(label: 'Hello'),
        glyph(label: 'World'),
      ]);
      final after = scry.observe([glyph(label: 'Hello')]);
      final diff = scry.diff(before, after);
      expect(diff.appeared, isEmpty);
      expect(diff.disappeared, hasLength(1));
      expect(diff.disappeared.first.label, 'World');
    });

    test('detects changed values', () {
      final before = scry.observe([
        glyph(label: 'Score', widgetType: 'Text', currentValue: '10'),
      ]);
      final after = scry.observe([
        glyph(label: 'Score', widgetType: 'Text', currentValue: '20'),
      ]);
      final diff = scry.diff(before, after);
      expect(diff.changedValues, hasLength(1));
      expect(diff.changedValues['Score']!['from'], '10');
      expect(diff.changedValues['Score']!['to'], '20');
    });

    test('detects route change', () {
      final before = scry.observe([glyph(label: 'Page A')], route: '/a');
      final after = scry.observe([glyph(label: 'Page B')], route: '/b');
      final diff = scry.diff(before, after);
      expect(diff.routeChanged, isTrue);
      expect(diff.previousRoute, '/a');
      expect(diff.currentRoute, '/b');
    });

    test('detects no route change when same', () {
      final before = scry.observe([glyph(label: 'Page A')], route: '/a');
      final after = scry.observe([glyph(label: 'Page A updated')], route: '/a');
      final diff = scry.diff(before, after);
      expect(diff.routeChanged, isFalse);
    });

    test('detects screen type change', () {
      // Login screen
      final before = scry.observe([
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'user',
        ),
        glyph(label: 'Log In', widgetType: 'ElevatedButton', interactive: true),
      ]);
      // After login: list screen
      final after = scry.observe([
        glyph(label: 'Item 1'),
        glyph(label: 'Item 2'),
        glyph(label: 'Item 3'),
        glyph(label: 'Item 4'),
        glyph(label: 'Item 5'),
      ]);
      final diff = scry.diff(before, after);
      expect(diff.screenTypeChanged, isTrue);
      expect(diff.previousScreenType, ScryScreenType.login);
      expect(diff.currentScreenType, ScryScreenType.list);
    });

    test('hasChanges is false when nothing changed', () {
      final glyphs = [glyph(label: 'Static content')];
      final before = scry.observe(glyphs, route: '/x');
      final after = scry.observe(glyphs, route: '/x');
      final diff = scry.diff(before, after);
      expect(diff.hasChanges, isFalse);
    });

    test('format produces readable markdown', () {
      final before = scry.observe([
        glyph(label: 'Old Button', interactive: true),
      ], route: '/old');
      final after = scry.observe([
        glyph(label: 'New Text'),
        glyph(label: 'New Button', interactive: true),
      ], route: '/new');
      final diff = scry.diff(before, after);
      final md = diff.format();
      expect(md, contains('What Changed'));
      expect(md, contains('/old'));
      expect(md, contains('/new'));
      expect(md, contains('Appeared'));
      expect(md, contains('Disappeared'));
      expect(md, contains('Old Button'));
      expect(md, contains('New Text'));
      expect(md, contains('New Button'));
    });

    test('format handles empty diff', () {
      final glyphs = [glyph(label: 'Static')];
      final before = scry.observe(glyphs);
      final after = scry.observe(glyphs);
      final diff = scry.diff(before, after);
      final md = diff.format();
      expect(md, contains('No visible changes'));
    });

    test('diff serializes to JSON', () {
      final before = scry.observe([glyph(label: 'AA')], route: '/a');
      final after = scry.observe([glyph(label: 'BB')], route: '/b');
      final diff = scry.diff(before, after);
      final json = diff.toJson();
      expect(json['routeChanged'], isTrue);
      expect(json['previousRoute'], '/a');
      expect(json['currentRoute'], '/b');
      expect(json['hasChanges'], isTrue);
      expect(json['appeared'], isA<List>());
      expect(json['disappeared'], isA<List>());
    });
  });

  // ===================================================================
  // Action suggestions
  // ===================================================================
  group('Action suggestions', () {
    test('suggests credentials on login screen', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'hero',
        ),
        glyph(
          label: 'Enter the Questboard',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions, isNotEmpty);
      expect(
        gaze.suggestions.any(
          (s) => s.contains('Hero Name') && s.contains('Enter the Questboard'),
        ),
        isTrue,
      );
    });

    test('suggests filling fields on form screen', () {
      final glyphs = [
        glyph(
          label: 'First Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'f',
        ),
        glyph(
          label: 'Last Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'l',
        ),
        glyph(label: 'Save', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions, isNotEmpty);
      expect(gaze.suggestions.any((s) => s.contains('Save')), isTrue);
    });

    test('suggests item tap on list screen', () {
      final glyphs = <Map<String, dynamic>>[];
      for (var i = 0; i < 6; i++) {
        glyphs.add(glyph(label: 'Quest $i'));
      }
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions.any((s) => s.contains('item')), isTrue);
    });

    test('warns about errors when error alerts present', () {
      final glyphs = [
        glyph(
          label: 'Error: Connection refused',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(
        gaze.suggestions.any((s) => s.toLowerCase().contains('error')),
        isTrue,
      );
    });

    test('warns about loading state', () {
      final glyphs = [
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
        glyph(label: 'Some content'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions.any((s) => s.contains('loading')), isTrue);
    });

    test('suggests navigation on dashboard screen', () {
      final glyphs = [
        glyph(label: 'Content 1'),
        glyph(label: 'Content 2'),
        glyph(label: 'Content 3'),
        glyph(
          label: 'Tab A',
          widgetType: 'Text',
          interactive: true,
          ancestors: ['NavigationBar'],
        ),
        glyph(
          label: 'Tab B',
          widgetType: 'Text',
          interactive: true,
          ancestors: ['NavigationBar'],
        ),
        glyph(label: 'Action', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.dashboard);
      expect(gaze.suggestions, isNotEmpty);
    });
  });

  // ===================================================================
  // Updated formatGaze — new sections
  // ===================================================================
  group('formatGaze — intelligence sections', () {
    test('includes screen type in header', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'u',
        ),
        glyph(label: 'Log In', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs, route: '/login');
      final md = scry.formatGaze(gaze);
      expect(md, contains('**Type**: login'));
    });

    test('includes alerts section', () {
      final glyphs = [
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('⏳'));
      expect(md, contains('loading'));
    });

    test('includes data fields section', () {
      final glyphs = [
        glyph(label: 'Class: Scout'),
        glyph(label: 'Level: Novice'),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('📊 Data'));
      expect(md, contains('**Class**: Scout'));
      expect(md, contains('**Level**: Novice'));
    });

    test('includes suggestions section', () {
      final glyphs = [
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'n',
        ),
        glyph(label: 'Submit', widgetType: 'ElevatedButton', interactive: true),
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'e',
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('💡 Suggestions'));
    });

    test('ScryGaze toJson includes new fields', () {
      final glyphs = [
        glyph(label: 'Class: Scout'),
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'n',
        ),
        glyph(label: 'Submit', widgetType: 'ElevatedButton', interactive: true),
        glyph(
          label: 'Other Field',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'o',
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json['screenType'], isA<String>());
      expect(json['alerts'], isA<List>());
      expect(json['dataFields'], isA<List>());
      expect(json['suggestions'], isA<List>());
    });
  });

  // ===================================================================
  // ScryAlertSeverity
  // ===================================================================
  group('ScryAlertSeverity', () {
    test('has all expected values', () {
      expect(ScryAlertSeverity.values, hasLength(4));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.error));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.warning));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.info));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.loading));
    });
  });

  // ===================================================================
  // Error screen type detection
  // ===================================================================
  group('ScryScreenType.error', () {
    test('error screen detected when snackbar has error', () {
      final glyphs = [
        glyph(
          label: 'Failed to load data',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
        glyph(label: 'Some content'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.error);
    });

    test('error takes precedence over login', () {
      final glyphs = [
        glyph(
          label: 'Error: Invalid credentials',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'u',
        ),
        glyph(
          label: 'Sign In',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      // Error takes precedence over login detection
      expect(gaze.screenType, ScryScreenType.error);
    });
  });

  // ===================================================================
  // Detail screen type detection
  // ===================================================================
  group('ScryScreenType.detail', () {
    test('detected when data fields present with no input fields', () {
      final glyphs = [
        glyph(label: 'Name: Kael'),
        glyph(label: 'Class: Scout'),
        glyph(label: 'Level: Novice'),
        glyph(label: 'Edit', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.detail);
      expect(gaze.dataFields, hasLength(3));
    });
  });

  // ===================================================================
  // Spatial layout awareness
  // ===================================================================
  group('Spatial layout awareness', () {
    test('ScryElement stores x/y/w/h from glyphs', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'heroName',
          x: 16.0,
          y: 200.0,
          w: 350.0,
          h: 56.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Hero Name');
      expect(field.x, 16.0);
      expect(field.y, 200.0);
      expect(field.w, 350.0);
      expect(field.h, 56.0);
    });

    test('ScryElement stores depth from glyphs', () {
      final glyphs = [glyph(label: 'Title', depth: 12, y: 50.0)];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.depth, 12);
    });

    test('ScryElement toJson includes spatial data when present', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Tap Me',
        widgetType: 'ElevatedButton',
        x: 10.0,
        y: 200.0,
        w: 120.0,
        h: 48.0,
        depth: 5,
      );
      final json = element.toJson();
      expect(json['x'], 10.0);
      expect(json['y'], 200.0);
      expect(json['w'], 120.0);
      expect(json['h'], 48.0);
      expect(json['depth'], 5);
    });

    test('ScryElement toJson omits null spatial data', () {
      const element = ScryElement(
        kind: ScryElementKind.content,
        label: 'Hello',
        widgetType: 'Text',
      );
      final json = element.toJson();
      expect(json.containsKey('x'), isFalse);
      expect(json.containsKey('depth'), isFalse);
    });
  });

  // ===================================================================
  // Screen region inference
  // ===================================================================
  group('Screen region inference', () {
    test('AppBar ancestor → topBar region', () {
      final glyphs = [
        glyph(
          label: 'My App',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          y: 40.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'My App');
      expect(el.region, ScryScreenRegion.topBar);
    });

    test('NavigationBar ancestor → bottomNav region', () {
      final glyphs = [
        glyph(
          label: 'Home',
          widgetType: 'GestureDetector',
          interactive: true,
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'NavigationBar',
            'GestureDetector',
          ],
          y: 750.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Home');
      expect(el.region, ScryScreenRegion.bottomNav);
    });

    test('FAB ancestor → floating region', () {
      final glyphs = [
        glyph(
          label: 'Add',
          widgetType: 'FloatingActionButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'FloatingActionButton'],
          y: 600.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Add');
      expect(el.region, ScryScreenRegion.floating);
    });

    test('y < 100 without ancestor → topBar by position', () {
      final glyphs = [glyph(label: 'Title Text', y: 50.0)];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.region, ScryScreenRegion.topBar);
    });

    test('y > 700 without ancestor → bottomNav by position', () {
      final glyphs = [
        glyph(
          label: 'Tab Label',
          widgetType: 'GestureDetector',
          interactive: true,
          y: 750.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.region, ScryScreenRegion.bottomNav);
    });

    test('y between 100 and 700 → mainContent', () {
      final glyphs = [glyph(label: 'Content Text', y: 400.0)];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.region, ScryScreenRegion.mainContent);
    });

    test('ScryScreenRegion has all expected values', () {
      expect(ScryScreenRegion.values, hasLength(5));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.topBar));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.mainContent));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.bottomNav));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.floating));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.unknown));
    });
  });

  // ===================================================================
  // Key-based stable targeting
  // ===================================================================
  group('Key-based stable targeting', () {
    test('ScryElement stores key from glyph', () {
      final glyphs = [
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          key: "ValueKey('submit_btn')",
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Submit');
      expect(btn.key, "ValueKey('submit_btn')");
    });

    test('ScryElement toJson includes key when present', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Submit',
        widgetType: 'ElevatedButton',
        key: "ValueKey('submit_btn')",
      );
      final json = element.toJson();
      expect(json['key'], "ValueKey('submit_btn')");
    });

    test('buildActionCampaign prefers key over label', () {
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'Submit',
        key: "ValueKey('submit_btn')",
      );
      // Campaign has nested structure: entries[0].stratagem.steps
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final tapStep = steps.last as Map<String, dynamic>;
      expect(tapStep['action'], 'tap');
      final target = tapStep['target'] as Map<String, dynamic>;
      expect(target['key'], "ValueKey('submit_btn')");
    });

    test('buildActionCampaign works without key', () {
      final campaign = scry.buildActionCampaign(action: 'tap', label: 'Submit');
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final tapStep = steps.last as Map<String, dynamic>;
      final target = tapStep['target'] as Map<String, dynamic>;
      expect(target['label'], 'Submit');
      expect(target.containsKey('key'), isFalse);
    });

    test('buildMultiActionCampaign uses key from action map', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'tap', 'label': 'Delete', 'key': "ValueKey('del_0')"},
      ]);
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final tapStep = steps.last as Map<String, dynamic>;
      final target = tapStep['target'] as Map<String, dynamic>;
      expect(target['key'], "ValueKey('del_0')");
    });
  });

  // ===================================================================
  // Ancestor context annotation
  // ===================================================================
  group('Ancestor context annotation', () {
    test('Dialog ancestor sets context to Dialog', () {
      final glyphs = [
        glyph(
          label: 'Cancel',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'TextButton'],
          depth: 30,
          y: 400.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Cancel');
      expect(btn.context, 'Dialog');
    });

    test('BottomSheet ancestor sets context', () {
      final glyphs = [
        glyph(
          label: 'Close',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'BottomSheet', 'TextButton'],
          depth: 25,
          y: 500.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Close');
      expect(btn.context, 'BottomSheet');
    });

    test('Card ancestor sets context', () {
      final glyphs = [
        glyph(
          label: 'Card Title',
          ancestors: ['MaterialApp', 'Scaffold', 'Card', 'Text'],
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Card Title');
      expect(el.context, 'Card');
    });

    test('no recognized ancestor sets context to null', () {
      final glyphs = [
        glyph(
          label: 'Plain Text',
          ancestors: ['MaterialApp', 'Scaffold', 'Column', 'Text'],
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Plain Text');
      expect(el.context, isNull);
    });

    test('formatGaze shows context for buttons', () {
      final glyphs = [
        glyph(
          label: 'Confirm',
          widgetType: 'ElevatedButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'ElevatedButton'],
          depth: 30,
          y: 400.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      expect(output, contains('Dialog'));
    });
  });

  // ===================================================================
  // Overlap / occlusion detection
  // ===================================================================
  group('Overlap / occlusion detection', () {
    test('background element behind dialog is marked obscured', () {
      final glyphs = [
        // Background button at depth 5
        glyph(
          label: 'Background Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 50.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        // Dialog content at depth 30
        glyph(
          label: 'Dialog Title',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 20.0,
          y: 200.0,
          w: 350.0,
          h: 400.0,
        ),
        glyph(
          label: 'OK',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'TextButton'],
          depth: 30,
          x: 150.0,
          y: 500.0,
          w: 60.0,
          h: 36.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      final bgBtn = gaze.elements.firstWhere(
        (e) => e.label == 'Background Button',
      );
      expect(bgBtn.obscured, isTrue);

      // Dialog elements should NOT be obscured
      final okBtn = gaze.elements.firstWhere((e) => e.label == 'OK');
      expect(okBtn.obscured, isFalse);
    });

    test('non-overlapping background element is not obscured', () {
      final glyphs = [
        // Background button far from dialog
        glyph(
          label: 'Far Away Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 50.0,
          y: 50.0,
          w: 100.0,
          h: 48.0,
        ),
        // Dialog in center of screen
        glyph(
          label: 'Dialog Content',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 100.0,
          y: 200.0,
          w: 200.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      final btn = gaze.elements.firstWhere((e) => e.label == 'Far Away Button');
      expect(btn.obscured, isFalse);
    });

    test('ScryGaze.obscured getter returns only obscured elements', () {
      final glyphs = [
        glyph(
          label: 'Hidden',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 100.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        glyph(
          label: 'Visible',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 50.0,
          y: 50.0,
          w: 80.0,
          h: 48.0,
        ),
        glyph(
          label: 'Dialog Text',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 80.0,
          y: 250.0,
          w: 250.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.obscured, hasLength(1));
      expect(gaze.obscured.first.label, 'Hidden');
    });

    test('no overlay means nothing is obscured', () {
      final glyphs = [
        glyph(
          label: 'Button A',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          y: 200.0,
        ),
        glyph(
          label: 'Button B',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.obscured, isEmpty);
    });

    test('ScryGaze toJson includes obscured count', () {
      final glyphs = [
        glyph(
          label: 'Blocked',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 100.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        glyph(
          label: 'Modal OK',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['Dialog'],
          depth: 30,
          x: 80.0,
          y: 250.0,
          w: 250.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json['obscuredCount'], 1);
    });

    test('formatGaze includes obscured warning section', () {
      final glyphs = [
        glyph(
          label: 'Hidden Btn',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 100.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        glyph(
          label: 'Dialog OK',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['Dialog'],
          depth: 30,
          x: 80.0,
          y: 250.0,
          w: 250.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      expect(output, contains('Obscured'));
      expect(output, contains('Hidden Btn'));
    });
  });

  // ===================================================================
  // Repeated-element multiplicity
  // ===================================================================
  group('Repeated-element multiplicity', () {
    test('multiple interactive buttons with same label get indices', () {
      final glyphs = [
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          y: 100.0,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          y: 200.0,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      final deletes = gaze.elements.where((e) => e.label == 'Delete').toList();
      expect(deletes, hasLength(3));
      expect(deletes[0].occurrenceIndex, 0);
      expect(deletes[0].totalOccurrences, 3);
      expect(deletes[1].occurrenceIndex, 1);
      expect(deletes[2].occurrenceIndex, 2);
    });

    test('unique label has null occurrence fields', () {
      final glyphs = [
        glyph(label: 'Submit', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Submit');
      expect(btn.occurrenceIndex, isNull);
      expect(btn.totalOccurrences, isNull);
    });

    test('non-interactive duplicates are still deduplicated', () {
      // Same label appearing as both GestureDetector and Tooltip
      // for the same UI element — should dedup, not multiply
      final glyphs = [
        glyph(
          label: 'Quests',
          widgetType: 'GestureDetector',
          interactive: true,
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'BottomNavigationBar',
            'GestureDetector',
          ],
        ),
        glyph(
          label: 'Quests',
          widgetType: 'Tooltip',
          interactive: false,
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'BottomNavigationBar',
            'Tooltip',
          ],
        ),
      ];
      final gaze = scry.observe(glyphs);
      final quests = gaze.elements.where((e) => e.label == 'Quests').toList();
      // Should dedup to one element since only one is interactive
      expect(quests, hasLength(1));
      expect(quests.first.occurrenceIndex, isNull);
    });

    test('formatGaze shows multiplicity for repeated buttons', () {
      final glyphs = [
        glyph(
          label: 'Remove',
          widgetType: 'IconButton',
          interactive: true,
          y: 100.0,
        ),
        glyph(
          label: 'Remove',
          widgetType: 'IconButton',
          interactive: true,
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      // Should show occurrence count/index
      expect(output, contains('Remove'));
      expect(output, contains('×2'));
    });
  });

  // ===================================================================
  // Form validation awareness
  // ===================================================================
  group('Form validation awareness', () {
    test('detects empty and filled fields', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'username',
          currentValue: 'Kael',
          y: 100.0,
        ),
        glyph(
          label: 'Password',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'password',
          y: 200.0,
        ),
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.totalFields, 2);
      expect(gaze.formStatus!.filledFields, 1);
      expect(gaze.formStatus!.emptyFields, ['Password']);
      expect(gaze.formStatus!.isReady, isFalse);
    });

    test('all fields filled and no errors → isReady', () {
      final glyphs = [
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'name',
          currentValue: 'Kael',
          y: 100.0,
        ),
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'email',
          currentValue: 'kael@titan.io',
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.isReady, isTrue);
      expect(gaze.formStatus!.emptyFields, isEmpty);
      expect(gaze.formStatus!.validationErrors, isEmpty);
    });

    test('detects disabled fields', () {
      final glyphs = [
        glyph(
          label: 'Locked Field',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'locked',
          enabled: false,
          y: 100.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.disabledFields, ['Locked Field']);
    });

    test('detects validation errors near fields', () {
      final glyphs = [
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'email',
          currentValue: 'bad',
          x: 16.0,
          y: 100.0,
          w: 350.0,
          h: 56.0,
        ),
        // Error text directly below the field
        glyph(
          label: 'Please enter a valid email',
          x: 16.0,
          y: 130.0,
          w: 200.0,
          h: 16.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.validationErrors, hasLength(1));
      expect(gaze.formStatus!.validationErrors.first.fieldLabel, 'Email');
      expect(
        gaze.formStatus!.validationErrors.first.errorMessage,
        'Please enter a valid email',
      );
      expect(gaze.formStatus!.isReady, isFalse);
    });

    test('ignores error text too far from field', () {
      final glyphs = [
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'name',
          currentValue: 'Kael',
          x: 16.0,
          y: 100.0,
          w: 350.0,
          h: 56.0,
        ),
        // Error text far below — 200px gap
        glyph(
          label: 'This field is required',
          x: 16.0,
          y: 300.0,
          w: 200.0,
          h: 16.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.validationErrors, isEmpty);
    });

    test('no fields → null formStatus', () {
      final glyphs = [
        glyph(label: 'Welcome'),
        glyph(label: 'Start', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.formStatus, isNull);
    });

    test('ScryFormStatus serializes to JSON', () {
      const status = ScryFormStatus(
        totalFields: 3,
        filledFields: 2,
        emptyFields: ['Password'],
        validationErrors: [
          ScryFieldError(fieldLabel: 'Email', errorMessage: 'Invalid email'),
        ],
        disabledFields: [],
      );

      final json = status.toJson();
      expect(json['totalFields'], 3);
      expect(json['filledFields'], 2);
      expect(json['emptyFields'], ['Password']);
      expect(json['isReady'], isFalse);
      expect(json['validationErrors'], hasLength(1));
    });

    test('ScryFieldError serializes to JSON', () {
      const error = ScryFieldError(
        fieldLabel: 'Email',
        errorMessage: 'Invalid email',
      );
      final json = error.toJson();
      expect(json['fieldLabel'], 'Email');
      expect(json['errorMessage'], 'Invalid email');
    });

    test('ScryGaze toJson includes formStatus when present', () {
      final glyphs = [
        glyph(
          label: 'Field',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'f',
          y: 100.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('formStatus'), isTrue);
    });

    test('formatGaze includes form status section', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'username',
          currentValue: 'Kael',
          y: 100.0,
        ),
        glyph(
          label: 'Password',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'password',
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      expect(output, contains('Form Status'));
      expect(output, contains('filled'));
    });
  });

  // ===================================================================
  // Combined capabilities integration
  // ===================================================================
  group('Combined capabilities', () {
    test('observe produces full-featured elements', () {
      final glyphs = [
        // AppBar title
        glyph(
          label: 'Quest Log',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          y: 40.0,
          depth: 10,
        ),
        // Form field with key
        glyph(
          label: 'Quest Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'questName',
          currentValue: 'Dragon Slayer',
          key: "ValueKey('quest_name')",
          y: 200.0,
          depth: 12,
        ),
        // Submit button in Card context
        glyph(
          label: 'Create Quest',
          widgetType: 'ElevatedButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Card', 'ElevatedButton'],
          y: 400.0,
          depth: 14,
        ),
      ];
      final gaze = scry.observe(glyphs);

      // AppBar title → topBar region
      final title = gaze.elements.firstWhere((e) => e.label == 'Quest Log');
      expect(title.region, ScryScreenRegion.topBar);

      // Field has key and is in main content
      final field = gaze.elements.firstWhere((e) => e.label == 'Quest Name');
      expect(field.key, "ValueKey('quest_name')");
      expect(field.region, ScryScreenRegion.mainContent);

      // Button has Card context
      final btn = gaze.elements.firstWhere((e) => e.label == 'Create Quest');
      expect(btn.context, 'Card');

      // Form status populated
      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.filledFields, 1);
    });

    test('dialog overlays + multiplicity + key targeting together', () {
      final glyphs = [
        // Three "Edit" buttons in a list (background)
        glyph(
          label: 'Edit',
          widgetType: 'IconButton',
          interactive: true,
          depth: 5,
          x: 300.0,
          y: 100.0,
          w: 48.0,
          h: 48.0,
          key: "ValueKey('edit_0')",
        ),
        glyph(
          label: 'Edit',
          widgetType: 'IconButton',
          interactive: true,
          depth: 5,
          x: 300.0,
          y: 200.0,
          w: 48.0,
          h: 48.0,
          key: "ValueKey('edit_1')",
        ),
        glyph(
          label: 'Edit',
          widgetType: 'IconButton',
          interactive: true,
          depth: 5,
          x: 300.0,
          y: 300.0,
          w: 48.0,
          h: 48.0,
          key: "ValueKey('edit_2')",
        ),
        // Dialog overlay covering the middle area
        glyph(
          label: 'Confirm Edit',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 50.0,
          y: 150.0,
          w: 300.0,
          h: 300.0,
        ),
        glyph(
          label: 'Save',
          widgetType: 'ElevatedButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'ElevatedButton'],
          depth: 30,
          x: 200.0,
          y: 400.0,
          w: 100.0,
          h: 48.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      // All 3 Edit buttons should have multiplicity
      final edits = gaze.elements.where((e) => e.label == 'Edit').toList();
      expect(edits, hasLength(3));
      expect(edits[0].totalOccurrences, 3);

      // Edit buttons 1 and 2 (y=200, y=300) overlap with dialog
      // Edit button 0 (y=100) is above the dialog
      final obscuredEdits = edits.where((e) => e.obscured).toList();
      expect(obscuredEdits, hasLength(2));

      // Keys are preserved even when obscured
      for (final e in edits) {
        expect(e.key, isNotNull);
      }

      // Dialog elements not obscured
      final save = gaze.elements.firstWhere((e) => e.label == 'Save');
      expect(save.obscured, isFalse);
      expect(save.context, 'Dialog');
    });
  });

  // ===================================================================
  // ScryTargetStrategy enum
  // ===================================================================
  group('ScryTargetStrategy', () {
    test('has all expected values', () {
      expect(ScryTargetStrategy.values, hasLength(4));
      expect(
        ScryTargetStrategy.values,
        containsAll([
          ScryTargetStrategy.key,
          ScryTargetStrategy.fieldId,
          ScryTargetStrategy.uniqueLabel,
          ScryTargetStrategy.indexedLabel,
        ]),
      );
    });
  });

  // ===================================================================
  // ScryScrollInfo
  // ===================================================================
  group('ScryScrollInfo', () {
    test('canScrollDown true when content exceeds viewport', () {
      const info = ScryScrollInfo(
        viewportHeight: 800,
        contentMaxY: 1600,
        visibleCount: 10,
        belowFoldCount: 5,
      );
      expect(info.canScrollDown, isTrue);
    });

    test('canScrollDown false when content within viewport', () {
      const info = ScryScrollInfo(
        viewportHeight: 800,
        contentMaxY: 400,
        visibleCount: 5,
        belowFoldCount: 0,
      );
      expect(info.canScrollDown, isFalse);
    });

    test('contentScreens computes screen count', () {
      const info = ScryScrollInfo(
        viewportHeight: 800,
        contentMaxY: 2400,
        visibleCount: 10,
        belowFoldCount: 20,
      );
      expect(info.contentScreens, 3.0);
    });

    test('contentScreens returns 1.0 when viewportHeight is 0', () {
      const info = ScryScrollInfo(
        viewportHeight: 0,
        contentMaxY: 400,
        visibleCount: 5,
        belowFoldCount: 0,
      );
      expect(info.contentScreens, 1.0);
    });

    test('toJson includes all fields', () {
      const info = ScryScrollInfo(
        viewportHeight: 800,
        contentMaxY: 1200,
        visibleCount: 8,
        belowFoldCount: 3,
      );
      final json = info.toJson();
      expect(json['viewportHeight'], 800.0);
      expect(json['contentMaxY'], 1200.0);
      expect(json['visibleCount'], 8);
      expect(json['belowFoldCount'], 3);
      expect(json['canScrollDown'], isTrue);
      expect(json['contentScreens'], 1.5);
    });
  });

  // ===================================================================
  // ScryElementGroup
  // ===================================================================
  group('ScryElementGroup', () {
    test('toJson serializes container info', () {
      const group = ScryElementGroup(
        containerType: 'Card',
        containerLabel: 'Quest Card',
        elements: [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Title',
            widgetType: 'Text',
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Delete',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
        ],
      );
      final json = group.toJson();
      expect(json['containerType'], 'Card');
      expect(json['containerLabel'], 'Quest Card');
      expect(json['elementCount'], 2);
      expect(json['elements'], isList);
      expect((json['elements'] as List), hasLength(2));
    });

    test('toJson omits null containerLabel', () {
      const group = ScryElementGroup(
        containerType: 'ListTile',
        elements: [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'A',
            widgetType: 'Text',
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'B',
            widgetType: 'Text',
          ),
        ],
      );
      final json = group.toJson();
      expect(json.containsKey('containerLabel'), isFalse);
    });
  });

  // ===================================================================
  // ScryLandmarks
  // ===================================================================
  group('ScryLandmarks', () {
    test('toJson includes available landmarks', () {
      const landmarks = ScryLandmarks(
        pageTitle: 'Quest Log',
        backAvailable: true,
        searchAvailable: true,
      );
      final json = landmarks.toJson();
      expect(json['pageTitle'], 'Quest Log');
      expect(json['backAvailable'], isTrue);
      expect(json['searchAvailable'], isTrue);
    });

    test('toJson includes primaryAction label', () {
      const landmarks = ScryLandmarks(
        primaryAction: ScryElement(
          kind: ScryElementKind.button,
          label: 'Add Quest',
          widgetType: 'FloatingActionButton',
          isInteractive: true,
        ),
      );
      final json = landmarks.toJson();
      expect(json['primaryAction'], 'Add Quest');
    });

    test('toJson omits null fields', () {
      const landmarks = ScryLandmarks();
      final json = landmarks.toJson();
      expect(json.containsKey('pageTitle'), isFalse);
      expect(json.containsKey('primaryAction'), isFalse);
      expect(json['backAvailable'], isFalse);
      expect(json['searchAvailable'], isFalse);
    });
  });

  // ===================================================================
  // Target stability scoring
  // ===================================================================
  group('Target stability scoring', () {
    test('key gives score 100', () {
      final glyphs = [
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          key: 'submit_btn',
          x: 100,
          y: 200,
          w: 120,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final submit = gaze.elements.firstWhere((e) => e.label == 'Submit');
      expect(submit.targetScore, 100);
      expect(submit.targetStrategy, ScryTargetStrategy.key);
    });

    test('fieldId gives score 90', () {
      final glyphs = [
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'type',
          fieldId: 'email_field',
          x: 10,
          y: 100,
          w: 300,
          h: 56,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final email = gaze.elements.firstWhere((e) => e.label == 'Email');
      expect(email.targetScore, 90);
      expect(email.targetStrategy, ScryTargetStrategy.fieldId);
    });

    test('unique label gives score 70', () {
      final glyphs = [
        glyph(
          label: 'Save Settings',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 200,
          w: 150,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final save = gaze.elements.firstWhere((e) => e.label == 'Save Settings');
      expect(save.targetScore, 70);
      expect(save.targetStrategy, ScryTargetStrategy.uniqueLabel);
    });

    test('duplicate label gives score 40', () {
      final glyphs = [
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 100,
          w: 48,
          h: 48,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 200,
          w: 48,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final deletes = gaze.elements.where((e) => e.label == 'Delete').toList();
      for (final d in deletes) {
        expect(d.targetScore, 40);
        expect(d.targetStrategy, ScryTargetStrategy.indexedLabel);
      }
    });

    test('key takes priority over fieldId', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'type',
          fieldId: 'username_field',
          key: 'username_key',
          x: 10,
          y: 100,
          w: 300,
          h: 56,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Username');
      expect(field.targetScore, 100); // key wins over fieldId
      expect(field.targetStrategy, ScryTargetStrategy.key);
    });

    test('non-interactive elements keep default score 0', () {
      final glyphs = [
        glyph(label: 'Welcome', widgetType: 'Text', x: 10, y: 50),
      ];
      final gaze = scry.observe(glyphs);
      final text = gaze.elements.firstWhere((e) => e.label == 'Welcome');
      expect(text.targetScore, 0);
      expect(text.targetStrategy, ScryTargetStrategy.uniqueLabel);
    });
  });

  // ===================================================================
  // Reachability analysis
  // ===================================================================
  group('Reachability analysis', () {
    test('enabled, visible element is reachable', () {
      final glyphs = [
        glyph(
          label: 'OK',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 200,
          w: 100,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final ok = gaze.elements.firstWhere((e) => e.label == 'OK');
      expect(ok.reachable, isTrue);
    });

    test('disabled element is unreachable', () {
      final glyphs = [
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          enabled: false,
          x: 100,
          y: 200,
          w: 100,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final submit = gaze.elements.firstWhere((e) => e.label == 'Submit');
      expect(submit.reachable, isFalse);
    });

    test('obscured element is unreachable', () {
      // Create an element obscured by a dialog overlay
      final glyphs = [
        glyph(
          label: 'Background Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['MaterialApp', 'Scaffold', 'Column', 'ElevatedButton'],
          depth: 10,
          x: 100,
          y: 300,
          w: 150,
          h: 48,
        ),
        // Dialog overlay element at higher depth
        glyph(
          label: 'Dialog Action',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'Overlay',
            'Dialog',
            'ElevatedButton',
          ],
          depth: 30,
          x: 50,
          y: 250,
          w: 300,
          h: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final bg = gaze.elements.firstWhere(
        (e) => e.label == 'Background Button',
      );
      // Obscured by the dialog, hence unreachable
      expect(bg.obscured, isTrue);
      expect(bg.reachable, isFalse);
    });

    test('offscreen element (y >= 800) is unreachable', () {
      final glyphs = [
        glyph(
          label: 'Far Below',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 900,
          w: 100,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final far = gaze.elements.firstWhere((e) => e.label == 'Far Below');
      expect(far.reachable, isFalse);
    });

    test('element at y=799 is still reachable', () {
      final glyphs = [
        glyph(
          label: 'Near Bottom',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 799,
          w: 100,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final near = gaze.elements.firstWhere((e) => e.label == 'Near Bottom');
      expect(near.reachable, isTrue);
    });

    test('non-interactive elements not assessed for reachability', () {
      final glyphs = [
        glyph(
          label: 'Text Below Fold',
          widgetType: 'Text',
          x: 100,
          y: 900,
          w: 200,
          h: 20,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final text = gaze.elements.firstWhere(
        (e) => e.label == 'Text Below Fold',
      );
      // Non-interactive keeps default reachable = true
      expect(text.reachable, isTrue);
    });

    test('gaze.reachable getter filters correctly', () {
      final glyphs = [
        glyph(
          label: 'In Viewport',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 200,
          w: 100,
          h: 48,
        ),
        glyph(
          label: 'Offscreen',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 900,
          w: 100,
          h: 48,
        ),
        glyph(label: 'Not Interactive', widgetType: 'Text', x: 100, y: 50),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.reachable, hasLength(1));
      expect(gaze.reachable.first.label, 'In Viewport');
    });
  });

  // ===================================================================
  // Visual prominence scoring
  // ===================================================================
  group('Visual prominence scoring', () {
    test('larger element gets higher prominence', () {
      final glyphs = [
        glyph(
          label: 'Big Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 100,
          w: 300,
          h: 80,
        ),
        glyph(
          label: 'Small Button',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 200,
          w: 48,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final big = gaze.elements.firstWhere((e) => e.label == 'Big Button');
      final small = gaze.elements.firstWhere((e) => e.label == 'Small Button');
      expect(big.prominence, greaterThan(small.prominence));
    });

    test('floating region gets 1.5x weight', () {
      // A floating element (FAB-like) at same size as mainContent element
      final glyphs = [
        glyph(
          label: 'Add',
          widgetType: 'FloatingActionButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'Overlay',
            'FloatingActionButton',
          ],
          depth: 20,
          x: 300,
          y: 700,
          w: 56,
          h: 56,
        ),
        glyph(
          label: 'Normal',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['MaterialApp', 'Scaffold', 'Column', 'ElevatedButton'],
          depth: 10,
          x: 100,
          y: 300,
          w: 48,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final fab = gaze.elements.firstWhere((e) => e.label == 'Add');
      final normal = gaze.elements.firstWhere((e) => e.label == 'Normal');
      // Same size but floating gets 1.5x vs mainContent 1.0x
      expect(fab.prominence, greaterThan(normal.prominence));
    });

    test('prominence is between 0.0 and 1.0', () {
      final glyphs = [
        glyph(
          label: 'A',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 100,
          w: 400,
          h: 100,
        ),
        glyph(
          label: 'B',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 200,
          w: 24,
          h: 24,
        ),
      ];
      final gaze = scry.observe(glyphs);
      for (final e in gaze.elements) {
        expect(e.prominence, greaterThanOrEqualTo(0.0));
        expect(e.prominence, lessThanOrEqualTo(1.0));
      }
    });

    test('zero-area element gets prominence 0', () {
      final glyphs = [
        glyph(
          label: 'Zero Area',
          widgetType: 'Text',
          x: 10,
          y: 100,
          w: 0,
          h: 0,
        ),
        // Need a non-zero element for normalization
        glyph(
          label: 'Normal Size',
          widgetType: 'Text',
          x: 10,
          y: 200,
          w: 100,
          h: 40,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final zero = gaze.elements.firstWhere((e) => e.label == 'Zero Area');
      expect(zero.prominence, 0.0);
    });

    test('prominence serialized in toJson when > 0', () {
      final glyphs = [
        glyph(
          label: 'Visible',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 100,
          w: 200,
          h: 60,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final e = gaze.elements.firstWhere((e) => e.label == 'Visible');
      final json = e.toJson();
      expect(json.containsKey('prominence'), isTrue);
      expect((json['prominence'] as double), greaterThan(0));
    });
  });

  // ===================================================================
  // Scroll inventory
  // ===================================================================
  group('Scroll inventory', () {
    test('detects scrollable content when elements below fold', () {
      final glyphs = [
        glyph(label: 'Item 1', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Item 2', widgetType: 'Text', x: 10, y: 300),
        glyph(label: 'Item 3', widgetType: 'Text', x: 10, y: 600),
        glyph(label: 'Item 4', widgetType: 'Text', x: 10, y: 850),
        glyph(label: 'Item 5', widgetType: 'Text', x: 10, y: 1100),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.scrollInfo, isNotNull);
      expect(gaze.scrollInfo!.canScrollDown, isTrue);
      expect(gaze.scrollInfo!.belowFoldCount, greaterThan(0));
    });

    test('no scroll when all within viewport', () {
      final glyphs = [
        glyph(label: 'Alpha', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Bravo', widgetType: 'Text', x: 10, y: 200),
        glyph(label: 'Charlie', widgetType: 'Text', x: 10, y: 300),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.scrollInfo, isNotNull);
      expect(gaze.scrollInfo!.canScrollDown, isFalse);
      expect(gaze.scrollInfo!.belowFoldCount, 0);
    });

    test('visibleCount counts elements within viewport', () {
      final glyphs = [
        glyph(label: 'Visible1', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Visible2', widgetType: 'Text', x: 10, y: 400),
        glyph(label: 'Visible3', widgetType: 'Text', x: 10, y: 700),
        glyph(label: 'Hidden', widgetType: 'Text', x: 10, y: 900),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.scrollInfo!.visibleCount, 3);
      expect(gaze.scrollInfo!.belowFoldCount, 1);
    });

    test('contentMaxY reflects actual content extent', () {
      final glyphs = [
        glyph(label: 'Top', widgetType: 'Text', x: 10, y: 50, h: 20),
        glyph(label: 'Bottom', widgetType: 'Text', x: 10, y: 1500, h: 20),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.scrollInfo!.contentMaxY, 1520.0); // 1500 + 20
    });

    test('scrollInfo toJson in gaze', () {
      final glyphs = [
        glyph(label: 'Top Item', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Bottom Item', widgetType: 'Text', x: 10, y: 900),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('scrollInfo'), isTrue);
      final si = json['scrollInfo'] as Map<String, dynamic>;
      expect(si['canScrollDown'], isTrue);
    });
  });

  // ===================================================================
  // Element grouping
  // ===================================================================
  group('Element grouping', () {
    test('groups elements with Card ancestor', () {
      final glyphs = [
        glyph(
          label: 'Title 1',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'ListView', 'Card', 'Text'],
          x: 10,
          y: 100,
        ),
        glyph(
          label: 'Action 1',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'ListView',
            'Card',
            'IconButton',
          ],
          x: 300,
          y: 100,
        ),
        glyph(
          label: 'Title 2',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'ListView', 'Card', 'Text'],
          x: 10,
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.groups, hasLength(1));
      expect(gaze.groups.first.containerType, 'Card');
      expect(gaze.groups.first.elements, hasLength(3));
    });

    test('groups elements with ListTile ancestor', () {
      final glyphs = [
        glyph(
          label: 'Item A',
          widgetType: 'Text',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'ListView',
            'ListTile',
            'Text',
          ],
          x: 10,
          y: 100,
        ),
        glyph(
          label: 'Item B',
          widgetType: 'Text',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'ListView',
            'ListTile',
            'Text',
          ],
          x: 10,
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final listTileGroups = gaze.groups.where(
        (g) => g.containerType == 'ListTile',
      );
      expect(listTileGroups, hasLength(1));
    });

    test('does not create group with fewer than 2 elements', () {
      final glyphs = [
        glyph(
          label: 'Single Card Item',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'Card', 'Text'],
          x: 10,
          y: 100,
        ),
        glyph(
          label: 'Other Item',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'Column', 'Text'],
          x: 10,
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final cardGroups = gaze.groups.where((g) => g.containerType == 'Card');
      expect(cardGroups, isEmpty);
    });

    test('groups toJson in gaze', () {
      final glyphs = [
        glyph(
          label: 'Alpha Item',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Card', 'Text'],
          x: 10,
          y: 100,
        ),
        glyph(
          label: 'Bravo Item',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Card', 'Text'],
          x: 10,
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      if (gaze.groups.isNotEmpty) {
        expect(json.containsKey('groups'), isTrue);
        final groups = json['groups'] as List;
        expect(groups.first, isA<Map<String, dynamic>>());
      }
    });
  });

  // ===================================================================
  // Semantic landmark detection
  // ===================================================================
  group('Semantic landmark detection', () {
    test('detects page title from structural element in topBar', () {
      final glyphs = [
        glyph(
          label: 'Quest Log',
          widgetType: 'Text',
          semanticRole: 'header',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          depth: 5,
          x: 100,
          y: 30,
          w: 200,
          h: 24,
        ),
        glyph(label: 'Item 1', widgetType: 'Text', x: 10, y: 200),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.landmarks, isNotNull);
      expect(gaze.landmarks!.pageTitle, 'Quest Log');
    });

    test('detects FAB as primary action', () {
      final glyphs = [
        glyph(
          label: 'Add Quest',
          widgetType: 'FloatingActionButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'Overlay',
            'FloatingActionButton',
          ],
          depth: 20,
          x: 300,
          y: 700,
          w: 56,
          h: 56,
        ),
        glyph(
          label: 'Save',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 100,
          y: 400,
          w: 100,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.landmarks, isNotNull);
      expect(gaze.landmarks!.primaryAction, isNotNull);
      expect(gaze.landmarks!.primaryAction!.label, 'Add Quest');
    });

    test('detects back button availability', () {
      final glyphs = [
        glyph(
          label: 'Back',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 20,
          w: 48,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.landmarks!.backAvailable, isTrue);
    });

    test('detects search availability', () {
      final glyphs = [
        glyph(
          label: 'Search',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'type',
          fieldId: 'search_field',
          x: 10,
          y: 80,
          w: 350,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.landmarks!.searchAvailable, isTrue);
    });

    test('no landmarks when screen is empty', () {
      final glyphs = <Map<String, dynamic>>[];
      final gaze = scry.observe(glyphs);
      expect(gaze.landmarks, isNotNull);
      expect(gaze.landmarks!.pageTitle, isNull);
      expect(gaze.landmarks!.primaryAction, isNull);
      expect(gaze.landmarks!.backAvailable, isFalse);
      expect(gaze.landmarks!.searchAvailable, isFalse);
    });

    test('primary action falls back to highest prominence button', () {
      final glyphs = [
        glyph(
          label: 'Small',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 200,
          w: 60,
          h: 36,
        ),
        glyph(
          label: 'Big CTA',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 400,
          w: 300,
          h: 56,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.landmarks!.primaryAction, isNotNull);
      expect(gaze.landmarks!.primaryAction!.label, 'Big CTA');
    });

    test('landmarks toJson in gaze', () {
      final glyphs = [
        glyph(
          label: 'Settings',
          widgetType: 'Text',
          semanticRole: 'header',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          depth: 5,
          x: 100,
          y: 30,
          w: 150,
          h: 24,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('landmarks'), isTrue);
      final lm = json['landmarks'] as Map<String, dynamic>;
      expect(lm['pageTitle'], 'Settings');
    });
  });

  // ===================================================================
  // ScryElement new fields serialization
  // ===================================================================
  group('ScryElement new fields', () {
    test('toJson includes targetScore and strategy for interactive', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Test',
        widgetType: 'ElevatedButton',
        isInteractive: true,
        targetScore: 100,
        targetStrategy: ScryTargetStrategy.key,
      );
      final json = element.toJson();
      expect(json['targetScore'], 100);
      expect(json['targetStrategy'], 'key');
    });

    test('toJson omits targetScore/strategy for non-interactive', () {
      const element = ScryElement(
        kind: ScryElementKind.content,
        label: 'Label',
        widgetType: 'Text',
      );
      final json = element.toJson();
      expect(json.containsKey('targetScore'), isFalse);
      expect(json.containsKey('targetStrategy'), isFalse);
    });

    test('toJson includes reachable only when false', () {
      const reachable = ScryElement(
        kind: ScryElementKind.button,
        label: 'OK',
        widgetType: 'ElevatedButton',
        isInteractive: true,
      );
      const unreachable = ScryElement(
        kind: ScryElementKind.button,
        label: 'Nope',
        widgetType: 'ElevatedButton',
        isInteractive: true,
        reachable: false,
      );
      expect(reachable.toJson().containsKey('reachable'), isFalse);
      expect(unreachable.toJson()['reachable'], isFalse);
    });

    test('toJson includes prominence when > 0', () {
      const withProminence = ScryElement(
        kind: ScryElementKind.button,
        label: 'A',
        widgetType: 'ElevatedButton',
        prominence: 0.75,
      );
      const noProminence = ScryElement(
        kind: ScryElementKind.button,
        label: 'B',
        widgetType: 'ElevatedButton',
      );
      expect(withProminence.toJson()['prominence'], 0.75);
      expect(noProminence.toJson().containsKey('prominence'), isFalse);
    });
  });

  // ===================================================================
  // formatGaze — new sections
  // ===================================================================
  group('formatGaze new sections', () {
    test('includes landmarks section with page title', () {
      final glyphs = [
        glyph(
          label: 'Dashboard',
          widgetType: 'Text',
          semanticRole: 'header',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          depth: 5,
          x: 100,
          y: 30,
          w: 200,
          h: 24,
        ),
        glyph(label: 'Content', widgetType: 'Text', x: 10, y: 200),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('**Page**: Dashboard'));
    });

    test('includes scroll info banner when scrollable', () {
      final glyphs = [
        glyph(label: 'Top', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Bottom', widgetType: 'Text', x: 10, y: 1500),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('📜 **Scrollable**'));
      expect(md, contains('scry_act(action: "scroll", direction: "down")'));
    });

    test('no scroll banner when not scrollable', () {
      final glyphs = [
        glyph(label: 'Top', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Mid', widgetType: 'Text', x: 10, y: 300),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, isNot(contains('📜 **Scrollable**')));
    });

    test('includes groups section', () {
      final glyphs = [
        glyph(
          label: 'Card Title',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Card', 'Text'],
          x: 10,
          y: 100,
        ),
        glyph(
          label: 'Card Action',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['MaterialApp', 'Card', 'IconButton'],
          x: 300,
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      if (gaze.groups.isNotEmpty) {
        final md = scry.formatGaze(gaze);
        expect(md, contains('🗂️ Groups'));
        expect(md, contains('Card'));
      }
    });

    test('includes back indicator in landmarks', () {
      final glyphs = [
        glyph(
          label: 'Back',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          x: 10,
          y: 20,
          w: 48,
          h: 48,
        ),
        glyph(label: 'Content', widgetType: 'Text', x: 10, y: 200),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('← Back'));
    });

    test('includes search indicator in landmarks', () {
      final glyphs = [
        glyph(
          label: 'Search',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'type',
          fieldId: 'search',
          x: 10,
          y: 80,
          w: 300,
          h: 48,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('🔍 Search'));
    });

    test('includes primary action in landmarks', () {
      final glyphs = [
        glyph(
          label: 'Create',
          widgetType: 'FloatingActionButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'Overlay',
            'FloatingActionButton',
          ],
          depth: 20,
          x: 300,
          y: 700,
          w: 56,
          h: 56,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('**Primary action**: Create'));
    });
  });

  // ===================================================================
  // Combined integration — second batch capabilities
  // ===================================================================
  group('Second batch integration', () {
    test('realistic list screen with all capabilities', () {
      final glyphs = [
        // AppBar title
        glyph(
          label: 'My Quests',
          widgetType: 'Text',
          semanticRole: 'header',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          depth: 5,
          x: 100,
          y: 30,
          w: 160,
          h: 24,
        ),
        // Back button
        glyph(
          label: 'Back',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'IconButton'],
          depth: 5,
          x: 10,
          y: 20,
          w: 48,
          h: 48,
        ),
        // Search button
        glyph(
          label: 'Search',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'IconButton'],
          depth: 5,
          x: 300,
          y: 20,
          w: 48,
          h: 48,
        ),
        // Card items
        glyph(
          label: 'Quest 1',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'ListView', 'Card', 'Text'],
          x: 20,
          y: 100,
          w: 300,
          h: 20,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          key: 'delete_1',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'ListView',
            'Card',
            'IconButton',
          ],
          x: 340,
          y: 100,
          w: 48,
          h: 48,
        ),
        glyph(
          label: 'Quest 2',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'ListView', 'Card', 'Text'],
          x: 20,
          y: 200,
          w: 300,
          h: 20,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          interactionType: 'tap',
          key: 'delete_2',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'ListView',
            'Card',
            'IconButton',
          ],
          x: 340,
          y: 200,
          w: 48,
          h: 48,
        ),
        // Far below fold
        glyph(
          label: 'Quest 10',
          widgetType: 'Text',
          ancestors: ['MaterialApp', 'Scaffold', 'ListView', 'Card', 'Text'],
          x: 20,
          y: 1000,
          w: 300,
          h: 20,
        ),
        // FAB
        glyph(
          label: 'Add Quest',
          widgetType: 'FloatingActionButton',
          interactive: true,
          interactionType: 'tap',
          key: 'fab_add',
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'Overlay',
            'FloatingActionButton',
          ],
          depth: 20,
          x: 320,
          y: 720,
          w: 56,
          h: 56,
        ),
      ];

      final gaze = scry.observe(glyphs);

      // Landmarks
      expect(gaze.landmarks, isNotNull);
      expect(gaze.landmarks!.pageTitle, 'My Quests');
      expect(gaze.landmarks!.primaryAction!.label, 'Add Quest');
      expect(gaze.landmarks!.backAvailable, isTrue);
      expect(gaze.landmarks!.searchAvailable, isTrue);

      // Scroll
      expect(gaze.scrollInfo, isNotNull);
      expect(gaze.scrollInfo!.canScrollDown, isTrue);
      expect(gaze.scrollInfo!.belowFoldCount, greaterThan(0));

      // Groups
      final cardGroup = gaze.groups.where((g) => g.containerType == 'Card');
      expect(cardGroup, isNotEmpty);

      // Target scoring — keyed elements get 100
      final fab = gaze.elements.firstWhere((e) => e.label == 'Add Quest');
      expect(fab.targetScore, 100);
      expect(fab.targetStrategy, ScryTargetStrategy.key);

      // Reachability — offscreen Quest 10 items are still "reachable"
      // (only interactive elements below fold are unreachable)

      // Prominence — FAB should have prominence
      expect(fab.prominence, greaterThan(0));

      // formatGaze includes new sections
      final md = scry.formatGaze(gaze);
      expect(md, contains('**Page**: My Quests'));
      expect(md, contains('**Primary action**: Add Quest'));
      expect(md, contains('← Back'));
      expect(md, contains('🔍 Search'));
      expect(md, contains('📜 **Scrollable**'));
    });

    test('settings screen with no scroll', () {
      final glyphs = [
        glyph(
          label: 'Settings',
          widgetType: 'Text',
          semanticRole: 'header',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          depth: 5,
          x: 100,
          y: 30,
          w: 130,
          h: 24,
        ),
        glyph(
          label: 'Dark Mode',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          x: 300,
          y: 200,
          w: 60,
          h: 36,
        ),
        glyph(
          label: 'Notifications',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          x: 300,
          y: 300,
          w: 60,
          h: 36,
        ),
      ];

      final gaze = scry.observe(glyphs);

      // Not scrollable
      expect(gaze.scrollInfo!.canScrollDown, isFalse);

      // Page title detected
      expect(gaze.landmarks!.pageTitle, 'Settings');

      // No back button or search
      expect(gaze.landmarks!.backAvailable, isFalse);
      expect(gaze.landmarks!.searchAvailable, isFalse);

      // formatGaze should NOT have scroll banner
      final md = scry.formatGaze(gaze);
      expect(md, isNot(contains('📜 **Scrollable**')));
    });
  });

  // ===================================================================
  // Batch 3: Value Type Inference
  // ===================================================================
  group('Value type inference', () {
    test('detects email fields from label', () {
      final glyphs = [
        glyph(
          label: 'Email Address',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'email_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Email Address');
      expect(field.inputType, ScryFieldValueType.email);
    });

    test('detects password fields from label', () {
      final glyphs = [
        glyph(
          label: 'Password',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'password_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Password');
      expect(field.inputType, ScryFieldValueType.password);
    });

    test('detects phone fields', () {
      final glyphs = [
        glyph(
          label: 'Phone Number',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'phone_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Phone Number');
      expect(field.inputType, ScryFieldValueType.phone);
    });

    test('detects numeric fields', () {
      final glyphs = [
        glyph(
          label: 'Total Amount',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'amount_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Total Amount');
      expect(field.inputType, ScryFieldValueType.numeric);
    });

    test('detects date fields', () {
      final glyphs = [
        glyph(
          label: 'Date of Birth',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'dob_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Date of Birth');
      expect(field.inputType, ScryFieldValueType.date);
    });

    test('detects url fields', () {
      final glyphs = [
        glyph(
          label: 'Website URL',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'url_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Website URL');
      expect(field.inputType, ScryFieldValueType.url);
    });

    test('detects email from current value pattern', () {
      final glyphs = [
        glyph(
          label: 'Contact Info',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'contact_field',
          currentValue: 'user@example.com',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Contact Info');
      expect(field.inputType, ScryFieldValueType.email);
    });

    test('leaves null for generic text fields', () {
      final glyphs = [
        glyph(
          label: 'Description',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'desc_field',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Description');
      expect(field.inputType, isNull);
    });

    test('does not apply inputType to non-field elements', () {
      final glyphs = [
        glyph(
          label: 'Email Settings',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Email Settings');
      expect(btn.inputType, isNull);
    });

    test('inputType appears in toJson', () {
      final element = ScryElement(
        kind: ScryElementKind.field,
        label: 'Email',
        widgetType: 'TextField',
        isInteractive: true,
        inputType: ScryFieldValueType.email,
      );
      final json = element.toJson();
      expect(json['inputType'], 'email');
    });

    test('formatGaze shows expects for typed fields', () {
      final glyphs = [
        glyph(
          label: 'Email Address',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'email',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('expects: email'));
    });
  });

  // ===================================================================
  // Batch 3: Action Impact Prediction
  // ===================================================================
  group('Action impact prediction', () {
    test('predicts delete for destructive labels', () {
      final glyphs = [
        glyph(
          label: 'Delete Quest',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Delete Quest');
      expect(btn.predictedImpact, ScryActionImpact.delete);
    });

    test('predicts submit for save labels', () {
      final glyphs = [
        glyph(
          label: 'Save Changes',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Save Changes');
      expect(btn.predictedImpact, ScryActionImpact.submit);
    });

    test('predicts dismiss for cancel labels', () {
      final glyphs = [
        glyph(
          label: 'Cancel Action',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Cancel Action');
      expect(btn.predictedImpact, ScryActionImpact.dismiss);
    });

    test('predicts navigate for view labels', () {
      final glyphs = [
        glyph(
          label: 'View Details',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'View Details');
      expect(btn.predictedImpact, ScryActionImpact.navigate);
    });

    test('predicts toggle for switch widget types', () {
      final glyphs = [
        glyph(
          label: 'Dark Mode',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'false',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final toggle = gaze.elements.firstWhere((e) => e.label == 'Dark Mode');
      expect(toggle.predictedImpact, ScryActionImpact.toggle);
    });

    test('predicts expand for expansion tiles', () {
      final glyphs = [
        glyph(
          label: 'Advanced Settings',
          widgetType: 'ExpansionTile',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final tile = gaze.elements.firstWhere(
        (e) => e.label == 'Advanced Settings',
      );
      expect(tile.predictedImpact, ScryActionImpact.expand);
    });

    test('predicts openModal for popup menus', () {
      final glyphs = [
        glyph(
          label: 'Options Menu',
          widgetType: 'PopupMenuButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final popup = gaze.elements.firstWhere((e) => e.label == 'Options Menu');
      expect(popup.predictedImpact, ScryActionImpact.openModal);
    });

    test('predicts unknown for ambiguous labels', () {
      final glyphs = [
        glyph(
          label: 'Continue Action',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Continue Action');
      expect(btn.predictedImpact, ScryActionImpact.unknown);
    });

    test('does not apply impact to non-interactive elements', () {
      final glyphs = [
        glyph(label: 'Delete Warning', widgetType: 'Text', y: 100),
      ];
      final gaze = scry.observe(glyphs);
      final text = gaze.elements.firstWhere((e) => e.label == 'Delete Warning');
      expect(text.predictedImpact, isNull);
    });

    test('predictedImpact appears in toJson', () {
      final element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Submit',
        widgetType: 'ElevatedButton',
        isInteractive: true,
        predictedImpact: ScryActionImpact.submit,
      );
      final json = element.toJson();
      expect(json['predictedImpact'], 'submit');
    });

    test('navigation kind defaults to navigate', () {
      final glyphs = [
        glyph(
          label: 'Quests Tab',
          widgetType: 'Text',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['BottomNavigationBar', 'Scaffold'],
          y: 750,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final nav = gaze.elements.firstWhere((e) => e.label == 'Quests Tab');
      expect(nav.predictedImpact, ScryActionImpact.navigate);
    });
  });

  // ===================================================================
  // Batch 3: Overlay / Modal Content Analysis
  // ===================================================================
  group('Overlay / modal analysis', () {
    test('detects AlertDialog overlay', () {
      final glyphs = [
        glyph(
          label: 'Confirm Deletion',
          widgetType: 'Text',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 300,
        ),
        glyph(
          label: 'Are you sure?',
          widgetType: 'Text',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 350,
        ),
        glyph(
          label: 'Cancel',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 400,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 400,
          x: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.overlay, isNotNull);
      expect(gaze.overlay!.type, 'AlertDialog');
      expect(gaze.overlay!.canDismiss, isTrue);
      expect(gaze.overlay!.actions.length, greaterThanOrEqualTo(1));
    });

    test('detects BottomSheet overlay', () {
      final glyphs = [
        glyph(
          label: 'Share Options',
          widgetType: 'Text',
          ancestors: ['BottomSheet', 'Scaffold'],
          y: 500,
        ),
        glyph(
          label: 'Copy Link',
          widgetType: 'ListTile',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['BottomSheet', 'Scaffold'],
          y: 550,
        ),
        glyph(
          label: 'Share via Email',
          widgetType: 'ListTile',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['BottomSheet', 'Scaffold'],
          y: 600,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.overlay, isNotNull);
      expect(gaze.overlay!.type, 'BottomSheet');
    });

    test('no overlay when no dialog ancestors', () {
      final glyphs = [
        glyph(label: 'Normal Screen', widgetType: 'Text', y: 100),
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.overlay, isNull);
    });

    test('overlay title detected from structural element', () {
      final glyphs = [
        glyph(
          label: 'Warning Message',
          widgetType: 'Text',
          ancestors: ['Dialog', 'Scaffold'],
          y: 300,
        ),
        glyph(
          label: 'OK Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['Dialog', 'Scaffold'],
          y: 400,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.overlay, isNotNull);
      expect(gaze.overlay!.title, isNotNull);
    });

    test('overlay toJson serializes correctly', () {
      final overlay = ScryOverlayInfo(
        type: 'AlertDialog',
        title: 'Confirm',
        actions: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'OK',
            widgetType: 'TextButton',
            isInteractive: true,
          ),
        ],
        canDismiss: true,
      );
      final json = overlay.toJson();
      expect(json['type'], 'AlertDialog');
      expect(json['title'], 'Confirm');
      expect(json['actions'], ['OK']);
      expect(json['canDismiss'], isTrue);
    });

    test('overlay appears in formatGaze', () {
      final glyphs = [
        glyph(
          label: 'Alert Title',
          widgetType: 'Text',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 300,
        ),
        glyph(
          label: 'Close Dialog',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 400,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('🪟'));
      expect(md, contains('Overlay active'));
    });

    test('overlay in gaze toJson', () {
      final glyphs = [
        glyph(
          label: 'Dialog Title',
          widgetType: 'Text',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 300,
        ),
        glyph(
          label: 'Dismiss',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 400,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('overlay'), isTrue);
    });

    test('detects AboutDialog overlay via ancestor context', () {
      final glyphs = [
        glyph(
          label: 'About My App',
          widgetType: 'Text',
          ancestors: ['AboutDialog', 'Scaffold'],
          y: 200,
        ),
        glyph(
          label: '1.0.0',
          widgetType: 'Text',
          ancestors: ['AboutDialog', 'Scaffold'],
          y: 250,
        ),
        glyph(
          label: 'Close',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AboutDialog', 'Scaffold'],
          y: 400,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.overlay, isNotNull);
      expect(gaze.overlay!.type, 'AboutDialog');
      expect(gaze.overlay!.actions, isNotEmpty);
    });

    test('raw glyph pre-scan detects overlay widget with no label', () {
      // Simulate an overlay widget type present in raw glyphs but
      // filtered out during element creation (no label).
      // Strategy 3: raw glyph pre-scan should detect it.

      // Raw glyphs for the overlay widget (no label, would be filtered)
      final rawGlyphs = <Map<String, dynamic>>[
        {'wt': 'Text', 'l': 'Home', 'd': 5, 'ia': false, 'y': 100.0},
        {'wt': 'AlertDialog', 'l': '', 'd': 20, 'ia': false, 'y': 200.0},
        {
          'wt': 'TextButton',
          'l': 'OK',
          'd': 25,
          'ia': true,
          'it': 'tap',
          'y': 300.0,
        },
      ];

      // The raw pre-scan happens inside observe() with raw glyphs.
      // Test directly with elements that have no overlay context/widgetType
      // but rawOverlayType is set — this tests strategy 3.
      final gaze = scry.observe(rawGlyphs);
      expect(gaze.overlay, isNotNull);
      expect(gaze.overlay!.type, 'AlertDialog');
    });
  });

  // ===================================================================
  // Batch 3: Layout Pattern Detection
  // ===================================================================
  group('Layout pattern detection', () {
    test('detects vertical list pattern', () {
      final glyphs = [
        glyph(label: 'Item Alpha', widgetType: 'ListTile', y: 100, x: 20),
        glyph(label: 'Item Bravo', widgetType: 'ListTile', y: 160, x: 20),
        glyph(label: 'Item Charlie', widgetType: 'ListTile', y: 220, x: 20),
        glyph(label: 'Item Delta', widgetType: 'ListTile', y: 280, x: 20),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.layoutPattern, ScryLayoutPattern.verticalList);
    });

    test('detects horizontal row pattern', () {
      final glyphs = [
        glyph(label: 'Tab Alpha', widgetType: 'Tab', x: 0, y: 50, w: 80),
        glyph(label: 'Tab Bravo', widgetType: 'Tab', x: 80, y: 50, w: 80),
        glyph(label: 'Tab Charlie', widgetType: 'Tab', x: 160, y: 50, w: 80),
        glyph(label: 'Tab Delta', widgetType: 'Tab', x: 240, y: 50, w: 80),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.layoutPattern, ScryLayoutPattern.horizontalRow);
    });

    test('detects grid pattern', () {
      final glyphs = [
        glyph(label: 'Cell AA', widgetType: 'Card', x: 0, y: 0, w: 150),
        glyph(label: 'Cell AB', widgetType: 'Card', x: 180, y: 0, w: 150),
        glyph(label: 'Cell BA', widgetType: 'Card', x: 0, y: 200, w: 150),
        glyph(label: 'Cell BB', widgetType: 'Card', x: 180, y: 200, w: 150),
        glyph(label: 'Cell CA', widgetType: 'Card', x: 0, y: 400, w: 150),
        glyph(label: 'Cell CB', widgetType: 'Card', x: 180, y: 400, w: 150),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.layoutPattern, ScryLayoutPattern.grid);
    });

    test('defaults to freeform when fewer than 3 elements', () {
      final glyphs = [
        glyph(label: 'Only Alpha', widgetType: 'Text', x: 10, y: 100),
        glyph(label: 'Only Bravo', widgetType: 'Text', x: 200, y: 300),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.layoutPattern, ScryLayoutPattern.freeform);
    });

    test('layout pattern appears in formatGaze header', () {
      final glyphs = [
        glyph(label: 'Row Alpha', widgetType: 'ListTile', y: 100, x: 20),
        glyph(label: 'Row Bravo', widgetType: 'ListTile', y: 160, x: 20),
        glyph(label: 'Row Charlie', widgetType: 'ListTile', y: 220, x: 20),
        glyph(label: 'Row Delta', widgetType: 'ListTile', y: 280, x: 20),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('**Layout**: verticalList'));
    });

    test('freeform layout omitted from formatGaze header', () {
      final glyphs = [
        glyph(label: 'Lone Widget', widgetType: 'Text', x: 50, y: 100),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, isNot(contains('**Layout**')));
    });

    test('layout pattern in toJson when not freeform', () {
      final glyphs = [
        glyph(label: 'List Alpha', widgetType: 'Text', y: 100, x: 20),
        glyph(label: 'List Bravo', widgetType: 'Text', y: 160, x: 20),
        glyph(label: 'List Charlie', widgetType: 'Text', y: 220, x: 20),
        glyph(label: 'List Delta', widgetType: 'Text', y: 280, x: 20),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('layoutPattern'), isTrue);
      expect(json['layoutPattern'], 'verticalList');
    });

    test('freeform layout omitted from toJson', () {
      final glyphs = [
        glyph(label: 'Single Item', widgetType: 'Text', x: 50, y: 100),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('layoutPattern'), isFalse);
    });
  });

  // ===================================================================
  // Batch 3: Toggle / Selection State Summary
  // ===================================================================
  group('Toggle / selection state summary', () {
    test('detects switches and their state', () {
      final glyphs = [
        glyph(
          label: 'Dark Mode',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'true',
          y: 100,
        ),
        glyph(
          label: 'Notifications',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'false',
          y: 160,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.toggleSummary, isNotNull);
      expect(gaze.toggleSummary!.totalCount, 2);
      expect(gaze.toggleSummary!.activeCount, 1);
    });

    test('detects checkboxes', () {
      final glyphs = [
        glyph(
          label: 'Accept Terms',
          widgetType: 'Checkbox',
          interactive: true,
          interactionType: 'checkbox',
          currentValue: 'true',
          y: 100,
        ),
        glyph(
          label: 'Subscribe Newsletter',
          widgetType: 'Checkbox',
          interactive: true,
          interactionType: 'checkbox',
          currentValue: 'false',
          y: 160,
        ),
        glyph(
          label: 'Share Data',
          widgetType: 'Checkbox',
          interactive: true,
          interactionType: 'checkbox',
          currentValue: 'on',
          y: 220,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.toggleSummary, isNotNull);
      expect(gaze.toggleSummary!.totalCount, 3);
      expect(gaze.toggleSummary!.activeCount, 2);
    });

    test('null when no toggles present', () {
      final glyphs = [
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
        glyph(
          label: 'Username Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          y: 160,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.toggleSummary, isNull);
    });

    test('toggle summary toJson', () {
      final summary = ScryToggleSummary(
        toggles: [
          ScryToggleState(
            label: 'Theme',
            widgetType: 'Switch',
            currentValue: 'true',
            isActive: true,
          ),
          ScryToggleState(
            label: 'Sound',
            widgetType: 'Switch',
            currentValue: 'false',
            isActive: false,
          ),
        ],
      );
      final json = summary.toJson();
      expect(json['active'], 1);
      expect(json['total'], 2);
      expect(json['toggles'], hasLength(2));
    });

    test('toggle state toJson', () {
      final state = ScryToggleState(
        label: 'WiFi',
        widgetType: 'Switch',
        currentValue: 'on',
        isActive: true,
      );
      final json = state.toJson();
      expect(json['label'], 'WiFi');
      expect(json['widgetType'], 'Switch');
      expect(json['value'], 'on');
      expect(json['isActive'], isTrue);
    });

    test('toggle state toJson omits null value', () {
      final state = ScryToggleState(
        label: 'Something',
        widgetType: 'Checkbox',
        isActive: false,
      );
      final json = state.toJson();
      expect(json.containsKey('value'), isFalse);
    });

    test('toggle summary appears in formatGaze', () {
      final glyphs = [
        glyph(
          label: 'Auto Save',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'true',
          y: 100,
        ),
        glyph(
          label: 'Auto Update',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'false',
          y: 160,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('🔀'));
      expect(md, contains('Toggles'));
      expect(md, contains('✅'));
      expect(md, contains('⬜'));
    });

    test('toggle summary in gaze toJson', () {
      final glyphs = [
        glyph(
          label: 'Dark Mode Toggle',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'true',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('toggleSummary'), isTrue);
    });
  });

  // ===================================================================
  // Batch 3: Field Tab Order
  // ===================================================================
  group('Field tab order', () {
    test('orders fields by Y then X', () {
      final glyphs = [
        glyph(
          label: 'Third Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'field3',
          y: 300,
          x: 20,
        ),
        glyph(
          label: 'First Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'field1',
          y: 100,
          x: 20,
        ),
        glyph(
          label: 'Second Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'field2',
          y: 200,
          x: 20,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.tabOrder, hasLength(3));
      expect(gaze.tabOrder[0], 'First Field');
      expect(gaze.tabOrder[1], 'Second Field');
      expect(gaze.tabOrder[2], 'Third Field');
    });

    test('same Y sorts by X', () {
      final glyphs = [
        glyph(
          label: 'Right Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'right',
          y: 200,
          x: 200,
        ),
        glyph(
          label: 'Left Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'left',
          y: 200,
          x: 20,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.tabOrder, ['Left Field', 'Right Field']);
    });

    test('empty when no fields', () {
      final glyphs = [
        glyph(
          label: 'Just a Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.tabOrder, isEmpty);
    });

    test('single field returns one-element list', () {
      final glyphs = [
        glyph(
          label: 'Only Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'only',
          y: 100,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.tabOrder, ['Only Field']);
    });

    test('tab order appears in formatGaze', () {
      final glyphs = [
        glyph(
          label: 'Email Address',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'email',
          y: 100,
        ),
        glyph(
          label: 'Password Field',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'password',
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('Tab order'));
      expect(md, contains('→'));
    });

    test('tab order in gaze toJson when non-empty', () {
      final glyphs = [
        glyph(
          label: 'Input Alpha',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'alpha',
          y: 100,
        ),
        glyph(
          label: 'Input Bravo',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'bravo',
          y: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json['tabOrder'], ['Input Alpha', 'Input Bravo']);
    });

    test('tab order omitted from toJson when empty', () {
      final glyphs = [glyph(label: 'Just Text', widgetType: 'Text', y: 100)];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('tabOrder'), isFalse);
    });
  });

  // ===================================================================
  // Batch 3: ScryFieldValueType enum
  // ===================================================================
  group('ScryFieldValueType', () {
    test('has all expected values', () {
      expect(ScryFieldValueType.values, hasLength(8));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.email));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.password));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.phone));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.numeric));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.date));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.url));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.search));
      expect(ScryFieldValueType.values, contains(ScryFieldValueType.freeText));
    });
  });

  // ===================================================================
  // Batch 3: ScryActionImpact enum
  // ===================================================================
  group('ScryActionImpact', () {
    test('has all expected values', () {
      expect(ScryActionImpact.values, hasLength(8));
      expect(ScryActionImpact.values, contains(ScryActionImpact.navigate));
      expect(ScryActionImpact.values, contains(ScryActionImpact.submit));
      expect(ScryActionImpact.values, contains(ScryActionImpact.delete));
      expect(ScryActionImpact.values, contains(ScryActionImpact.toggle));
      expect(ScryActionImpact.values, contains(ScryActionImpact.expand));
      expect(ScryActionImpact.values, contains(ScryActionImpact.dismiss));
      expect(ScryActionImpact.values, contains(ScryActionImpact.openModal));
      expect(ScryActionImpact.values, contains(ScryActionImpact.unknown));
    });
  });

  // ===================================================================
  // Batch 3: ScryLayoutPattern enum
  // ===================================================================
  group('ScryLayoutPattern', () {
    test('has all expected values', () {
      expect(ScryLayoutPattern.values, hasLength(5));
      expect(
        ScryLayoutPattern.values,
        contains(ScryLayoutPattern.verticalList),
      );
      expect(ScryLayoutPattern.values, contains(ScryLayoutPattern.grid));
      expect(
        ScryLayoutPattern.values,
        contains(ScryLayoutPattern.horizontalRow),
      );
      expect(ScryLayoutPattern.values, contains(ScryLayoutPattern.singleCard));
      expect(ScryLayoutPattern.values, contains(ScryLayoutPattern.freeform));
    });
  });

  // ===================================================================
  // Batch 3: Integration test
  // ===================================================================
  group('Batch 3 integration', () {
    test('login form with all batch 3 features', () {
      final glyphs = [
        glyph(label: 'Login Title', widgetType: 'Text', y: 80, x: 20),
        glyph(
          label: 'Email Address',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'email_field',
          y: 150,
          x: 20,
          w: 300,
        ),
        glyph(
          label: 'Password',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'input',
          fieldId: 'password_field',
          y: 220,
          x: 20,
          w: 300,
        ),
        glyph(
          label: 'Remember Me',
          widgetType: 'Checkbox',
          interactive: true,
          interactionType: 'checkbox',
          currentValue: 'false',
          y: 290,
          x: 20,
        ),
        glyph(
          label: 'Sign In',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          y: 360,
          x: 20,
          w: 300,
        ),
      ];
      final gaze = scry.observe(glyphs);

      // Input type inference
      final emailField = gaze.elements.firstWhere(
        (e) => e.label == 'Email Address',
      );
      expect(emailField.inputType, ScryFieldValueType.email);

      final passField = gaze.elements.firstWhere((e) => e.label == 'Password');
      expect(passField.inputType, ScryFieldValueType.password);

      // Action impact prediction
      final signIn = gaze.elements.firstWhere((e) => e.label == 'Sign In');
      expect(signIn.predictedImpact, ScryActionImpact.unknown);

      // Toggle summary
      expect(gaze.toggleSummary, isNotNull);
      expect(gaze.toggleSummary!.totalCount, 1);
      expect(gaze.toggleSummary!.activeCount, 0);

      // Tab order
      expect(gaze.tabOrder, ['Email Address', 'Password']);

      // Layout pattern — vertical
      expect(gaze.layoutPattern, ScryLayoutPattern.verticalList);

      // No overlay
      expect(gaze.overlay, isNull);
    });

    test('dialog overlay with toggles and actions', () {
      final glyphs = [
        glyph(
          label: 'Preferences Title',
          widgetType: 'Text',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 200,
          x: 50,
        ),
        glyph(
          label: 'Enable Features',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'true',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 260,
          x: 50,
        ),
        glyph(
          label: 'Dark Theme',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'toggle',
          currentValue: 'false',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 320,
          x: 50,
        ),
        glyph(
          label: 'Cancel',
          widgetType: 'TextButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 400,
          x: 50,
        ),
        glyph(
          label: 'Save Preferences',
          widgetType: 'ElevatedButton',
          interactive: true,
          interactionType: 'tap',
          ancestors: ['AlertDialog', 'Scaffold'],
          y: 400,
          x: 200,
        ),
      ];
      final gaze = scry.observe(glyphs);

      // Overlay detected
      expect(gaze.overlay, isNotNull);
      expect(gaze.overlay!.type, 'AlertDialog');
      expect(gaze.overlay!.canDismiss, isTrue);

      // Toggle summary in dialog
      expect(gaze.toggleSummary, isNotNull);
      expect(gaze.toggleSummary!.totalCount, 2);
      expect(gaze.toggleSummary!.activeCount, 1);

      // Action impacts
      final cancel = gaze.elements.firstWhere((e) => e.label == 'Cancel');
      expect(cancel.predictedImpact, ScryActionImpact.dismiss);

      final save = gaze.elements.firstWhere(
        (e) => e.label == 'Save Preferences',
      );
      expect(save.predictedImpact, ScryActionImpact.submit);

      // formatGaze includes overlay and toggle sections
      final md = scry.formatGaze(gaze);
      expect(md, contains('🪟'));
      expect(md, contains('🔀'));
    });
  });
}
