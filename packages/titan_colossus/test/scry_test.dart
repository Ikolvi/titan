import 'package:test/test.dart';
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
    'x': 0.0,
    'y': 0.0,
    'w': 100.0,
    'h': 40.0,
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
        glyph(
          label: 'Sign Out',
          interactive: true,
          widgetType: 'IconButton',
        ),
        glyph(
          label: 'About',
          interactive: true,
          widgetType: 'IconButton',
        ),
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
        glyph(
          label: 'Quests',
          interactive: true,
          widgetType: 'NavigationBar',
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.navigation, hasLength(1));
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
      final glyphs = [
        glyph(label: 'Questboard', widgetType: 'AppBar'),
      ];

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
      expect(
        gaze.elements.where((e) => e.label == 'Kael'),
        hasLength(1),
      );
    });

    test('excludes empty and short labels', () {
      final glyphs = [
        glyph(label: ''),
        glyph(label: 'A'),
        glyph(label: 'OK'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.elements, hasLength(1));
      expect(gaze.elements.first.label, 'OK');
    });

    test('excludes IconData labels', () {
      final glyphs = [
        glyph(label: 'IconData(U+0E15A)'),
        glyph(label: 'Kael'),
      ];

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
        glyph(
          label: 'Save',
          interactive: true,
          widgetType: 'ElevatedButton',
        ),
      ];

      final gaze = scry.observe(glyphs);

      final deleteBtn = gaze.buttons.firstWhere(
        (e) => e.label == 'Delete Account',
      );
      expect(deleteBtn.gated, isTrue);

      final saveBtn = gaze.buttons.firstWhere(
        (e) => e.label == 'Save',
      );
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
        final glyphs = [
          glyph(label: label, interactive: true),
        ];
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
      final glyphs = [
        glyph(label: 'Delete this file', interactive: false),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.content.first.gated, isFalse);
    });

    test('preserves route information', () {
      final gaze = scry.observe(
        [glyph(label: 'OK')],
        route: '/quests',
      );

      expect(gaze.route, '/quests');
    });

    test('tracks glyph count', () {
      final glyphs = [
        glyph(label: 'A'),
        glyph(label: 'B'),
        glyph(label: 'CC'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.glyphCount, 3);
    });

    test('promotes interactive to button even with nav ancestor label', () {
      // If "Hero" is interactive AND has a nav ancestor, it's navigation
      // (navigation takes precedence over generic button)
      final glyphs = [
        glyph(
          label: 'Hero',
          interactive: true,
          widgetType: 'GestureDetector',
        ),
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
        glyph(
          label: 'Questboard',
          ancestors: ['_AppBarTitleBox', 'Semantics'],
        ),
        glyph(label: 'Questboard', widgetType: 'AppBar'),
        // Buttons
        glyph(
          label: 'Sign Out',
          interactive: true,
          widgetType: 'IconButton',
        ),
        glyph(label: 'Sign Out', widgetType: 'Tooltip'),
        glyph(
          label: 'About',
          interactive: true,
          widgetType: 'IconButton',
        ),
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
        glyph(
          label: 'Hero',
          interactive: true,
          widgetType: 'GestureDetector',
        ),
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
      expect(
        gaze.structural.map((e) => e.label),
        contains('Questboard'),
      );

      // Navigation: Quests, Hero (nav destination ancestors)
      expect(gaze.navigation.map((e) => e.label), contains('Quests'));
      expect(gaze.navigation.map((e) => e.label), contains('Hero'));

      // Buttons: Sign Out, About, Complete Quest
      expect(gaze.buttons.map((e) => e.label), contains('Sign Out'));
      expect(gaze.buttons.map((e) => e.label), contains('About'));
      expect(
        gaze.buttons.map((e) => e.label),
        contains('Complete Quest'),
      );

      // Content: Kael, quest names/scores
      expect(gaze.content.map((e) => e.label), contains('Kael'));
      expect(
        gaze.content.map((e) => e.label),
        contains('Slay the Bug Dragon'),
      );

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
      expect(gaze.content.map((e) => e.label),
          contains('Sign in to continue to /'));
    });
  });

  // ===================================================================
  // Scry.formatGaze
  // ===================================================================
  group('Scry.formatGaze', () {
    test('includes route and glyph count in header', () {
      const gaze = ScryGaze(
        elements: [],
        route: '/quests',
        glyphCount: 177,
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('# Current Screen'));
      expect(md, contains('/quests'));
      expect(md, contains('177 glyphs'));
    });

    test('marks login screen', () {
      const gaze = ScryGaze(
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

    test('lists text fields with fieldId', () {
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

    test('builds enterText campaign with value', () {
      final campaign = scry.buildActionCampaign(
        action: 'enterText',
        fieldId: 'heroName',
        value: 'Titan',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'enterText');
      expect((step['target'] as Map)['fieldId'], 'heroName');
      expect(step['value'], 'Titan');
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
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'OK',
      );

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
      final glyphs = [
        glyph(label: 'Disconnect', interactive: true),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.gated, hasLength(1));
    });
  });
}
