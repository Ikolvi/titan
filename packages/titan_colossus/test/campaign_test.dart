import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Stratagem makeStratagem({
    required String name,
    String startRoute = '/test',
    List<String> tags = const [],
  }) {
    return Stratagem(
      name: name,
      description: 'Test stratagem $name',
      startRoute: startRoute,
      tags: tags,
      steps: [
        const StratagemStep(
          id: 1,
          action: StratagemAction.verify,
          description: 'verify',
        ),
      ],
    );
  }

  CampaignEntry makeEntry({
    required String name,
    String startRoute = '/test',
    List<String> dependsOn = const [],
    String? skipIf,
    Map<String, dynamic>? testDataOverride,
    List<String> tags = const [],
  }) {
    return CampaignEntry(
      stratagem: makeStratagem(name: name, startRoute: startRoute, tags: tags),
      dependsOn: dependsOn,
      skipIf: skipIf,
      testDataOverride: testDataOverride,
    );
  }

  Campaign makeCampaign({
    String name = 'test_campaign',
    List<CampaignEntry>? entries,
    bool includeGauntlet = false,
    GauntletIntensity gauntletIntensity = GauntletIntensity.standard,
    CampaignFailurePolicy failurePolicy = CampaignFailurePolicy.skipDependents,
    Map<String, dynamic>? sharedTestData,
    Stratagem? authStratagem,
  }) {
    return Campaign(
      name: name,
      description: 'Test campaign',
      entries: entries ?? [makeEntry(name: 'step_a')],
      includeGauntlet: includeGauntlet,
      gauntletIntensity: gauntletIntensity,
      failurePolicy: failurePolicy,
      sharedTestData: sharedTestData,
      authStratagem: authStratagem,
    );
  }

  Outpost createOutpost({
    String route = '/test',
    String displayName = 'Test',
    List<OutpostElement>? interactive,
    List<String>? tags,
    List<March>? exits,
    List<March>? entrances,
  }) {
    return Outpost(
      signet: Signet(
        routePattern: route,
        interactiveDescriptors: const [],
        hash: 'abc',
        identity: 'test',
      ),
      routePattern: route,
      displayName: displayName,
      interactiveElements: interactive,
      tags: tags,
      exits: exits,
      entrances: entrances,
    );
  }

  March createMarch({
    String from = '/a',
    String to = '/b',
    MarchTrigger trigger = MarchTrigger.tap,
  }) {
    return March(fromRoute: from, toRoute: to, trigger: trigger);
  }

  OutpostElement button({String? label}) => OutpostElement(
    widgetType: 'ElevatedButton',
    label: label ?? 'Go',
    interactionType: 'tap',
    isInteractive: true,
  );

  // =========================================================================
  // CampaignEntry
  // =========================================================================

  group('CampaignEntry', () {
    test('name delegates to stratagem name', () {
      final entry = makeEntry(name: 'login_test');
      expect(entry.name, 'login_test');
    });

    test('defaults to empty dependsOn', () {
      final entry = CampaignEntry(stratagem: makeStratagem(name: 'solo'));
      expect(entry.dependsOn, isEmpty);
    });

    test('toString includes name and deps', () {
      final entry = makeEntry(name: 'a', dependsOn: ['b']);
      expect(entry.toString(), contains('a'));
      expect(entry.toString(), contains('b'));
    });

    test('toJson round-trip', () {
      final entry = makeEntry(
        name: 'login',
        dependsOn: ['setup'],
        skipIf: 'previous_failed',
        testDataOverride: {'heroName': 'Thor'},
      );

      final json = entry.toJson();
      expect(json['dependsOn'], ['setup']);
      expect(json['skipIf'], 'previous_failed');
      expect(json['testDataOverride'], {'heroName': 'Thor'});

      final restored = CampaignEntry.fromJson(json);
      expect(restored.name, 'login');
      expect(restored.dependsOn, ['setup']);
      expect(restored.skipIf, 'previous_failed');
      expect(restored.testDataOverride!['heroName'], 'Thor');
    });

    test('fromJson with minimal data', () {
      final json = {'stratagem': makeStratagem(name: 'basic').toJson()};
      final entry = CampaignEntry.fromJson(json);
      expect(entry.name, 'basic');
      expect(entry.dependsOn, isEmpty);
      expect(entry.skipIf, isNull);
    });
  });

  // =========================================================================
  // CampaignFailurePolicy
  // =========================================================================

  group('CampaignFailurePolicy', () {
    test('has 3 values', () {
      expect(CampaignFailurePolicy.values, hasLength(3));
    });

    test('enum names', () {
      expect(CampaignFailurePolicy.abortOnFirst.name, 'abortOnFirst');
      expect(CampaignFailurePolicy.continueAll.name, 'continueAll');
      expect(CampaignFailurePolicy.skipDependents.name, 'skipDependents');
    });
  });

  // =========================================================================
  // Campaign model
  // =========================================================================

  group('Campaign model', () {
    test('creates with required fields', () {
      final campaign = makeCampaign();
      expect(campaign.name, 'test_campaign');
      expect(campaign.entries, hasLength(1));
    });

    test('defaults', () {
      final campaign = Campaign(name: 'default', entries: []);
      expect(campaign.includeGauntlet, false);
      expect(campaign.gauntletIntensity, GauntletIntensity.standard);
      expect(campaign.failurePolicy, CampaignFailurePolicy.skipDependents);
      expect(campaign.timeout, const Duration(minutes: 5));
      expect(campaign.tags, isEmpty);
      expect(campaign.sharedTestData, isNull);
      expect(campaign.description, '');
    });

    test('toString', () {
      final campaign = makeCampaign();
      expect(campaign.toString(), contains('test_campaign'));
      expect(campaign.toString(), contains('1 entries'));
    });
  });

  // =========================================================================
  // Topological Sort
  // =========================================================================

  group('Campaign topological sort', () {
    test('no dependencies → single batch', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b'),
          makeEntry(name: 'c'),
        ],
      );
      final batches = campaign.topologicalSort();
      expect(batches, hasLength(1));
      expect(batches[0], hasLength(3));
    });

    test('linear chain → 3 batches', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b', dependsOn: ['a']),
          makeEntry(name: 'c', dependsOn: ['b']),
        ],
      );
      final batches = campaign.topologicalSort();
      expect(batches, hasLength(3));
      expect(batches[0].map((e) => e.name), ['a']);
      expect(batches[1].map((e) => e.name), ['b']);
      expect(batches[2].map((e) => e.name), ['c']);
    });

    test('diamond dependency → correct batches', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b', dependsOn: ['a']),
          makeEntry(name: 'c', dependsOn: ['a']),
          makeEntry(name: 'd', dependsOn: ['b', 'c']),
        ],
      );
      final batches = campaign.topologicalSort();
      expect(batches, hasLength(3));

      // Batch 0: a
      expect(batches[0].map((e) => e.name), ['a']);
      // Batch 1: b and c (parallel)
      expect(batches[1].map((e) => e.name).toSet(), {'b', 'c'});
      // Batch 2: d
      expect(batches[2].map((e) => e.name), ['d']);
    });

    test('circular dependency throws CampaignCycleException', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a', dependsOn: ['c']),
          makeEntry(name: 'b', dependsOn: ['a']),
          makeEntry(name: 'c', dependsOn: ['b']),
        ],
      );
      expect(
        () => campaign.topologicalSort(),
        throwsA(isA<CampaignCycleException>()),
      );
    });

    test('CampaignCycleException toString', () {
      const e = CampaignCycleException(['a', 'b', 'c']);
      expect(e.toString(), contains('a'));
      expect(e.toString(), contains('circular dependency'));
    });

    test('self-dependency throws', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a', dependsOn: ['a']),
        ],
      );
      expect(
        () => campaign.topologicalSort(),
        throwsA(isA<CampaignCycleException>()),
      );
    });

    test('external dependency ignored in sort', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a', dependsOn: ['external_prereq']),
          makeEntry(name: 'b'),
        ],
      );
      // 'external_prereq' not in entries → ignored
      final batches = campaign.topologicalSort();
      expect(batches, hasLength(1));
      expect(batches[0], hasLength(2));
    });

    test('executionOrder flattens batches', () {
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b', dependsOn: ['a']),
          makeEntry(name: 'c', dependsOn: ['a']),
        ],
      );
      final order = campaign.executionOrder();
      expect(order.map((e) => e.name).first, 'a');
      expect(order.map((e) => e.name).toSet(), {'a', 'b', 'c'});
    });

    test('empty campaign → empty batches', () {
      final campaign = makeCampaign(entries: []);
      expect(campaign.topologicalSort(), isEmpty);
      expect(campaign.executionOrder(), isEmpty);
    });

    test('parallel branches produce correct batches', () {
      // a → d, b → d, c → d — 3 independent roots
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b'),
          makeEntry(name: 'c'),
          makeEntry(name: 'd', dependsOn: ['a', 'b', 'c']),
        ],
      );
      final batches = campaign.topologicalSort();
      expect(batches, hasLength(2));
      expect(batches[0], hasLength(3));
      expect(batches[1], hasLength(1));
    });
  });

  // =========================================================================
  // Prerequisite Injection
  // =========================================================================

  group('Campaign prerequisite injection', () {
    test('no prerequisites for entry point screens', () {
      final terrain = Terrain(
        outposts: {'/home': createOutpost(route: '/home')},
      );
      final campaign = makeCampaign(
        entries: [makeEntry(name: 'home_test', startRoute: '/home')],
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      // No prereq needed — /home is entry point (no entrances)
      expect(augmented, hasLength(1));
      expect(augmented[0].name, 'home_test');
    });

    test('injects prerequisite for deep screen', () {
      final march = createMarch(from: '/login', to: '/dashboard');
      final terrain = Terrain(
        outposts: {
          '/login': createOutpost(
            route: '/login',
            displayName: 'Login',
            exits: [march],
          ),
          '/dashboard': createOutpost(
            route: '/dashboard',
            displayName: 'Dashboard',
            entrances: [march],
          ),
        },
      );

      final campaign = makeCampaign(
        entries: [makeEntry(name: 'dashboard_test', startRoute: '/dashboard')],
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      expect(augmented, hasLength(2));
      expect(augmented[0].name, 'prereq_dashboard_test');
      expect(augmented[0].stratagem.tags, contains('prerequisite'));
      expect(augmented[1].name, 'dashboard_test');
      expect(augmented[1].dependsOn, contains('prereq_dashboard_test'));
    });

    test('preserves original dependencies with prereq', () {
      final march = createMarch(from: '/login', to: '/deep');
      final terrain = Terrain(
        outposts: {
          '/login': createOutpost(route: '/login', exits: [march]),
          '/deep': createOutpost(route: '/deep', entrances: [march]),
        },
      );

      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'setup_step'),
          makeEntry(
            name: 'deep_test',
            startRoute: '/deep',
            dependsOn: ['setup_step'],
          ),
        ],
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      final deepEntry = augmented.firstWhere((e) => e.name == 'deep_test');
      expect(deepEntry.dependsOn, contains('setup_step'));
      expect(deepEntry.dependsOn, contains('prereq_deep_test'));
    });

    test('merges sharedTestData with entry testDataOverride', () {
      final march = createMarch(from: '/login', to: '/profile');
      final terrain = Terrain(
        outposts: {
          '/login': createOutpost(route: '/login', exits: [march]),
          '/profile': createOutpost(route: '/profile', entrances: [march]),
        },
      );

      final campaign = Campaign(
        name: 'test',
        entries: [
          CampaignEntry(
            stratagem: makeStratagem(
              name: 'profile_test',
              startRoute: '/profile',
            ),
            testDataOverride: {'heroId': '42'},
          ),
        ],
        sharedTestData: {'heroName': 'Thor'},
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      final prereq = augmented.firstWhere(
        (e) => e.name == 'prereq_profile_test',
      );
      // Prereq should exist
      expect(prereq.stratagem.tags, contains('auto-generated'));
    });

    test('skips prereq if it already exists', () {
      final march = createMarch(from: '/login', to: '/deep');
      final terrain = Terrain(
        outposts: {
          '/login': createOutpost(route: '/login', exits: [march]),
          '/deep': createOutpost(route: '/deep', entrances: [march]),
        },
      );

      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'prereq_deep_test', startRoute: '/login'),
          makeEntry(
            name: 'deep_test',
            startRoute: '/deep',
            dependsOn: ['prereq_deep_test'],
          ),
        ],
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      // Should not duplicate the prereq
      final prereqs = augmented
          .where((e) => e.name == 'prereq_deep_test')
          .toList();
      expect(prereqs, hasLength(1));
    });

    test('unknown route returns entry unchanged', () {
      final terrain = Terrain();
      final campaign = makeCampaign(
        entries: [makeEntry(name: 'unknown', startRoute: '/nowhere')],
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      expect(augmented, hasLength(1));
      expect(augmented[0].name, 'unknown');
    });
  });

  // =========================================================================
  // Gauntlet Augmentation
  // =========================================================================

  group('Campaign gauntlet augmentation', () {
    test('generates gauntlet entries when enabled', () {
      final terrain = Terrain(
        outposts: {
          '/home': createOutpost(
            route: '/home',
            interactive: [button(label: 'Start')],
          ),
        },
      );

      final campaign = makeCampaign(
        includeGauntlet: true,
        gauntletIntensity: GauntletIntensity.quick,
      );
      final gauntletEntries = campaign.generateGauntletEntries(terrain);

      expect(gauntletEntries, isNotEmpty);
      for (final entry in gauntletEntries) {
        expect(entry.stratagem.tags, contains('gauntlet'));
      }
    });

    test('returns empty when gauntlet disabled', () {
      final terrain = Terrain(
        outposts: {
          '/home': createOutpost(route: '/home', interactive: [button()]),
        },
      );

      final campaign = makeCampaign(includeGauntlet: false);
      final gauntletEntries = campaign.generateGauntletEntries(terrain);

      expect(gauntletEntries, isEmpty);
    });

    test('respects gauntlet intensity', () {
      final terrain = Terrain(
        outposts: {
          '/home': createOutpost(
            route: '/home',
            interactive: [button(label: 'Go')],
            exits: [createMarch(from: '/home', to: '/other')],
            tags: ['scrollable'],
          ),
        },
      );

      final quick = Campaign(
        name: 'q',
        entries: [],
        includeGauntlet: true,
        gauntletIntensity: GauntletIntensity.quick,
      ).generateGauntletEntries(terrain);

      final thorough = Campaign(
        name: 't',
        entries: [],
        includeGauntlet: true,
        gauntletIntensity: GauntletIntensity.thorough,
      ).generateGauntletEntries(terrain);

      expect(quick.length, lessThan(thorough.length));
    });
  });

  // =========================================================================
  // CampaignResult
  // =========================================================================

  group('CampaignResult', () {
    CampaignResult makeResult({
      Map<String, Verdict>? verdicts,
      List<String>? skipped,
    }) {
      final v = verdicts ?? {};
      return CampaignResult(
        campaign: makeCampaign(),
        verdicts: v,
        skipped: skipped ?? [],
        executedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 10),
      );
    }

    Verdict makeVerdict(String name, {bool passed = true}) {
      return Verdict(
        stratagemName: name,
        executedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        passed: passed,
        steps: const [],
        summary: const VerdictSummary(
          totalSteps: 1,
          passedSteps: 1,
          failedSteps: 0,
          skippedSteps: 0,
          successRate: 1.0,
          duration: Duration(seconds: 1),
        ),
        performance: const VerdictPerformance(),
      );
    }

    test('passRate 1.0 with all passing', () {
      final result = makeResult(
        verdicts: {'a': makeVerdict('a'), 'b': makeVerdict('b')},
      );
      expect(result.passRate, 1.0);
    });

    test('passRate 0.5 with mixed', () {
      final result = makeResult(
        verdicts: {'a': makeVerdict('a'), 'b': makeVerdict('b', passed: false)},
      );
      expect(result.passRate, 0.5);
    });

    test('passRate 1.0 for empty verdicts', () {
      final result = makeResult();
      expect(result.passRate, 1.0);
    });

    test('allPassed true when all pass and none skipped', () {
      final result = makeResult(verdicts: {'a': makeVerdict('a')});
      expect(result.allPassed, true);
    });

    test('allPassed false when skipped exist', () {
      final result = makeResult(
        verdicts: {'a': makeVerdict('a')},
        skipped: ['b'],
      );
      expect(result.allPassed, false);
    });

    test('allPassed false when any failed', () {
      final result = makeResult(
        verdicts: {'a': makeVerdict('a', passed: false)},
      );
      expect(result.allPassed, false);
    });

    test('totalExecuted and totalFailed', () {
      final result = makeResult(
        verdicts: {
          'a': makeVerdict('a'),
          'b': makeVerdict('b', passed: false),
          'c': makeVerdict('c'),
        },
      );
      expect(result.totalExecuted, 3);
      expect(result.totalFailed, 1);
    });

    test('toReport contains campaign info', () {
      final result = makeResult(
        verdicts: {'a': makeVerdict('a'), 'b': makeVerdict('b', passed: false)},
        skipped: ['c'],
      );

      final report = result.toReport();
      expect(report, contains('test_campaign'));
      expect(report, contains('✓ a'));
      expect(report, contains('✗ b'));
      expect(report, contains('⊘ c'));
    });

    test('toReport shows prerequisites', () {
      final result = CampaignResult(
        campaign: makeCampaign(),
        verdicts: {'a': makeVerdict('a')},
        prerequisiteVerdicts: {'prereq_a': makeVerdict('prereq_a')},
        executedAt: DateTime(2025),
        duration: const Duration(seconds: 5),
      );

      final report = result.toReport();
      expect(report, contains('Prerequisites'));
      expect(report, contains('prereq_a'));
    });

    test('toReport shows gauntlet', () {
      final result = CampaignResult(
        campaign: makeCampaign(),
        verdicts: {},
        gauntletVerdicts: {'g1': makeVerdict('g1')},
        executedAt: DateTime(2025),
        duration: const Duration(seconds: 5),
      );

      final report = result.toReport();
      expect(report, contains('Gauntlet'));
      expect(report, contains('g1'));
    });

    test('toAiDiagnostic contains pass rate', () {
      final result = makeResult(verdicts: {'a': makeVerdict('a')});
      final diag = result.toAiDiagnostic();
      expect(diag, contains('pass_rate: 1.000'));
    });

    test('toAiDiagnostic lists failures', () {
      final failedVerdict = Verdict(
        stratagemName: 'fail_test',
        executedAt: DateTime(2025),
        duration: const Duration(seconds: 1),
        passed: false,
        steps: [
          const VerdictStep(
            stepId: 1,
            description: 'tap button',
            status: VerdictStepStatus.failed,
            duration: Duration(milliseconds: 100),
            failure: VerdictFailure(
              type: VerdictFailureType.targetNotFound,
              message: 'element not found',
            ),
          ),
        ],
        summary: const VerdictSummary(
          totalSteps: 1,
          passedSteps: 0,
          failedSteps: 1,
          skippedSteps: 0,
          successRate: 0,
          duration: Duration(seconds: 1),
        ),
        performance: const VerdictPerformance(),
      );

      final result = makeResult(verdicts: {'fail_test': failedVerdict});

      final diag = result.toAiDiagnostic();
      expect(diag, contains('failures:'));
      expect(diag, contains('fail_test'));
      expect(diag, contains('element not found'));
    });

    test('toJson contains all fields', () {
      final result = makeResult(
        verdicts: {'a': makeVerdict('a')},
        skipped: ['b'],
      );

      final json = result.toJson();
      expect(json['campaign'], 'test_campaign');
      expect(json['passRate'], 1.0);
      expect(json['skipped'], ['b']);
      expect(json['totalExecuted'], 1);
      expect(json['totalFailed'], 0);
      expect(json['verdicts'], isA<Map>());
    });

    test('toString', () {
      final result = makeResult(verdicts: {'a': makeVerdict('a')});
      expect(result.toString(), contains('test_campaign'));
      expect(result.toString(), contains('100.0%'));
    });
  });

  // =========================================================================
  // Campaign serialization
  // =========================================================================

  group('Campaign serialization', () {
    test('toJson round-trip', () {
      final campaign = Campaign(
        name: 'regression',
        description: 'Full regression',
        tags: ['regression', 'nightly'],
        entries: [
          makeEntry(name: 'login', dependsOn: []),
          makeEntry(name: 'create', dependsOn: ['login']),
        ],
        sharedTestData: {'heroName': 'TestHero'},
        includeGauntlet: true,
        gauntletIntensity: GauntletIntensity.thorough,
        failurePolicy: CampaignFailurePolicy.continueAll,
        timeout: const Duration(minutes: 10),
      );

      final json = campaign.toJson();
      expect(json[r'$schema'], 'titan://campaign/v1');
      expect(json['name'], 'regression');
      expect(json['includeGauntlet'], true);
      expect(json['gauntletIntensity'], 'thorough');
      expect(json['failurePolicy'], 'continueAll');
      expect(json['timeout'], 600000);

      final restored = Campaign.fromJson(json);
      expect(restored.name, 'regression');
      expect(restored.description, 'Full regression');
      expect(restored.tags, ['regression', 'nightly']);
      expect(restored.entries, hasLength(2));
      expect(restored.includeGauntlet, true);
      expect(restored.gauntletIntensity, GauntletIntensity.thorough);
      expect(restored.failurePolicy, CampaignFailurePolicy.continueAll);
      expect(restored.timeout.inMinutes, 10);
      expect(restored.sharedTestData!['heroName'], 'TestHero');
    });

    test('fromJson with minimal fields', () {
      final json = {'name': 'minimal', 'entries': <Map<String, dynamic>>[]};
      final campaign = Campaign.fromJson(json);
      expect(campaign.name, 'minimal');
      expect(campaign.entries, isEmpty);
      expect(campaign.includeGauntlet, false);
      expect(campaign.failurePolicy, CampaignFailurePolicy.skipDependents);
    });

    test('fromJson with unknown intensity uses default', () {
      final json = {
        'name': 'test',
        'entries': <Map<String, dynamic>>[],
        'gauntletIntensity': 'unknown_value',
      };
      final campaign = Campaign.fromJson(json);
      expect(campaign.gauntletIntensity, GauntletIntensity.standard);
    });

    test('fromJson preserves entry dependencies', () {
      final json = Campaign(
        name: 'deps',
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b', dependsOn: ['a']),
        ],
      ).toJson();

      final restored = Campaign.fromJson(json);
      expect(restored.entries[1].dependsOn, ['a']);
    });
  });

  // =========================================================================
  // Campaign template
  // =========================================================================

  group('Campaign template', () {
    test('templateDescription is non-empty', () {
      expect(Campaign.templateDescription, isNotEmpty);
      expect(Campaign.templateDescription, contains('Campaign'));
    });

    test('template has required fields', () {
      final t = Campaign.template;
      expect(t[r'$schema'], 'titan://campaign/v1');
      expect(t['name'], isNotNull);
      expect(t['entries'], isNotNull);
      expect(t['failurePolicy'], 'skipDependents');
    });
  });

  // =========================================================================
  // Integration
  // =========================================================================

  group('Campaign integration', () {
    test('full workflow: build, sort, resolve, serialize', () {
      final march1 = createMarch(from: '/home', to: '/login');
      final march2 = createMarch(from: '/login', to: '/dashboard');
      final terrain = Terrain(
        outposts: {
          '/home': createOutpost(
            route: '/home',
            exits: [march1],
            interactive: [button(label: 'Start')],
          ),
          '/login': createOutpost(
            route: '/login',
            entrances: [march1],
            exits: [march2],
            interactive: [button(label: 'Login')],
          ),
          '/dashboard': createOutpost(
            route: '/dashboard',
            entrances: [march2],
            interactive: [button(label: 'View')],
          ),
        },
      );

      final campaign = Campaign(
        name: 'full_workflow',
        description: 'End-to-end test',
        entries: [
          makeEntry(name: 'login_test', startRoute: '/login'),
          makeEntry(
            name: 'dashboard_test',
            startRoute: '/dashboard',
            dependsOn: ['login_test'],
          ),
        ],
        includeGauntlet: true,
        gauntletIntensity: GauntletIntensity.quick,
      );

      // 1. Topological sort
      final batches = campaign.topologicalSort();
      expect(batches, hasLength(2));

      // 2. Resolve prerequisites
      final augmented = campaign.resolvePrerequisites(terrain);
      expect(augmented.length, greaterThan(2));

      // 3. Generate gauntlet
      final gauntlet = campaign.generateGauntletEntries(terrain);
      expect(gauntlet, isNotEmpty);

      // 4. Serialize
      final json = campaign.toJson();
      final restored = Campaign.fromJson(json);
      expect(restored.entries, hasLength(2));
    });

    test('prereq entry uses abortOnFirst policy', () {
      final march = createMarch(from: '/home', to: '/deep');
      final terrain = Terrain(
        outposts: {
          '/home': createOutpost(route: '/home', exits: [march]),
          '/deep': createOutpost(route: '/deep', entrances: [march]),
        },
      );

      final campaign = makeCampaign(
        entries: [makeEntry(name: 'deep_test', startRoute: '/deep')],
      );

      final augmented = campaign.resolvePrerequisites(terrain);
      final prereq = augmented.firstWhere((e) => e.name.startsWith('prereq_'));
      expect(
        prereq.stratagem.failurePolicy,
        StratagemFailurePolicy.abortOnFirst,
      );
    });

    test('large DAG sorts correctly', () {
      // a, b independent; c depends on both; d on c; e on a
      final campaign = makeCampaign(
        entries: [
          makeEntry(name: 'a'),
          makeEntry(name: 'b'),
          makeEntry(name: 'c', dependsOn: ['a', 'b']),
          makeEntry(name: 'd', dependsOn: ['c']),
          makeEntry(name: 'e', dependsOn: ['a']),
        ],
      );

      final order = campaign.executionOrder();
      final names = order.map((e) => e.name).toList();

      // 'a' must come before 'c', 'd', and 'e'
      expect(names.indexOf('a'), lessThan(names.indexOf('c')));
      expect(names.indexOf('a'), lessThan(names.indexOf('d')));
      expect(names.indexOf('a'), lessThan(names.indexOf('e')));

      // 'b' must come before 'c'
      expect(names.indexOf('b'), lessThan(names.indexOf('c')));

      // 'c' must come before 'd'
      expect(names.indexOf('c'), lessThan(names.indexOf('d')));
    });
  });

  // =========================================================================
  // Campaign — authStratagem
  // =========================================================================

  group('Campaign — authStratagem', () {
    Stratagem makeAuthStratagem() {
      return const Stratagem(
        name: '_auth',
        description: 'Auto-login',
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
            target: StratagemTarget(label: 'Enter the Questboard'),
          ),
        ],
      );
    }

    test('authStratagem is null by default', () {
      final campaign = makeCampaign();
      expect(campaign.authStratagem, isNull);
    });

    test('constructor accepts authStratagem', () {
      final auth = makeAuthStratagem();
      final campaign = makeCampaign(authStratagem: auth);
      expect(campaign.authStratagem, isNotNull);
      expect(campaign.authStratagem!.name, '_auth');
    });

    test('toJson includes authStratagem when set', () {
      final auth = makeAuthStratagem();
      final campaign = makeCampaign(authStratagem: auth);
      final json = campaign.toJson();
      expect(json.containsKey('authStratagem'), isTrue);
      expect(json['authStratagem'], isA<Map<String, dynamic>>());
      expect((json['authStratagem'] as Map<String, dynamic>)['name'], '_auth');
    });

    test('toJson omits authStratagem when null', () {
      final campaign = makeCampaign();
      final json = campaign.toJson();
      expect(json.containsKey('authStratagem'), isFalse);
    });

    test('fromJson round-trip preserves authStratagem', () {
      final auth = makeAuthStratagem();
      final campaign = makeCampaign(authStratagem: auth);
      final json = campaign.toJson();
      final restored = Campaign.fromJson(json);
      expect(restored.authStratagem, isNotNull);
      expect(restored.authStratagem!.name, '_auth');
      expect(restored.authStratagem!.steps, hasLength(2));
      expect(restored.authStratagem!.steps.first.target?.label, 'Hero Name');
    });

    test('fromJson without authStratagem produces null', () {
      final campaign = makeCampaign();
      final json = campaign.toJson();
      final restored = Campaign.fromJson(json);
      expect(restored.authStratagem, isNull);
    });

    test('template includes authStratagem section', () {
      final template = Campaign.template;
      expect(template.containsKey('authStratagem'), isTrue);
    });
  });

  // =========================================================================
  // Campaign.fromJson schema validation
  // =========================================================================

  group('Campaign.fromJson — schema validation', () {
    test('throws FormatException when name is missing', () {
      expect(
        () => Campaign.fromJson({'entries': []}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"name"'),
          ),
        ),
      );
    });

    test('throws FormatException when name is wrong type', () {
      expect(
        () => Campaign.fromJson({'name': 42, 'entries': []}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('String'),
          ),
        ),
      );
    });

    test('throws FormatException when entries is missing', () {
      expect(
        () => Campaign.fromJson({'name': 'test'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"entries"'),
          ),
        ),
      );
    });

    test('throws FormatException when entries is wrong type', () {
      expect(
        () => Campaign.fromJson({'name': 'test', 'entries': 'not_a_list'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('List'),
          ),
        ),
      );
    });

    test('parses valid minimal Campaign', () {
      final campaign = Campaign.fromJson({
        'name': 'minimal',
        'entries': <dynamic>[],
      });
      expect(campaign.name, 'minimal');
      expect(campaign.entries, isEmpty);
    });
  });

  // =========================================================================
  // Stratagem.fromJson schema validation
  // =========================================================================

  group('Stratagem.fromJson — schema validation', () {
    test('throws FormatException when name is missing', () {
      expect(
        () => Stratagem.fromJson({'startRoute': '/', 'steps': <dynamic>[]}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"name"'),
          ),
        ),
      );
    });

    test('throws FormatException when name is wrong type', () {
      expect(
        () => Stratagem.fromJson({
          'name': 123,
          'startRoute': '/',
          'steps': <dynamic>[],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('String'),
          ),
        ),
      );
    });

    test('throws FormatException when startRoute is missing', () {
      expect(
        () => Stratagem.fromJson({'name': 'test', 'steps': <dynamic>[]}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"startRoute"'), contains('"test"')),
          ),
        ),
      );
    });

    test('throws FormatException when startRoute is wrong type', () {
      expect(
        () => Stratagem.fromJson({
          'name': 'test',
          'startRoute': 42,
          'steps': <dynamic>[],
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('String'),
          ),
        ),
      );
    });

    test('error message includes stratagem name', () {
      expect(
        () => Stratagem.fromJson({'name': 'login_flow', 'steps': <dynamic>[]}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('login_flow'),
          ),
        ),
      );
    });

    test('parses valid minimal Stratagem', () {
      final s = Stratagem.fromJson({
        'name': 'minimal',
        'startRoute': '/',
        'steps': <dynamic>[],
      });
      expect(s.name, 'minimal');
      expect(s.startRoute, '/');
      expect(s.steps, isEmpty);
    });
  });

  // =========================================================================
  // StratagemStep.fromJson schema validation
  // =========================================================================

  group('StratagemStep.fromJson — schema validation', () {
    test('throws FormatException when id is missing', () {
      expect(
        () => StratagemStep.fromJson({
          'action': 'tap',
          'target': {'label': 'Go'},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"id"'),
          ),
        ),
      );
    });

    test('throws FormatException when id is a String', () {
      expect(
        () => StratagemStep.fromJson({
          'id': 's1',
          'action': 'tap',
          'target': {'label': 'Go'},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('int'), contains('s1')),
          ),
        ),
      );
    });

    test('throws FormatException when action is missing', () {
      expect(
        () => StratagemStep.fromJson({
          'id': 1,
          'target': {'label': 'Go'},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('"action"'), contains('#1')),
          ),
        ),
      );
    });

    test('throws FormatException when action is wrong type', () {
      expect(
        () => StratagemStep.fromJson({
          'id': 1,
          'action': 42,
          'target': {'label': 'Go'},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('String'),
          ),
        ),
      );
    });

    test('error message suggests valid actions', () {
      expect(
        () => StratagemStep.fromJson({
          'id': 2,
          'target': {'label': 'Go'},
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('tap'), contains('enterText')),
          ),
        ),
      );
    });

    test('error message includes step id for missing action', () {
      expect(
        () => StratagemStep.fromJson({'id': 5}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('#5'),
          ),
        ),
      );
    });

    test('parses valid minimal step', () {
      final step = StratagemStep.fromJson({
        'id': 1,
        'action': 'tap',
        'target': {'label': 'Go'},
      });
      expect(step.id, 1);
      expect(step.action, StratagemAction.tap);
      expect(step.target?.label, 'Go');
    });

    test('preserves existing unknown action error', () {
      expect(
        () => StratagemStep.fromJson({'id': 1, 'action': 'nonexistent'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unknown StratagemAction'),
          ),
        ),
      );
    });
  });
}
