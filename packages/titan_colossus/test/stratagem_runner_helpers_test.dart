import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/recording/glyph.dart';
import 'package:titan_colossus/src/recording/tableau.dart';
import 'package:titan_colossus/src/recording/shade.dart';
import 'package:titan_colossus/src/testing/stratagem.dart';
import 'package:titan_colossus/src/testing/stratagem_runner.dart';
import 'package:titan_colossus/src/testing/verdict.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Tableau makeTableau({String? route, List<Glyph>? glyphs}) {
  return Tableau(
    index: 0,
    timestamp: Duration.zero,
    glyphs: glyphs ?? [],
    route: route ?? '/test',
    screenWidth: 400,
    screenHeight: 800,
  );
}

void main() {
  late StratagemRunner runner;

  setUp(() {
    runner = StratagemRunner(shade: Shade());
  });

  // -------------------------------------------------------------------------
  // keyCodeFromId — all key mappings
  // -------------------------------------------------------------------------
  group('StratagemRunner.keyCodeFromId', () {
    test('enter maps to 66', () {
      expect(StratagemRunner.keyCodeFromId('enter'), 66);
    });

    test('return maps to 66', () {
      expect(StratagemRunner.keyCodeFromId('return'), 66);
    });

    test('tab maps to 61', () {
      expect(StratagemRunner.keyCodeFromId('tab'), 61);
    });

    test('escape maps to 111', () {
      expect(StratagemRunner.keyCodeFromId('escape'), 111);
    });

    test('esc maps to 111', () {
      expect(StratagemRunner.keyCodeFromId('esc'), 111);
    });

    test('backspace maps to 67', () {
      expect(StratagemRunner.keyCodeFromId('backspace'), 67);
    });

    test('delete maps to 112', () {
      expect(StratagemRunner.keyCodeFromId('delete'), 112);
    });

    test('del maps to 112', () {
      expect(StratagemRunner.keyCodeFromId('del'), 112);
    });

    test('space maps to 62', () {
      expect(StratagemRunner.keyCodeFromId('space'), 62);
    });

    test('up maps to 19', () {
      expect(StratagemRunner.keyCodeFromId('up'), 19);
    });

    test('arrowup maps to 19', () {
      expect(StratagemRunner.keyCodeFromId('arrowup'), 19);
    });

    test('down maps to 20', () {
      expect(StratagemRunner.keyCodeFromId('down'), 20);
    });

    test('arrowdown maps to 20', () {
      expect(StratagemRunner.keyCodeFromId('arrowdown'), 20);
    });

    test('left maps to 21', () {
      expect(StratagemRunner.keyCodeFromId('left'), 21);
    });

    test('arrowleft maps to 21', () {
      expect(StratagemRunner.keyCodeFromId('arrowleft'), 21);
    });

    test('right maps to 22', () {
      expect(StratagemRunner.keyCodeFromId('right'), 22);
    });

    test('arrowright maps to 22', () {
      expect(StratagemRunner.keyCodeFromId('arrowright'), 22);
    });

    test('home maps to 122', () {
      expect(StratagemRunner.keyCodeFromId('home'), 122);
    });

    test('end maps to 123', () {
      expect(StratagemRunner.keyCodeFromId('end'), 123);
    });

    test('pageup maps to 92', () {
      expect(StratagemRunner.keyCodeFromId('pageup'), 92);
    });

    test('pagedown maps to 93', () {
      expect(StratagemRunner.keyCodeFromId('pagedown'), 93);
    });

    test('single char "a" maps to codeUnit', () {
      expect(StratagemRunner.keyCodeFromId('a'), 'a'.codeUnitAt(0));
    });

    test('single char "Z" maps to codeUnit', () {
      expect(StratagemRunner.keyCodeFromId('Z'), 'Z'.codeUnitAt(0));
    });

    test('unknown multi-char string maps to 0', () {
      expect(StratagemRunner.keyCodeFromId('foobar'), 0);
    });

    test('case insensitive — ENTER maps to 66', () {
      expect(StratagemRunner.keyCodeFromId('ENTER'), 66);
    });

    test('case insensitive — Tab maps to 61', () {
      expect(StratagemRunner.keyCodeFromId('Tab'), 61);
    });
  });

  // -------------------------------------------------------------------------
  // actionNeedsTarget — all action types
  // -------------------------------------------------------------------------
  group('StratagemRunner.actionNeedsTarget', () {
    final needsTarget = {
      StratagemAction.tap,
      StratagemAction.doubleTap,
      StratagemAction.longPress,
      StratagemAction.enterText,
      StratagemAction.clearText,
      StratagemAction.toggleSwitch,
      StratagemAction.toggleCheckbox,
      StratagemAction.selectRadio,
      StratagemAction.adjustSlider,
      StratagemAction.selectDropdown,
      StratagemAction.selectDate,
      StratagemAction.selectSegment,
      StratagemAction.swipe,
    };

    for (final action in StratagemAction.values) {
      test('${action.name} → ${needsTarget.contains(action)}', () {
        expect(runner.actionNeedsTarget(action), needsTarget.contains(action));
      });
    }
  });

  // -------------------------------------------------------------------------
  // actionRequiresInteractive — all action types
  // -------------------------------------------------------------------------
  group('StratagemRunner.actionRequiresInteractive', () {
    final requiresInteractive = {
      StratagemAction.tap,
      StratagemAction.doubleTap,
      StratagemAction.longPress,
      StratagemAction.enterText,
      StratagemAction.clearText,
      StratagemAction.toggleSwitch,
      StratagemAction.toggleCheckbox,
      StratagemAction.selectRadio,
      StratagemAction.adjustSlider,
      StratagemAction.selectDropdown,
      StratagemAction.selectDate,
      StratagemAction.selectSegment,
    };

    for (final action in StratagemAction.values) {
      test('${action.name} → ${requiresInteractive.contains(action)}', () {
        expect(
          runner.actionRequiresInteractive(action),
          requiresInteractive.contains(action),
        );
      });
    }
  });

  // -------------------------------------------------------------------------
  // targetDescription — all combinations
  // -------------------------------------------------------------------------
  group('StratagemRunner.targetDescription', () {
    test('label only', () {
      expect(
        runner.targetDescription(const StratagemTarget(label: 'OK')),
        '"OK"',
      );
    });

    test('type only', () {
      expect(
        runner.targetDescription(const StratagemTarget(type: 'Button')),
        '(Button)',
      );
    });

    test('key only', () {
      expect(
        runner.targetDescription(const StratagemTarget(key: 'k1')),
        '[key: k1]',
      );
    });

    test('label + type + key', () {
      expect(
        runner.targetDescription(
          const StratagemTarget(label: 'OK', type: 'Button', key: 'k1'),
        ),
        '"OK" (Button) [key: k1]',
      );
    });

    test('all fields null returns unknown target', () {
      expect(
        runner.targetDescription(const StratagemTarget()),
        'unknown target',
      );
    });
  });

  // -------------------------------------------------------------------------
  // screenCenter — fallback in test environment
  // -------------------------------------------------------------------------
  group('StratagemRunner.screenCenter', () {
    testWidgets('returns a sensible center', (tester) async {
      // In test environment with TestWidgetsFlutterBinding,
      // renderViews should be available
      final center = runner.screenCenter;
      expect(center.dx, greaterThan(0));
      expect(center.dy, greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // validateExpectations — edge cases
  // -------------------------------------------------------------------------
  group('StratagemRunner.validateExpectations', () {
    final stratagem = const Stratagem(name: 'test', startRoute: '/', steps: []);

    test('null expectations returns null', () {
      final result = runner.validateExpectations(
        null,
        makeTableau(),
        stratagem,
      );
      expect(result, isNull);
    });

    test('matching route returns null', () {
      final result = runner.validateExpectations(
        const StratagemExpectations(route: '/test'),
        makeTableau(route: '/test'),
        stratagem,
      );
      expect(result, isNull);
    });

    test('mismatched route returns wrongRoute failure', () {
      final result = runner.validateExpectations(
        const StratagemExpectations(route: '/home'),
        makeTableau(route: '/login'),
        stratagem,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.wrongRoute);
      expect(result.expected, '/home');
      expect(result.actual, '/login');
    });

    test('route with testData interpolation', () {
      final s = const Stratagem(
        name: 'test',
        startRoute: '/',
        testData: {'page': 'home'},
        steps: [],
      );
      final result = runner.validateExpectations(
        const StratagemExpectations(route: r'/test/${testData.page}'),
        // route does NOT match the interpolated value
        makeTableau(route: '/test/settings'),
        s,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.wrongRoute);
    });

    test('elementsPresent — all found returns null', () {
      final tableau = makeTableau(
        glyphs: [
          Glyph(
            label: 'OK',
            widgetType: 'Text',
            left: 0,
            top: 0,
            width: 100,
            height: 50,
            ancestors: const [],
            isInteractive: false,
            isEnabled: true,
          ),
        ],
      );
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementsPresent: [StratagemTarget(label: 'OK')],
        ),
        tableau,
        stratagem,
      );
      expect(result, isNull);
    });

    test('elementsPresent — missing returns elementMissing', () {
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementsPresent: [StratagemTarget(label: 'OK')],
        ),
        makeTableau(),
        stratagem,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.elementMissing);
    });

    test('elementsAbsent — all absent returns null', () {
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementsAbsent: [StratagemTarget(label: 'Error')],
        ),
        makeTableau(),
        stratagem,
      );
      expect(result, isNull);
    });

    test('elementsAbsent — present returns elementUnexpected', () {
      final tableau = makeTableau(
        glyphs: [
          Glyph(
            label: 'Error',
            widgetType: 'Text',
            left: 0,
            top: 0,
            width: 100,
            height: 50,
            ancestors: const [],
            isInteractive: false,
            isEnabled: true,
          ),
        ],
      );
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementsAbsent: [StratagemTarget(label: 'Error')],
        ),
        tableau,
        stratagem,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.elementUnexpected);
    });

    test('elementStates — glyph not found returns elementMissing', () {
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementStates: [
            StratagemElementState(label: 'Phantom', enabled: true),
          ],
        ),
        makeTableau(),
        stratagem,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.elementMissing);
    });

    test('elementStates — enabled mismatch returns wrongState', () {
      final tableau = makeTableau(
        glyphs: [
          Glyph(
            label: 'Submit',
            widgetType: 'ElevatedButton',
            left: 0,
            top: 0,
            width: 100,
            height: 50,
            ancestors: const [],
            isInteractive: true,
            isEnabled: false,
          ),
        ],
      );
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementStates: [
            StratagemElementState(label: 'Submit', enabled: true),
          ],
        ),
        tableau,
        stratagem,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.wrongState);
      expect(result.expected, 'enabled');
      expect(result.actual, 'disabled');
    });

    test('elementStates — value mismatch returns wrongState', () {
      final tableau = makeTableau(
        glyphs: [
          Glyph(
            label: 'Slider',
            widgetType: 'Slider',
            left: 0,
            top: 0,
            width: 200,
            height: 50,
            ancestors: const [],
            isInteractive: true,
            isEnabled: true,
            currentValue: '42',
          ),
        ],
      );
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementStates: [StratagemElementState(label: 'Slider', value: '50')],
        ),
        tableau,
        stratagem,
      );
      expect(result, isNotNull);
      expect(result!.type, VerdictFailureType.wrongState);
      expect(result.expected, '50');
      expect(result.actual, '42');
    });

    test('elementStates — matching state returns null', () {
      final tableau = makeTableau(
        glyphs: [
          Glyph(
            label: 'Toggle',
            widgetType: 'Switch',
            left: 0,
            top: 0,
            width: 60,
            height: 30,
            ancestors: const [],
            isInteractive: true,
            isEnabled: true,
            currentValue: 'on',
          ),
        ],
      );
      final result = runner.validateExpectations(
        const StratagemExpectations(
          elementStates: [
            StratagemElementState(label: 'Toggle', enabled: true, value: 'on'),
          ],
        ),
        tableau,
        stratagem,
      );
      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // StratagemRunner — navigateToRoute callback
  // -------------------------------------------------------------------------
  group('StratagemRunner — navigateToRoute', () {
    test('constructor accepts navigateToRoute callback', () {
      final navigatedRoutes = <String>[];
      final r = StratagemRunner(
        shade: Shade(),
        navigateToRoute: (route) async {
          navigatedRoutes.add(route);
        },
      );
      expect(r.navigateToRoute, isNotNull);
    });

    test('navigateToRoute is null by default', () {
      final r = StratagemRunner(shade: Shade());
      expect(r.navigateToRoute, isNull);
    });

    test('actionNeedsTarget returns false for navigate', () {
      expect(runner.actionNeedsTarget(StratagemAction.navigate), isFalse);
    });

    test('targetDescription handles various targets', () {
      expect(
        runner.targetDescription(
          const StratagemTarget(label: 'OK', type: 'Button'),
        ),
        contains('OK'),
      );
      expect(
        runner.targetDescription(const StratagemTarget(key: 'myKey')),
        contains('myKey'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // StratagemRunner — authStratagem
  // -------------------------------------------------------------------------
  group('StratagemRunner — authStratagem', () {
    test('constructor accepts authStratagem', () {
      const auth = Stratagem(
        name: '_auth',
        startRoute: '',
        steps: [
          StratagemStep(
            id: 1,
            action: StratagemAction.enterText,
            target: StratagemTarget(label: 'Hero Name'),
            value: 'Kael',
          ),
          StratagemStep(
            id: 2,
            action: StratagemAction.tap,
            target: StratagemTarget(label: 'Login'),
          ),
        ],
      );
      final r = StratagemRunner(shade: Shade(), authStratagem: auth);
      expect(r.authStratagem, isNotNull);
      expect(r.authStratagem!.name, '_auth');
      expect(r.authStratagem!.steps, hasLength(2));
    });

    test('authStratagem is null by default', () {
      final r = StratagemRunner(shade: Shade());
      expect(r.authStratagem, isNull);
    });

    test('authStratagem and navigateToRoute can both be set', () {
      final routes = <String>[];
      const auth = Stratagem(
        name: '_auth',
        startRoute: '',
        steps: [
          StratagemStep(
            id: 1,
            action: StratagemAction.tap,
            target: StratagemTarget(label: 'Login'),
          ),
        ],
      );
      final r = StratagemRunner(
        shade: Shade(),
        authStratagem: auth,
        navigateToRoute: (route) async => routes.add(route),
      );
      expect(r.authStratagem, isNotNull);
      expect(r.navigateToRoute, isNotNull);
    });
  });
}
