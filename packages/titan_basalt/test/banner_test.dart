import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Banner', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    group('construction', () {
      test('creates with empty flags list', () {
        final b = Banner(flags: []);
        expect(b.count, 0);
        expect(b.names, isEmpty);
      });

      test('creates with multiple flags', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b', defaultValue: true),
            const BannerFlag(name: 'c'),
          ],
          name: 'test',
        );
        expect(b.count, 3);
        expect(b.names, containsAll(['a', 'b', 'c']));
        expect(b.name, 'test');
      });

      test('initializes flags with default values', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'off'),
            const BannerFlag(name: 'on', defaultValue: true),
          ],
        );
        expect(b['off'].value, false);
        expect(b['on'].value, true);
      });
    });

    // -----------------------------------------------------------------------
    // Default evaluation
    // -----------------------------------------------------------------------

    group('default evaluation', () {
      test('isEnabled returns defaultValue when no rules or overrides', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'off'),
            const BannerFlag(name: 'on', defaultValue: true),
          ],
        );
        expect(b.isEnabled('off'), false);
        expect(b.isEnabled('on'), true);
      });

      test('returns false for unknown flags', () {
        final b = Banner(flags: []);
        expect(b.isEnabled('unknown'), false);
      });

      test('evaluate returns notFound reason for unknown flags', () {
        final b = Banner(flags: []);
        final eval = b.evaluate('unknown');
        expect(eval.enabled, false);
        expect(eval.reason, BannerReason.notFound);
      });

      test('evaluate returns defaultValue reason when no rules match', () {
        final b = Banner(
          flags: [const BannerFlag(name: 'simple', defaultValue: true)],
        );
        final eval = b.evaluate('simple');
        expect(eval.enabled, true);
        expect(eval.reason, BannerReason.defaultValue);
        expect(eval.flagName, 'simple');
      });
    });

    // -----------------------------------------------------------------------
    // Rules evaluation
    // -----------------------------------------------------------------------

    group('rules evaluation', () {
      test('enables flag when a rule matches', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'premium',
              rules: [
                BannerRule(
                  name: 'is-premium',
                  evaluate: (ctx) => ctx['tier'] == 'premium',
                ),
              ],
            ),
          ],
        );

        expect(b.isEnabled('premium', context: {'tier': 'premium'}), true);
        expect(b.isEnabled('premium', context: {'tier': 'free'}), false);
      });

      test('first matching rule wins', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              rules: [
                BannerRule(
                  name: 'admin',
                  evaluate: (ctx) => ctx['role'] == 'admin',
                ),
                BannerRule(
                  name: 'beta',
                  evaluate: (ctx) => ctx['beta'] == true,
                ),
              ],
            ),
          ],
        );

        final eval = b.evaluate('feature', context: {'role': 'admin'});
        expect(eval.enabled, true);
        expect(eval.reason, BannerReason.rule);
        expect(eval.matchedRule, 'admin');
      });

      test('falls through to default when no rules match', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              rules: [
                BannerRule(
                  name: 'admin',
                  evaluate: (ctx) => ctx['role'] == 'admin',
                ),
              ],
            ),
          ],
        );

        final eval = b.evaluate('feature', context: {'role': 'user'});
        expect(eval.enabled, false);
        expect(eval.reason, BannerReason.defaultValue);
      });

      test('skips rules evaluation when context is null', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              defaultValue: true,
              rules: [
                BannerRule(
                  name: 'never-match',
                  evaluate: (ctx) => ctx['x'] == true,
                ),
              ],
            ),
          ],
        );

        // No context → rules skipped → default value used
        final eval = b.evaluate('feature');
        expect(eval.enabled, true);
        expect(eval.reason, BannerReason.defaultValue);
      });
    });

    // -----------------------------------------------------------------------
    // Rollout percentage
    // -----------------------------------------------------------------------

    group('rollout', () {
      test('deterministic per userId', () {
        final b = Banner(flags: [const BannerFlag(name: 'test', rollout: 0.5)]);

        // Same user always gets the same result
        final first = b.isEnabled('test', userId: 'user-42');
        for (var i = 0; i < 10; i++) {
          expect(b.isEnabled('test', userId: 'user-42'), first);
        }
      });

      test('different users may get different results', () {
        final b = Banner(
          flags: [const BannerFlag(name: 'feature', rollout: 0.5)],
        );

        // With 50% rollout, if we check enough users, we should get both
        final results = <bool>{};
        for (var i = 0; i < 100; i++) {
          results.add(b.isEnabled('feature', userId: 'user-$i'));
        }
        expect(results, containsAll([true, false]));
      });

      test('0% rollout disables for all users', () {
        final b = Banner(flags: [const BannerFlag(name: 'zero', rollout: 0.0)]);

        for (var i = 0; i < 50; i++) {
          expect(b.isEnabled('zero', userId: 'user-$i'), false);
        }
      });

      test('100% rollout enables for all users', () {
        final b = Banner(flags: [const BannerFlag(name: 'full', rollout: 1.0)]);

        for (var i = 0; i < 50; i++) {
          expect(b.isEnabled('full', userId: 'user-$i'), true);
        }
      });

      test('evaluate returns rollout reason', () {
        final b = Banner(flags: [const BannerFlag(name: 'test', rollout: 1.0)]);

        final eval = b.evaluate('test', userId: 'user-1');
        expect(eval.reason, BannerReason.rollout);
      });

      test('rollout not applied without userId', () {
        final b = Banner(flags: [const BannerFlag(name: 'test', rollout: 1.0)]);

        // Without userId, rollout is skipped → falls to default (false)
        expect(b.isEnabled('test'), false);
      });
    });

    // -----------------------------------------------------------------------
    // Expiration
    // -----------------------------------------------------------------------

    group('expiration', () {
      test('expired flag returns defaultValue', () {
        final past = DateTime(2020, 1, 1);
        final b = Banner(
          flags: [
            BannerFlag(name: 'expired', defaultValue: false, expiresAt: past),
          ],
          now: () => DateTime(2025, 1, 1),
        );

        final eval = b.evaluate('expired');
        expect(eval.enabled, false);
        expect(eval.reason, BannerReason.expired);
      });

      test('non-expired flag evaluates normally', () {
        final future = DateTime(2099, 1, 1);
        final b = Banner(
          flags: [
            BannerFlag(name: 'active', defaultValue: true, expiresAt: future),
          ],
          now: () => DateTime(2025, 1, 1),
        );

        expect(b.isEnabled('active'), true);
      });

      test('override takes precedence over expiration', () {
        final past = DateTime(2020, 1, 1);
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'expired-but-forced',
              defaultValue: false,
              expiresAt: past,
            ),
          ],
          now: () => DateTime(2025, 1, 1),
        );

        b.setOverride('expired-but-forced', true);
        final eval = b.evaluate('expired-but-forced');
        expect(eval.enabled, true);
        expect(eval.reason, BannerReason.forceOverride);
      });
    });

    // -----------------------------------------------------------------------
    // Overrides
    // -----------------------------------------------------------------------

    group('overrides', () {
      test('setOverride forces flag value', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        expect(b.isEnabled('feature'), false);
        b.setOverride('feature', true);
        expect(b.isEnabled('feature'), true);
      });

      test('override takes precedence over rules', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              rules: [BannerRule(name: 'always', evaluate: (_) => true)],
            ),
          ],
        );

        b.setOverride('feature', false);
        expect(b.isEnabled('feature', context: {'anything': true}), false);
      });

      test('clearOverride removes the override', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        b.setOverride('feature', true);
        expect(b.isEnabled('feature'), true);

        b.clearOverride('feature');
        expect(b.isEnabled('feature'), false); // Back to default
      });

      test('clearAllOverrides removes all overrides', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b'),
          ],
        );

        b.setOverride('a', true);
        b.setOverride('b', true);
        expect(b.isEnabled('a'), true);
        expect(b.isEnabled('b'), true);

        b.clearAllOverrides();
        expect(b.isEnabled('a'), false);
        expect(b.isEnabled('b'), false);
      });

      test('hasOverride returns current override state', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        expect(b.hasOverride('feature'), false);
        b.setOverride('feature', true);
        expect(b.hasOverride('feature'), true);
        b.clearOverride('feature');
        expect(b.hasOverride('feature'), false);
      });

      test('overrides getter returns all active overrides', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b'),
          ],
        );

        b.setOverride('a', true);
        b.setOverride('b', false);
        expect(b.overrides, {'a': true, 'b': false});
      });

      test('setOverride throws for unknown flag', () {
        final b = Banner(flags: []);
        expect(() => b.setOverride('unknown', true), throwsArgumentError);
      });
    });

    // -----------------------------------------------------------------------
    // Remote config / bulk updates
    // -----------------------------------------------------------------------

    group('remote config', () {
      test('updateFlags changes flag states', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b'),
          ],
        );

        b.updateFlags({'a': true, 'b': true});
        expect(b['a'].value, true);
        expect(b['b'].value, true);
      });

      test('updateFlags ignores unknown flags', () {
        final b = Banner(flags: [const BannerFlag(name: 'a')]);
        // Should not throw
        b.updateFlags({'a': true, 'unknown': true});
        expect(b['a'].value, true);
      });

      test('overrides take precedence over remote values', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        b.setOverride('feature', true);
        b.updateFlags({'feature': false});

        // Override wins, state should still be true
        expect(b['feature'].value, true);
      });

      test('remote value is used when no override and no rules', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        b.updateFlags({'feature': true});
        final eval = b.evaluate('feature');
        expect(eval.enabled, true);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('operator [] returns reactive Core', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        final core = b['feature'];
        expect(core, isA<Core<bool>>());
        expect(core.value, false);
      });

      test('operator [] throws for unknown flags', () {
        final b = Banner(flags: []);
        expect(() => b['unknown'], throwsArgumentError);
      });

      test('state updates are reactive', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        final values = <bool>[];
        final core = b['feature'];
        // Track changes manually
        values.add(core.value);
        b.setOverride('feature', true);
        values.add(core.value);
        b.clearOverride('feature');
        values.add(core.value);

        expect(values, [false, true, false]);
      });

      test('enabledCount tracks enabled flags', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b'),
            const BannerFlag(name: 'c', defaultValue: true),
          ],
        );

        expect(b.enabledCount.value, 1); // 'c' is true
        b.setOverride('a', true);
        expect(b.enabledCount.value, 2);
        b.setOverride('b', true);
        expect(b.enabledCount.value, 3);
      });

      test('totalCount reflects flag count', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b'),
          ],
        );

        expect(b.totalCount.value, 2);
      });

      test('snapshot returns all flag states', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b', defaultValue: true),
          ],
        );

        expect(b.snapshot, {'a': false, 'b': true});
      });
    });

    // -----------------------------------------------------------------------
    // Runtime registration
    // -----------------------------------------------------------------------

    group('runtime registration', () {
      test('register adds a new flag', () {
        final b = Banner(flags: []);
        b.register(const BannerFlag(name: 'new-flag', defaultValue: true));

        expect(b.has('new-flag'), true);
        expect(b.isEnabled('new-flag'), true);
        expect(b.count, 1);
      });

      test('register throws for duplicate flag names', () {
        final b = Banner(flags: [const BannerFlag(name: 'dup')]);
        expect(
          () => b.register(const BannerFlag(name: 'dup')),
          throwsArgumentError,
        );
      });

      test('unregister removes a flag', () {
        final b = Banner(flags: [const BannerFlag(name: 'temp')]);
        expect(b.unregister('temp'), true);
        expect(b.has('temp'), false);
        expect(b.count, 0);
      });

      test('unregister returns false for unknown flags', () {
        final b = Banner(flags: []);
        expect(b.unregister('unknown'), false);
      });

      test('unregister cleans up overrides and remote values', () {
        final b = Banner(flags: [const BannerFlag(name: 'temp')]);
        b.setOverride('temp', true);
        b.updateFlags({'temp': true});
        b.unregister('temp');

        expect(b.hasOverride('temp'), false);
      });
    });

    // -----------------------------------------------------------------------
    // Inspection
    // -----------------------------------------------------------------------

    group('inspection', () {
      test('has checks flag existence', () {
        final b = Banner(flags: [const BannerFlag(name: 'exists')]);
        expect(b.has('exists'), true);
        expect(b.has('nope'), false);
      });

      test('config returns flag configuration', () {
        const flag = BannerFlag(name: 'test', description: 'desc');
        final b = Banner(flags: [flag]);
        expect(b.config('test')?.description, 'desc');
        expect(b.config('unknown'), isNull);
      });

      test('toString includes name and counts', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a', defaultValue: true),
            const BannerFlag(name: 'b'),
          ],
          name: 'app',
        );
        expect(b.toString(), 'Banner "app"(2 flags, 1 enabled)');
      });
    });

    // -----------------------------------------------------------------------
    // Evaluation priority
    // -----------------------------------------------------------------------

    group('evaluation priority', () {
      test('override > expired > rule > rollout > remote > default', () {
        final past = DateTime(2020, 1, 1);
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              defaultValue: false,
              expiresAt: past,
              rollout: 1.0,
              rules: [BannerRule(name: 'always', evaluate: (_) => true)],
            ),
          ],
          now: () => DateTime(2025, 1, 1),
        );

        // Override beats everything
        b.setOverride('feature', true);
        final eval1 = b.evaluate(
          'feature',
          context: {'x': true},
          userId: 'user',
        );
        expect(eval1.reason, BannerReason.forceOverride);
        expect(eval1.enabled, true);

        // Without override, expiration wins
        b.clearOverride('feature');
        final eval2 = b.evaluate(
          'feature',
          context: {'x': true},
          userId: 'user',
        );
        expect(eval2.reason, BannerReason.expired);
      });

      test('rules beat rollout and default', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              rollout: 0.0,
              rules: [BannerRule(name: 'match', evaluate: (_) => true)],
            ),
          ],
        );

        final eval = b.evaluate(
          'feature',
          context: {'any': true},
          userId: 'user',
        );
        expect(eval.reason, BannerReason.rule);
        expect(eval.enabled, true);
      });
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    group('Pillar integration', () {
      test('managedNodes includes all states and derived nodes', () {
        final b = Banner(
          flags: [
            const BannerFlag(name: 'a'),
            const BannerFlag(name: 'b'),
          ],
        );

        final nodes = b.managedNodes.toList();
        // 2 flag states + enabledCount + totalCount = 4
        expect(nodes.length, 4);
      });

      test('banner() extension creates lifecycle-managed instance', () {
        final pillar = _TestPillar();

        expect(pillar.flags.count, 2);
        expect(pillar.flags.isEnabled('dark-mode'), false);
        expect(pillar.flags.isEnabled('beta', context: {'beta': true}), true);

        pillar.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // BannerFlag
    // -----------------------------------------------------------------------

    group('BannerFlag', () {
      test('toString shows name and default', () {
        const flag = BannerFlag(name: 'test', defaultValue: true);
        expect(flag.toString(), 'BannerFlag(test, default=true)');
      });

      test('rollout assertion enforces range', () {
        // Valid values — no error
        Banner(flags: [const BannerFlag(name: 'a', rollout: 0.0)]);
        Banner(flags: [const BannerFlag(name: 'b', rollout: 0.5)]);
        Banner(flags: [const BannerFlag(name: 'c', rollout: 1.0)]);

        // Invalid values trigger ArgumentError at registration time
        expect(
          () => Banner(flags: [BannerFlag(name: 'bad', rollout: -0.1)]),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => Banner(flags: [BannerFlag(name: 'bad', rollout: 1.1)]),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    // BannerRule
    // -----------------------------------------------------------------------

    group('BannerRule', () {
      test('toString shows name', () {
        final rule = BannerRule(
          name: 'admin-check',
          evaluate: (_) => true,
          reason: 'Admin access',
        );
        expect(rule.toString(), 'BannerRule(admin-check)');
        expect(rule.reason, 'Admin access');
      });
    });

    // -----------------------------------------------------------------------
    // BannerEvaluation
    // -----------------------------------------------------------------------

    group('BannerEvaluation', () {
      test('toString includes details', () {
        const eval1 = BannerEvaluation(
          flagName: 'test',
          enabled: true,
          reason: BannerReason.rule,
          matchedRule: 'admin',
        );
        expect(
          eval1.toString(),
          'BannerEvaluation(test=true, reason=BannerReason.rule, '
          'rule=admin)',
        );
      });

      test('toString without matchedRule', () {
        const eval1 = BannerEvaluation(
          flagName: 'test',
          enabled: false,
          reason: BannerReason.defaultValue,
        );
        expect(
          eval1.toString(),
          'BannerEvaluation(test=false, reason=BannerReason.defaultValue)',
        );
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    group('edge cases', () {
      test('evaluating same flag multiple times is consistent', () {
        final b = Banner(
          flags: [const BannerFlag(name: 'stable', defaultValue: true)],
        );

        for (var i = 0; i < 100; i++) {
          expect(b.isEnabled('stable'), true);
        }
      });

      test('update after clearOverride restores remote value', () {
        final b = Banner(flags: [const BannerFlag(name: 'feature')]);

        b.updateFlags({'feature': true});
        expect(b['feature'].value, true);

        b.setOverride('feature', false);
        expect(b['feature'].value, false);

        b.clearOverride('feature');
        // After clearing, re-evaluate should pick up remote value
        b.evaluate('feature');
        expect(b['feature'].value, true);
      });

      test('multiple rules with partial context', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              rules: [
                BannerRule(
                  name: 'user-exists',
                  evaluate: (ctx) => ctx.containsKey('userId'),
                ),
                BannerRule(
                  name: 'has-role',
                  evaluate: (ctx) => ctx['role'] == 'admin',
                ),
              ],
            ),
          ],
        );

        // First rule matches
        final eval = b.evaluate('feature', context: {'userId': '123'});
        expect(eval.enabled, true);
        expect(eval.matchedRule, 'user-exists');
      });

      test('empty context does not match rules', () {
        final b = Banner(
          flags: [
            BannerFlag(
              name: 'feature',
              rules: [
                BannerRule(
                  name: 'needs-data',
                  evaluate: (ctx) => ctx['key'] == 'value',
                ),
              ],
            ),
          ],
        );

        expect(b.isEnabled('feature', context: {}), false);
      });
    });
  });
}

// Test pillar for integration testing
class _TestPillar extends Pillar {
  late final flags = banner(
    flags: [
      const BannerFlag(name: 'dark-mode'),
      BannerFlag(
        name: 'beta',
        rules: [
          BannerRule(name: 'is-beta', evaluate: (ctx) => ctx['beta'] == true),
        ],
      ),
    ],
    name: 'test',
  );

  @override
  void onInit() {
    // Access flags to initialize
    flags;
  }
}
