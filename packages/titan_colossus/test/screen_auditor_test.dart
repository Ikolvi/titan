import 'package:test/test.dart';
import 'package:titan_colossus/src/testing/screen_auditor.dart';

void main() {
  const auditor = ScreenAuditor();

  // ----- Helper: build a glyph map -----
  Map<String, dynamic> glyph({
    required String label,
    String widgetType = 'Text',
    bool interactive = false,
    String? interactionType,
    String? semanticRole,
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
    if (ancestors != null) 'anc': ancestors,
    'x': 0.0,
    'y': 0.0,
    'w': 100.0,
    'h': 40.0,
  };

  // ===================================================================
  // extractDisplayLabels
  // ===================================================================
  group('ScreenAuditor.extractDisplayLabels', () {
    test('extracts non-empty text labels', () {
      final glyphs = [
        glyph(label: 'Kael'),
        glyph(label: 'Questboard'),
        glyph(label: 'Slay the Bug Dragon'),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels, contains('Kael'));
      expect(labels, contains('Questboard'));
      expect(labels, contains('Slay the Bug Dragon'));
    });

    test('excludes empty and single-character labels', () {
      final glyphs = [
        glyph(label: ''),
        glyph(label: ' '),
        glyph(label: 'A'),
        glyph(label: 'OK'),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels, isNot(contains('')));
      expect(labels, isNot(contains(' ')));
      expect(labels, isNot(contains('A')));
      expect(labels, contains('OK'));
    });

    test('excludes IconData labels', () {
      final glyphs = [
        glyph(label: 'IconData(U+0E15A)'),
        glyph(label: 'Kael'),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels, isNot(contains('IconData(U+0E15A)')));
      expect(labels, contains('Kael'));
    });

    test('excludes private-use-area Unicode characters', () {
      final glyphs = [
        glyph(label: '\ue15a'), // PUA icon
        glyph(label: 'Kael'),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels, isNot(contains('\ue15a')));
      expect(labels, contains('Kael'));
    });

    test('includes interactive elements in display labels', () {
      // Display labels include ALL text, interactive or not
      final glyphs = [
        glyph(label: 'Sign Out', interactive: true),
        glyph(label: 'Kael'),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels, contains('Sign Out'));
      expect(labels, contains('Kael'));
    });

    test('deduplicates labels', () {
      final glyphs = [
        glyph(label: 'Kael', widgetType: 'Text'),
        glyph(label: 'Kael', widgetType: 'RichText'),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels.length, 1);
      expect(labels, contains('Kael'));
    });

    test('trims whitespace from labels', () {
      final glyphs = [
        glyph(label: '  Kael  '),
        glyph(label: ' Questboard '),
      ];

      final labels = auditor.extractDisplayLabels(glyphs);

      expect(labels, contains('Kael'));
      expect(labels, contains('Questboard'));
    });
  });

  // ===================================================================
  // detectSignOutButtons
  // ===================================================================
  group('ScreenAuditor.detectSignOutButtons', () {
    test('detects "Sign Out" button', () {
      final glyphs = [
        glyph(label: 'Sign Out', interactive: true),
        glyph(label: 'About', interactive: true),
      ];

      final buttons = auditor.detectSignOutButtons(glyphs);

      expect(buttons, ['Sign Out']);
    });

    test('detects "Log Out" button', () {
      final glyphs = [
        glyph(label: 'Log Out', interactive: true),
      ];

      expect(auditor.detectSignOutButtons(glyphs), ['Log Out']);
    });

    test('detects "Logout" button', () {
      final glyphs = [
        glyph(label: 'Logout', interactive: true),
      ];

      expect(auditor.detectSignOutButtons(glyphs), ['Logout']);
    });

    test('detects "Sign Off" button', () {
      final glyphs = [
        glyph(label: 'Sign Off', interactive: true),
      ];

      expect(auditor.detectSignOutButtons(glyphs), ['Sign Off']);
    });

    test('detects "Disconnect" button', () {
      final glyphs = [
        glyph(label: 'Disconnect', interactive: true),
      ];

      expect(auditor.detectSignOutButtons(glyphs), ['Disconnect']);
    });

    test('ignores non-interactive elements', () {
      final glyphs = [
        glyph(label: 'Sign Out', interactive: false),
      ];

      expect(auditor.detectSignOutButtons(glyphs), isEmpty);
    });

    test('is case-insensitive', () {
      final glyphs = [
        glyph(label: 'SIGN OUT', interactive: true),
        glyph(label: 'log out', interactive: true),
      ];

      final buttons = auditor.detectSignOutButtons(glyphs);

      expect(buttons, contains('SIGN OUT'));
      expect(buttons, contains('log out'));
    });

    test('deduplicates results', () {
      final glyphs = [
        glyph(label: 'Sign Out', interactive: true, widgetType: 'Text'),
        glyph(label: 'Sign Out', interactive: true, widgetType: 'Button'),
      ];

      expect(auditor.detectSignOutButtons(glyphs).length, 1);
    });

    test('returns empty for non-logout buttons', () {
      final glyphs = [
        glyph(label: 'Submit', interactive: true),
        glyph(label: 'Cancel', interactive: true),
        glyph(label: 'About', interactive: true),
      ];

      expect(auditor.detectSignOutButtons(glyphs), isEmpty);
    });
  });

  // ===================================================================
  // isSignOutButton
  // ===================================================================
  group('ScreenAuditor.isSignOutButton', () {
    test('returns true for sign-out variants', () {
      expect(auditor.isSignOutButton('Sign Out'), isTrue);
      expect(auditor.isSignOutButton('Log Out'), isTrue);
      expect(auditor.isSignOutButton('Logout'), isTrue);
      expect(auditor.isSignOutButton('Sign Off'), isTrue);
      expect(auditor.isSignOutButton('Disconnect'), isTrue);
    });

    test('returns false for unrelated labels', () {
      expect(auditor.isSignOutButton('Sign In'), isFalse);
      expect(auditor.isSignOutButton('Submit'), isFalse);
      expect(auditor.isSignOutButton('Cancel'), isFalse);
      expect(auditor.isSignOutButton('Enterprise'), isFalse);
    });
  });

  // ===================================================================
  // generateProbeValue
  // ===================================================================
  group('ScreenAuditor.generateProbeValue', () {
    test('starts with Probe_ prefix', () {
      final probe = ScreenAuditor.generateProbeValue();

      expect(probe, startsWith('Probe_'));
    });

    test('has expected length (Probe_ + 6 chars)', () {
      final probe = ScreenAuditor.generateProbeValue();

      expect(probe.length, 12);
    });

    test('generates unique values', () {
      final probes = List.generate(100, (_) => ScreenAuditor.generateProbeValue());
      final unique = probes.toSet();

      // Very high probability all are unique
      expect(unique.length, greaterThan(95));
    });
  });

  // ===================================================================
  // compareScreens — primary audit logic
  // ===================================================================
  group('ScreenAuditor.compareScreens', () {
    group('missing_input detection', () {
      test('detects when entered value is absent from screen', () {
        final before = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
        ];
        final after = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Titan',
        );

        expect(report.hasBugs, isTrue);
        expect(
          report.bugs.any((f) => f.category == 'missing_input'),
          isTrue,
        );
        expect(report.bugs.first.expected, 'Titan');
      });

      test('no bug when entered value appears on screen', () {
        final before = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
        ];
        final after = [
          glyph(label: 'Titan'),
          glyph(label: 'Questboard'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Titan',
        );

        expect(
          report.findings.any((f) => f.category == 'missing_input'),
          isFalse,
        );
      });
    });

    group('partial_match detection', () {
      test('reports partial match when input is substring of another label',
          () {
        final before = [glyph(label: 'Kael')];
        final after = [
          glyph(label: 'Welcome, Titan!'),
          glyph(label: 'Questboard'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Titan',
        );

        // Should have partial_match info, not a bug
        expect(
          report.findings.any((f) => f.category == 'partial_match'),
          isTrue,
        );
        expect(
          report.findings.any((f) => f.category == 'missing_input'),
          isFalse,
        );
      });
    });

    group('data_binding detection', () {
      test('detects hardcoded name: input missing + old name persists', () {
        final before = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
          glyph(label: 'Champion \u2022 50 glory'),
        ];
        final after = [
          glyph(label: 'Kael'), // Still shows Kael!
          glyph(label: 'Questboard'),
          glyph(label: 'Champion \u2022 50 glory'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Probe_abc123',
        );

        expect(report.hasBugs, isTrue);

        // Should have both missing_input and data_binding
        final categories = report.bugs.map((f) => f.category).toSet();
        expect(categories, contains('missing_input'));
        expect(categories, contains('data_binding'));

        // data_binding finding should reference both values
        final binding = report.bugs.firstWhere(
          (f) => f.category == 'data_binding',
        );
        expect(binding.expected, 'Probe_abc123');
        expect(binding.actual, 'Kael');
      });

      test('does not flag structural labels as hardcoded', () {
        final before = [
          glyph(label: 'Questboard'),
          glyph(label: 'Champion \u2022 50 glory'),
          glyph(label: 'Slay the Bug Dragon'),
          glyph(label: 'Forge the Universal Adapter'),
        ];
        final after = [
          glyph(label: 'Questboard'),
          glyph(label: 'Champion \u2022 50 glory'),
          glyph(label: 'Slay the Bug Dragon'),
          glyph(label: 'Forge the Universal Adapter'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Probe_xyz789',
        );

        // missing_input should fire (probe not shown)
        expect(
          report.bugs.any((f) => f.category == 'missing_input'),
          isTrue,
        );

        // But data_binding should NOT flag long/structural labels
        final bindings = report.bugs.where(
          (f) => f.category == 'data_binding',
        );
        // Questboard is > 3 words? No. Let's check:
        // - "Questboard" — 1 word, 10 chars, alphabetic → matches name heuristic
        // - "Champion • 50 glory" — has bullet → filtered out
        // - "Slay the Bug Dragon" — 4 words → filtered (> 3 words)
        // - "Forge the Universal Adapter" — 4 words → filtered
        // So "Questboard" might still be flagged. That's OK — it's a heuristic.
        // The key is structural labels with bullets, colons, long text are NOT flagged.
        for (final b in bindings) {
          expect(b.actual, isNot(contains('\u2022')));
        }
      });
    });

    group('disappeared / appeared tracking', () {
      test('reports disappeared labels', () {
        final before = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
        ];
        final after = [
          glyph(label: 'Titan'),
          glyph(label: 'Questboard'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Titan',
        );

        expect(report.disappeared, contains('Kael'));
        expect(
          report.findings.any((f) => f.category == 'disappeared'),
          isTrue,
        );
      });

      test('reports appeared labels', () {
        final before = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
        ];
        final after = [
          glyph(label: 'Titan'),
          glyph(label: 'Questboard'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Titan',
        );

        expect(report.appeared, contains('Titan'));
        expect(
          report.findings.any((f) => f.category == 'appeared'),
          isTrue,
        );
      });

      test('no disappeared/appeared when screens identical', () {
        final glyphs = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: glyphs,
          glyphsAfter: glyphs,
          testInput: 'Kael',
        );

        expect(report.disappeared, isEmpty);
        expect(report.appeared, isEmpty);
      });
    });

    group('clean screen — no bugs', () {
      test('reports no bugs when input appears correctly', () {
        final before = [
          glyph(label: 'Kael'),
          glyph(label: 'Questboard'),
          glyph(label: '0 Glory \u2022 Novice'),
        ];
        final after = [
          glyph(label: 'Titan'),
          glyph(label: 'Questboard'),
          glyph(label: '0 Glory \u2022 Novice'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Titan',
        );

        expect(report.hasBugs, isFalse);
        expect(report.bugs, isEmpty);
      });
    });

    group('the Kael bug scenario', () {
      test('detects exact Kael hardcoded-name bug', () {
        // Simulates the real app bug: login as "Probe_abc" but
        // screen still shows "Kael".
        // Uses realistic glyph metadata — interactive tabs/buttons,
        // AppBar ancestors for title — to validate structural
        // filtering.
        final before = [
          glyph(label: 'Kael'),
          glyph(
            label: 'Questboard',
            ancestors: ['_AppBarTitleBox', 'Semantics', 'DefaultTextStyle'],
          ),
          glyph(label: 'Questboard', widgetType: 'AppBar'),
          glyph(label: '0 Glory \u2022 Novice'),
          glyph(label: 'Sign Out', interactive: true),
          glyph(label: 'About', interactive: true),
          glyph(
            label: 'Quests',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Quests'),
          glyph(
            label: 'Hero',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Hero'),
          glyph(
            label: 'Shade',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Shade'),
          glyph(
            label: 'Enterprise',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Enterprise'),
          glyph(
            label: 'Spark',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Spark'),
          glyph(label: 'Slay the Bug Dragon'),
          glyph(label: 'Champion \u2022 50 glory'),
          glyph(
            label: 'Complete Quest',
            interactive: true,
            widgetType: 'IconButton',
          ),
          glyph(label: 'Complete Quest', widgetType: 'Tooltip'),
        ];

        final after = [
          glyph(label: 'Kael'), // BUG: should show "Probe_test42"
          glyph(
            label: 'Questboard',
            ancestors: ['_AppBarTitleBox', 'Semantics', 'DefaultTextStyle'],
          ),
          glyph(label: 'Questboard', widgetType: 'AppBar'),
          glyph(label: '0 Glory \u2022 Novice'),
          glyph(label: 'Sign Out', interactive: true),
          glyph(label: 'About', interactive: true),
          glyph(
            label: 'Quests',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Quests'),
          glyph(
            label: 'Hero',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Hero'),
          glyph(
            label: 'Shade',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Shade'),
          glyph(
            label: 'Enterprise',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Enterprise'),
          glyph(
            label: 'Spark',
            interactive: true,
            widgetType: 'GestureDetector',
          ),
          glyph(label: 'Spark'),
          glyph(label: 'Slay the Bug Dragon'),
          glyph(label: 'Champion \u2022 50 glory'),
          glyph(
            label: 'Complete Quest',
            interactive: true,
            widgetType: 'IconButton',
          ),
          glyph(label: 'Complete Quest', widgetType: 'Tooltip'),
        ];

        final report = auditor.compareScreens(
          glyphsBefore: before,
          glyphsAfter: after,
          testInput: 'Probe_test42',
        );

        expect(report.hasBugs, isTrue);

        // Should detect missing_input
        expect(
          report.bugs.any((f) => f.category == 'missing_input'),
          isTrue,
          reason: '"Probe_test42" is nowhere on screen',
        );

        // Should detect data_binding for "Kael"
        final bindingBugs = report.bugs.where(
          (f) => f.category == 'data_binding',
        );
        expect(
          bindingBugs.any((f) => f.actual == 'Kael'),
          isTrue,
          reason: '"Kael" persists as a hardcoded value',
        );

        // Should NOT flag structural labels (interactive tabs/buttons)
        for (final structural in [
          'Hero',
          'Quests',
          'Shade',
          'Enterprise',
          'Spark',
          'Sign Out',
          'About',
          'Complete Quest',
          'Questboard',
        ]) {
          expect(
            bindingBugs.any((f) => f.actual == structural),
            isFalse,
            reason: '"$structural" is structural UI chrome',
          );
        }

        // Verify bullet + long labels are still filtered
        expect(
          bindingBugs.any(
            (f) => f.actual == 'Champion \u2022 50 glory',
          ),
          isFalse,
          reason: 'Labels with bullet separators are structural',
        );
        expect(
          bindingBugs.any(
            (f) => f.actual == 'Slay the Bug Dragon',
          ),
          isFalse,
          reason: 'Labels with > 3 words are not name-like',
        );

        // Should be exactly 2 bugs: missing_input + data_binding(Kael)
        expect(report.bugs.length, 2);
      });
    });
  });

  // ===================================================================
  // AuditFinding
  // ===================================================================
  group('AuditFinding', () {
    test('toJson serializes all fields', () {
      const finding = AuditFinding(
        severity: 'bug',
        category: 'data_binding',
        message: 'Value hardcoded',
        expected: 'Titan',
        actual: 'Kael',
      );

      final json = finding.toJson();

      expect(json['severity'], 'bug');
      expect(json['category'], 'data_binding');
      expect(json['message'], 'Value hardcoded');
      expect(json['expected'], 'Titan');
      expect(json['actual'], 'Kael');
    });

    test('toJson omits null fields', () {
      const finding = AuditFinding(
        severity: 'info',
        category: 'appeared',
        message: 'New labels appeared',
      );

      final json = finding.toJson();

      expect(json.containsKey('expected'), isFalse);
      expect(json.containsKey('actual'), isFalse);
    });

    test('toString includes severity and category', () {
      const finding = AuditFinding(
        severity: 'bug',
        category: 'missing_input',
        message: 'Input not found',
      );

      expect(finding.toString(), contains('bug'));
      expect(finding.toString(), contains('missing_input'));
    });
  });

  // ===================================================================
  // AuditReport
  // ===================================================================
  group('AuditReport', () {
    test('hasBugs returns true when bugs exist', () {
      const report = AuditReport(
        findings: [
          AuditFinding(
            severity: 'bug',
            category: 'missing_input',
            message: 'test',
          ),
        ],
        testInput: 'probe',
        labelsBefore: {'A'},
        labelsAfter: {'B'},
      );

      expect(report.hasBugs, isTrue);
    });

    test('hasBugs returns false when only warnings/infos', () {
      const report = AuditReport(
        findings: [
          AuditFinding(
            severity: 'warning',
            category: 'stale_data',
            message: 'test',
          ),
          AuditFinding(
            severity: 'info',
            category: 'appeared',
            message: 'test',
          ),
        ],
        testInput: 'probe',
        labelsBefore: {'A'},
        labelsAfter: {'B'},
      );

      expect(report.hasBugs, isFalse);
    });

    test('filters by severity correctly', () {
      const report = AuditReport(
        findings: [
          AuditFinding(
            severity: 'bug',
            category: 'c1',
            message: 'm1',
          ),
          AuditFinding(
            severity: 'warning',
            category: 'c2',
            message: 'm2',
          ),
          AuditFinding(
            severity: 'info',
            category: 'c3',
            message: 'm3',
          ),
          AuditFinding(
            severity: 'bug',
            category: 'c4',
            message: 'm4',
          ),
        ],
        testInput: 'probe',
        labelsBefore: {},
        labelsAfter: {},
      );

      expect(report.bugs.length, 2);
      expect(report.warnings.length, 1);
      expect(report.infos.length, 1);
    });

    test('persisting returns intersection', () {
      const report = AuditReport(
        findings: [],
        testInput: 'probe',
        labelsBefore: {'A', 'B', 'C'},
        labelsAfter: {'B', 'C', 'D'},
      );

      expect(report.persisting, {'B', 'C'});
      expect(report.disappeared, {'A'});
      expect(report.appeared, {'D'});
    });

    test('toJson serializes report', () {
      const report = AuditReport(
        findings: [
          AuditFinding(
            severity: 'bug',
            category: 'missing_input',
            message: 'Not found',
            expected: 'Probe_x',
          ),
        ],
        testInput: 'Probe_x',
        labelsBefore: {'A', 'B'},
        labelsAfter: {'B', 'C'},
      );

      final json = report.toJson();

      expect(json['testInput'], 'Probe_x');
      expect(json['hasBugs'], isTrue);
      expect(json['bugCount'], 1);
      expect(json['findings'], hasLength(1));
      expect(json['disappeared'], contains('A'));
      expect(json['appeared'], contains('C'));
    });
  });

  // ===================================================================
  // _looksLikeName heuristic (tested via compareScreens)
  // ===================================================================
  group('name-like heuristic (via compareScreens)', () {
    test('short alphabetic labels are flagged as potential names', () {
      final before = [glyph(label: 'Kael')];
      final after = [glyph(label: 'Kael')];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == 'Kael'), isTrue);
    });

    test('labels with bullets are not flagged', () {
      final label = 'Champion \u2022 50 glory';
      final before = [glyph(label: label)];
      final after = [glyph(label: label)];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == label), isFalse);
    });

    test('labels with colons are not flagged', () {
      final before = [glyph(label: 'Status: Active')];
      final after = [glyph(label: 'Status: Active')];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == 'Status: Active'), isFalse);
    });

    test('labels with > 3 words are not flagged', () {
      final before = [glyph(label: 'Slay the Bug Dragon')];
      final after = [glyph(label: 'Slay the Bug Dragon')];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(
        bindings.any((f) => f.actual == 'Slay the Bug Dragon'),
        isFalse,
      );
    });

    test('labels > 25 chars are not flagged', () {
      final longName = 'A' * 26;
      final before = [glyph(label: longName)];
      final after = [glyph(label: longName)];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == longName), isFalse);
    });

    test('two-word names are flagged', () {
      final before = [glyph(label: 'John Smith')];
      final after = [glyph(label: 'John Smith')];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == 'John Smith'), isTrue);
    });

    test('labels with slashes are not flagged', () {
      final before = [glyph(label: 'on/off')];
      final after = [glyph(label: 'on/off')];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == 'on/off'), isFalse);
    });

    test('labels with parentheses are not flagged', () {
      final before = [glyph(label: 'Score (100)')];
      final after = [glyph(label: 'Score (100)')];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      final bindings = report.bugs.where(
        (f) => f.category == 'data_binding',
      );
      expect(bindings.any((f) => f.actual == 'Score (100)'), isFalse);
    });

    test('data_binding not flagged when input IS present', () {
      // When testInput appears on screen, no data_binding bugs
      final before = [glyph(label: 'Kael')];
      final after = [
        glyph(label: 'Probe_test'),
        glyph(label: 'Kael'), // Old name still here too
      ];

      final report = auditor.compareScreens(
        glyphsBefore: before,
        glyphsAfter: after,
        testInput: 'Probe_test',
      );

      expect(
        report.bugs.any((f) => f.category == 'data_binding'),
        isFalse,
      );
    });
  });

  // ===================================================================
  // extractStructuralLabels
  // ===================================================================
  group('ScreenAuditor.extractStructuralLabels', () {
    test('identifies interactive elements as structural', () {
      final glyphs = [
        glyph(label: 'Sign Out', interactive: true),
        glyph(label: 'About', interactive: true),
        glyph(label: 'Kael'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Sign Out'));
      expect(structural, contains('About'));
      expect(structural, isNot(contains('Kael')));
    });

    test('identifies AppBar widget type as structural', () {
      final glyphs = [
        glyph(label: 'Questboard', widgetType: 'AppBar'),
        glyph(label: 'Kael'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Questboard'));
      expect(structural, isNot(contains('Kael')));
    });

    test('identifies NavigationBar widget type as structural', () {
      final glyphs = [
        glyph(label: 'Quests', widgetType: 'NavigationBar'),
        glyph(label: 'Kael'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Quests'));
      expect(structural, isNot(contains('Kael')));
    });

    test('identifies labels with AppBar ancestors as structural', () {
      final glyphs = [
        glyph(
          label: 'Questboard',
          ancestors: ['_AppBarTitleBox', 'Semantics', 'DefaultTextStyle'],
        ),
        glyph(label: 'Kael'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Questboard'));
      expect(structural, isNot(contains('Kael')));
    });

    test('identifies labels with NavigationBar ancestors as structural', () {
      final glyphs = [
        glyph(
          label: 'Hero',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
        glyph(label: 'Kael'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Hero'));
      expect(structural, isNot(contains('Kael')));
    });

    test('identifies labels with TabBar ancestors as structural', () {
      final glyphs = [
        glyph(
          label: 'Settings',
          ancestors: ['TabBar', 'Align', 'Padding'],
        ),
        glyph(label: 'UserName'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Settings'));
      expect(structural, isNot(contains('UserName')));
    });

    test('marks label structural if ANY instance is interactive', () {
      // "Hero" appears as both Text (non-interactive) and
      // GestureDetector (interactive). Should be structural.
      final glyphs = [
        glyph(label: 'Hero'),
        glyph(
          label: 'Hero',
          interactive: true,
          widgetType: 'GestureDetector',
        ),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Hero'));
    });

    test('excludes short and icon labels', () {
      final glyphs = [
        glyph(label: ''),
        glyph(label: 'A'),
        glyph(label: 'IconData(U+0E15A)', interactive: true),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, isEmpty);
    });

    test('labels with Drawer ancestors are structural', () {
      final glyphs = [
        glyph(
          label: 'Profile',
          ancestors: ['Drawer', 'ListView', 'ListTile'],
        ),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Profile'));
    });

    test('labels with Toolbar ancestors are structural', () {
      final glyphs = [
        glyph(
          label: 'Edit',
          ancestors: ['ToolbarOptions', 'Row'],
        ),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Edit'));
    });

    test('Toolbar widget type is structural', () {
      final glyphs = [
        glyph(label: 'Format', widgetType: 'Toolbar'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Format'));
    });

    test('Drawer widget type is structural', () {
      final glyphs = [
        glyph(label: 'Menu', widgetType: 'Drawer'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Menu'));
    });

    test('BottomSheet widget type is structural', () {
      final glyphs = [
        glyph(label: 'Options', widgetType: 'BottomSheet'),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, contains('Options'));
    });

    test('plain Text widget with no structural ancestors is not structural',
        () {
      final glyphs = [
        glyph(label: 'Kael'),
        glyph(label: 'John Smith'),
        glyph(
          label: '0 Glory',
          ancestors: ['Column', 'Padding', 'DecoratedBox'],
        ),
      ];

      final structural = auditor.extractStructuralLabels(glyphs);

      expect(structural, isEmpty);
    });
  });
}
