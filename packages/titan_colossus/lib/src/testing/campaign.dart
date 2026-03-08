import '../discovery/gauntlet.dart';
import '../discovery/lineage.dart';
import '../discovery/terrain.dart';
import 'stratagem.dart';
import 'stratagem_runner.dart';
import 'verdict.dart';

// ---------------------------------------------------------------------------
// CampaignFailurePolicy
// ---------------------------------------------------------------------------

/// How the [Campaign] handles failures across Stratagems.
///
/// ```dart
/// final campaign = Campaign(
///   name: 'regression',
///   failurePolicy: CampaignFailurePolicy.skipDependents,
///   entries: [...],
/// );
/// ```
enum CampaignFailurePolicy {
  /// Stop the entire campaign on the first failure.
  abortOnFirst,

  /// Continue executing all Stratagems regardless of failures.
  continueAll,

  /// Skip Stratagems whose dependencies have failed.
  skipDependents,
}

// ---------------------------------------------------------------------------
// CampaignEntry
// ---------------------------------------------------------------------------

/// A single entry in a [Campaign] — wraps a [Stratagem] with dependency
/// metadata.
///
/// ```dart
/// final entry = CampaignEntry(
///   stratagem: loginStratagem,
///   dependsOn: ['setup_hero'],
/// );
/// ```
class CampaignEntry {
  /// The [Stratagem] to execute.
  final Stratagem stratagem;

  /// Names of Stratagems that must succeed before this one runs.
  final List<String> dependsOn;

  /// An optional condition expression to skip this entry.
  ///
  /// Example: `"previous_failed"` — skip if any predecessor failed.
  final String? skipIf;

  /// Override shared test data for this specific entry.
  final Map<String, dynamic>? testDataOverride;

  /// Creates a [CampaignEntry].
  const CampaignEntry({
    required this.stratagem,
    this.dependsOn = const [],
    this.skipIf,
    this.testDataOverride,
  });

  /// Convenience: the Stratagem name (delegates to [stratagem]).
  String get name => stratagem.name;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'stratagem': stratagem.toJson(),
    'dependsOn': dependsOn,
    if (skipIf != null) 'skipIf': skipIf,
    if (testDataOverride != null) 'testDataOverride': testDataOverride,
  };

  /// Deserialize from JSON.
  factory CampaignEntry.fromJson(Map<String, dynamic> json) {
    return CampaignEntry(
      stratagem: Stratagem.fromJson(json['stratagem'] as Map<String, dynamic>),
      dependsOn:
          (json['dependsOn'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      skipIf: json['skipIf'] as String?,
      testDataOverride: json['testDataOverride'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'CampaignEntry(${stratagem.name}, '
      'dependsOn: $dependsOn)';
}

// ---------------------------------------------------------------------------
// CampaignResult
// ---------------------------------------------------------------------------

/// The result of executing a [Campaign].
///
/// ```dart
/// final result = await campaign.execute(runner: runner, terrain: terrain);
/// print('Pass rate: ${result.passRate}');
/// print('Skipped: ${result.skipped}');
/// ```
class CampaignResult {
  /// The [Campaign] that was executed.
  final Campaign campaign;

  /// Verdicts keyed by Stratagem name.
  final Map<String, Verdict> verdicts;

  /// Stratagem names that were skipped (dependency failed).
  final List<String> skipped;

  /// Auto-injected prerequisite Stratagems and their results.
  final Map<String, Verdict> prerequisiteVerdicts;

  /// Gauntlet edge-case results (if generated).
  final Map<String, Verdict>? gauntletVerdicts;

  /// When execution started.
  final DateTime executedAt;

  /// Total execution duration.
  final Duration duration;

  /// Creates a [CampaignResult].
  const CampaignResult({
    required this.campaign,
    required this.verdicts,
    this.skipped = const [],
    this.prerequisiteVerdicts = const {},
    this.gauntletVerdicts,
    required this.executedAt,
    required this.duration,
  });

  /// Overall pass rate: fraction of Stratagems that passed.
  ///
  /// Returns `1.0` if no verdicts exist.
  double get passRate {
    if (verdicts.isEmpty) return 1.0;
    final passed = verdicts.values.where((v) => v.passed).length;
    return passed / verdicts.length;
  }

  /// Whether all Stratagems passed.
  bool get allPassed => passRate == 1.0 && skipped.isEmpty;

  /// Total Stratagems executed (not skipped).
  int get totalExecuted => verdicts.length;

  /// Total Stratagems that failed.
  int get totalFailed => verdicts.values.where((v) => !v.passed).length;

  /// Generate a human-readable report.
  String toReport() {
    final buf = StringBuffer()
      ..writeln('═══════════════════════════════════════════')
      ..writeln('CAMPAIGN REPORT: ${campaign.name}')
      ..writeln('═══════════════════════════════════════════')
      ..writeln('Description: ${campaign.description}')
      ..writeln('Executed at: $executedAt')
      ..writeln('Duration: ${duration.inMilliseconds}ms')
      ..writeln('Pass rate: ${(passRate * 100).toStringAsFixed(1)}%')
      ..writeln('Executed: $totalExecuted')
      ..writeln('Failed: $totalFailed')
      ..writeln('Skipped: ${skipped.length}')
      ..writeln('───────────────────────────────────────────');

    for (final entry in verdicts.entries) {
      final icon = entry.value.passed ? '✓' : '✗';
      buf.writeln('  $icon ${entry.key}');
    }

    for (final name in skipped) {
      buf.writeln('  ⊘ $name (skipped)');
    }

    if (prerequisiteVerdicts.isNotEmpty) {
      buf.writeln('───────────────────────────────────────────');
      buf.writeln('Prerequisites:');
      for (final entry in prerequisiteVerdicts.entries) {
        final icon = entry.value.passed ? '✓' : '✗';
        buf.writeln('  $icon ${entry.key}');
      }
    }

    if (gauntletVerdicts != null && gauntletVerdicts!.isNotEmpty) {
      buf.writeln('───────────────────────────────────────────');
      buf.writeln('Gauntlet edge cases:');
      for (final entry in gauntletVerdicts!.entries) {
        final icon = entry.value.passed ? '✓' : '✗';
        buf.writeln('  $icon ${entry.key}');
      }
    }

    buf.writeln('═══════════════════════════════════════════');
    return buf.toString();
  }

  /// Generate an AI-readable diagnostic.
  String toAiDiagnostic() {
    final buf = StringBuffer()
      ..writeln('campaign: ${campaign.name}')
      ..writeln('pass_rate: ${passRate.toStringAsFixed(3)}')
      ..writeln('total: $totalExecuted')
      ..writeln('failed: $totalFailed')
      ..writeln('skipped: ${skipped.length}');

    final failures = verdicts.entries.where((e) => !e.value.passed);
    if (failures.isNotEmpty) {
      buf.writeln('failures:');
      for (final f in failures) {
        final failedSteps = f.value.steps.where(
          (s) => s.status == VerdictStepStatus.failed,
        );
        buf.writeln('  - ${f.key}: ${failedSteps.length} steps failed');
        for (final step in failedSteps) {
          buf.writeln('    step ${step.stepId}: ${step.failure ?? "unknown"}');
        }
      }
    }

    return buf.toString();
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'campaign': campaign.name,
    'passRate': passRate,
    'executedAt': executedAt.toIso8601String(),
    'duration': duration.inMilliseconds,
    'totalExecuted': totalExecuted,
    'totalFailed': totalFailed,
    'skipped': skipped,
    'verdicts': verdicts.map((k, v) => MapEntry(k, v.toJson())),
    'prerequisiteVerdicts': prerequisiteVerdicts.map(
      (k, v) => MapEntry(k, v.toJson()),
    ),
    if (gauntletVerdicts != null)
      'gauntletVerdicts': gauntletVerdicts!.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
  };

  @override
  String toString() =>
      'CampaignResult(${campaign.name}, '
      'passRate: ${(passRate * 100).toStringAsFixed(1)}%, '
      'executed: $totalExecuted, skipped: ${skipped.length})';
}

// ---------------------------------------------------------------------------
// CampaignCycleException
// ---------------------------------------------------------------------------

/// Thrown when a [Campaign] contains circular dependencies.
class CampaignCycleException implements Exception {
  /// The cycle detected as a list of Stratagem names.
  final List<String> cycle;

  /// Creates a [CampaignCycleException].
  const CampaignCycleException(this.cycle);

  @override
  String toString() =>
      'CampaignCycleException: '
      'circular dependency detected: ${cycle.join(" → ")}';
}

// ---------------------------------------------------------------------------
// Campaign
// ---------------------------------------------------------------------------

/// **Campaign** — an ordered suite of [Stratagem]s with dependency
/// resolution, prerequisite injection, and optional Gauntlet edge-case
/// augmentation.
///
/// A Campaign is the top-level artifact that AI produces as a comprehensive
/// test plan. Unlike a flat list of Stratagems, a Campaign is a **DAG** —
/// entries can declare dependencies on each other, and the engine resolves
/// the correct execution order via topological sort.
///
/// ```dart
/// final campaign = Campaign(
///   name: 'questboard_regression',
///   description: 'Full regression for Questboard',
///   entries: [
///     CampaignEntry(stratagem: loginStratagem),
///     CampaignEntry(
///       stratagem: createQuestStratagem,
///       dependsOn: ['login_happy_path'],
///     ),
///   ],
///   includeGauntlet: true,
///   gauntletIntensity: GauntletIntensity.standard,
/// );
///
/// final result = await campaign.execute(
///   runner: runner,
///   terrain: terrain,
/// );
/// print(result.toReport());
/// ```
class Campaign {
  /// Campaign name / identifier.
  final String name;

  /// Human-readable description.
  final String description;

  /// Tags for categorization.
  final List<String> tags;

  /// The core entries — the user-defined test Stratagems.
  final List<CampaignEntry> entries;

  /// Shared test data across all Stratagems.
  ///
  /// Individual entries can override via [CampaignEntry.testDataOverride].
  final Map<String, dynamic>? sharedTestData;

  /// Whether to generate and include Gauntlet edge cases.
  final bool includeGauntlet;

  /// Gauntlet intensity level.
  final GauntletIntensity gauntletIntensity;

  /// How to handle failures across the campaign.
  final CampaignFailurePolicy failurePolicy;

  /// Total campaign timeout.
  final Duration timeout;

  /// Optional auth [Stratagem] for automatic login handling.
  ///
  /// When specified, the runner detects whether the app is on the
  /// login screen before each Stratagem by checking if the first
  /// step's target is visible. If found (login screen detected),
  /// the runner executes the auth steps automatically, then
  /// re-navigates to the original `startRoute`.
  ///
  /// ```json
  /// {
  ///   "authStratagem": {
  ///     "name": "_auth",
  ///     "startRoute": "",
  ///     "steps": [
  ///       {"id": 1, "action": "enterText", "target": {"label": "Hero Name"}, "value": "Kael"},
  ///       {"id": 2, "action": "tap", "target": {"label": "Enter the Questboard"}}
  ///     ]
  ///   }
  /// }
  /// ```
  final Stratagem? authStratagem;

  /// Creates a [Campaign].
  const Campaign({
    required this.name,
    this.description = '',
    this.tags = const [],
    required this.entries,
    this.sharedTestData,
    this.includeGauntlet = false,
    this.gauntletIntensity = GauntletIntensity.standard,
    this.failurePolicy = CampaignFailurePolicy.skipDependents,
    this.timeout = const Duration(minutes: 5),
    this.authStratagem,
  });

  // -----------------------------------------------------------------------
  // Topological Sort
  // -----------------------------------------------------------------------

  /// Topologically sort entries using Kahn's algorithm.
  ///
  /// Returns a list of execution batches. Each batch contains entries
  /// whose dependencies are all in previous batches — entries within
  /// one batch are independent and can execute in parallel.
  ///
  /// Throws [CampaignCycleException] if a circular dependency is detected.
  List<List<CampaignEntry>> topologicalSort() {
    final entryMap = <String, CampaignEntry>{};
    for (final entry in entries) {
      entryMap[entry.name] = entry;
    }

    // Build in-degree map
    final inDegree = <String, int>{};
    final dependents = <String, List<String>>{};

    for (final entry in entries) {
      inDegree.putIfAbsent(entry.name, () => 0);
      dependents.putIfAbsent(entry.name, () => []);

      for (final dep in entry.dependsOn) {
        // Only count edges to entries within this campaign
        if (entryMap.containsKey(dep)) {
          inDegree[entry.name] = (inDegree[entry.name] ?? 0) + 1;
          dependents.putIfAbsent(dep, () => []);
          dependents[dep]!.add(entry.name);
        }
      }
    }

    final batches = <List<CampaignEntry>>[];
    final processed = <String>{};

    while (processed.length < entries.length) {
      // Find entries with in-degree 0 that haven't been processed
      final ready = <CampaignEntry>[];
      for (final entry in entries) {
        if (!processed.contains(entry.name) &&
            (inDegree[entry.name] ?? 0) == 0) {
          ready.add(entry);
        }
      }

      if (ready.isEmpty) {
        // Cycle detected
        final remaining = entries
            .where((e) => !processed.contains(e.name))
            .map((e) => e.name)
            .toList();
        throw CampaignCycleException(remaining);
      }

      batches.add(ready);

      for (final entry in ready) {
        processed.add(entry.name);
        for (final dependent in (dependents[entry.name] ?? [])) {
          inDegree[dependent] = (inDegree[dependent] ?? 1) - 1;
        }
      }
    }

    return batches;
  }

  /// Flatten topological batches into a single ordered list.
  List<CampaignEntry> executionOrder() {
    return topologicalSort().expand((batch) => batch).toList();
  }

  // -----------------------------------------------------------------------
  // Prerequisite Injection
  // -----------------------------------------------------------------------

  /// Resolve prerequisites and return an augmented list of entries.
  ///
  /// For each entry whose [Stratagem.startRoute] requires setup,
  /// a prerequisite entry is prepended with `prereq_` prefix.
  ///
  /// ```dart
  /// final augmented = campaign.resolvePrerequisites(terrain);
  /// // Now contains prerequisite entries auto-injected
  /// ```
  List<CampaignEntry> resolvePrerequisites(Terrain terrain) {
    final augmented = <CampaignEntry>[];
    final existingNames = entries.map((e) => e.name).toSet();

    for (final entry in entries) {
      final startRoute = entry.stratagem.startRoute;

      final lineage = Lineage.resolve(terrain, targetRoute: startRoute);

      if (lineage.isEmpty) {
        augmented.add(entry);
        continue;
      }

      final prereqName = 'prereq_${entry.name}';

      // Skip if a prerequisite with this name already exists
      if (existingNames.contains(prereqName)) {
        augmented.add(entry);
        continue;
      }

      // Build setup Stratagem from Lineage
      final setupTestData = <String, dynamic>{
        ...?sharedTestData,
        ...?entry.testDataOverride,
      };

      final setupStratagem = lineage.toSetupStratagem(
        testData: setupTestData.isNotEmpty ? setupTestData : null,
      );

      final prereqEntry = CampaignEntry(
        stratagem: Stratagem(
          name: prereqName,
          description: '[Setup] ${setupStratagem.description}',
          tags: const ['prerequisite', 'auto-generated'],
          startRoute: setupStratagem.startRoute,
          steps: setupStratagem.steps,
          failurePolicy: StratagemFailurePolicy.abortOnFirst,
        ),
        dependsOn: entry.dependsOn,
      );

      augmented.add(prereqEntry);

      // Augment the original entry to depend on its prerequisite
      augmented.add(
        CampaignEntry(
          stratagem: entry.stratagem,
          dependsOn: [...entry.dependsOn, prereqName],
          skipIf: entry.skipIf,
          testDataOverride: entry.testDataOverride,
        ),
      );

      existingNames.add(prereqName);
    }

    return augmented;
  }

  // -----------------------------------------------------------------------
  // Gauntlet Augmentation
  // -----------------------------------------------------------------------

  /// Generate Gauntlet edge cases for every screen in the Terrain
  /// and return them as additional [CampaignEntry]s.
  List<CampaignEntry> generateGauntletEntries(Terrain terrain) {
    if (!includeGauntlet) return const [];

    final gauntletEntries = <CampaignEntry>[];

    for (final outpost in terrain.outposts.values) {
      final lineage = Lineage.resolve(
        terrain,
        targetRoute: outpost.routePattern,
      );

      final edgeCases = Gauntlet.generateFor(
        outpost,
        lineage: lineage,
        intensity: gauntletIntensity,
      );

      for (final stratagem in edgeCases) {
        gauntletEntries.add(
          CampaignEntry(stratagem: stratagem, dependsOn: const []),
        );
      }
    }

    return gauntletEntries;
  }

  // -----------------------------------------------------------------------
  // Execution
  // -----------------------------------------------------------------------

  /// Execute the full Campaign.
  ///
  /// Resolves prerequisites, optionally generates Gauntlet edge cases,
  /// topologically sorts all entries, and executes them in order.
  ///
  /// ```dart
  /// final result = await campaign.execute(
  ///   runner: StratagemRunner(shade: shade),
  ///   terrain: terrain,
  /// );
  /// ```
  Future<CampaignResult> execute({
    required StratagemRunner runner,
    required Terrain terrain,
    void Function(String stratagemName, Verdict verdict)? onStratagemComplete,
  }) async {
    final executedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    // 1. Resolve prerequisites
    final augmentedEntries = resolvePrerequisites(terrain);

    // 2. Generate Gauntlet entries
    final gauntletEntries = generateGauntletEntries(terrain);

    // 3. Build full entry list for topological sort
    final allEntries = Campaign(
      name: name,
      entries: [...augmentedEntries, ...gauntletEntries],
    );

    // 4. Topological sort
    final batches = allEntries.topologicalSort();

    // 5. Execute
    final verdicts = <String, Verdict>{};
    final prerequisiteVerdicts = <String, Verdict>{};
    final gauntletVerdictMap = <String, Verdict>{};
    final skipped = <String>[];
    final failed = <String>{};

    for (final batch in batches) {
      // Check timeout
      if (stopwatch.elapsed > timeout) break;

      for (final entry in batch) {
        // Check if should skip
        if (failurePolicy == CampaignFailurePolicy.abortOnFirst &&
            failed.isNotEmpty) {
          skipped.add(entry.name);
          continue;
        }

        if (failurePolicy == CampaignFailurePolicy.skipDependents) {
          final depsFailed = entry.dependsOn.any((dep) => failed.contains(dep));
          if (depsFailed) {
            skipped.add(entry.name);
            continue;
          }
        }

        // Check skipIf
        if (entry.skipIf == 'previous_failed' && failed.isNotEmpty) {
          skipped.add(entry.name);
          continue;
        }

        // Execute
        try {
          final verdict = await runner.execute(entry.stratagem);

          if (entry.name.startsWith('prereq_')) {
            prerequisiteVerdicts[entry.name] = verdict;
          } else if (entry.stratagem.tags.contains('gauntlet')) {
            gauntletVerdictMap[entry.name] = verdict;
          } else {
            verdicts[entry.name] = verdict;
          }

          if (!verdict.passed) {
            failed.add(entry.name);
          }

          onStratagemComplete?.call(entry.name, verdict);
        } catch (e) {
          // Execution error — mark as failed
          failed.add(entry.name);
          verdicts[entry.name] = Verdict(
            stratagemName: entry.name,
            executedAt: DateTime.now(),
            duration: stopwatch.elapsed,
            steps: const [],
            tableaux: const [],
            summary: const VerdictSummary(
              totalSteps: 0,
              passedSteps: 0,
              failedSteps: 0,
              skippedSteps: 0,
              successRate: 0,
              duration: Duration.zero,
              apiErrors: ['Execution error'],
            ),
            performance: const VerdictPerformance(),
            passed: false,
          );
        }
      }
    }

    stopwatch.stop();

    return CampaignResult(
      campaign: this,
      verdicts: verdicts,
      skipped: skipped,
      prerequisiteVerdicts: prerequisiteVerdicts,
      gauntletVerdicts: gauntletVerdictMap.isNotEmpty
          ? gauntletVerdictMap
          : null,
      executedAt: executedAt,
      duration: stopwatch.elapsed,
    );
  }

  // -----------------------------------------------------------------------
  // Template
  // -----------------------------------------------------------------------

  /// AI prompt template for generating Campaigns.
  static String get templateDescription =>
      '''
Generate a Campaign JSON conforming to the titan://campaign/v1 schema.

A Campaign is an ordered suite of Stratagems with dependency resolution.
Each CampaignEntry wraps a Stratagem and declares dependencies via
the "dependsOn" array (names of other Stratagems that must pass first).

The engine will:
1. Topologically sort entries by dependencies
2. Auto-inject login/setup prerequisites from the flow graph
3. Optionally generate Gauntlet edge-case Stratagems
4. Execute in dependency order, respecting the failurePolicy

Available actions: ${StratagemAction.values.map((a) => a.name).join(', ')}
''';

  /// Template JSON for AI to fill out.
  static Map<String, dynamic> get template => {
    r'$schema': 'titan://campaign/v1',
    'name': '<campaign_name>',
    'description': '<description>',
    'tags': ['<tag1>', '<tag2>'],
    'sharedTestData': {'heroName': '<test_hero_name>'},
    'authStratagem': {
      'name': '_auth',
      'description': 'Auto-login when auth screen is detected',
      'startRoute': '',
      'steps': [
        {
          'id': 1,
          'action': 'enterText',
          'target': {'label': '<login_field_label>'},
          'value': r'${testData.heroName}',
        },
        {
          'id': 2,
          'action': 'tap',
          'target': {'label': '<login_button_label>'},
        },
      ],
    },
    'includeGauntlet': false,
    'gauntletIntensity': 'standard',
    'failurePolicy': 'skipDependents',
    'timeout': 300000,
    'entries': [
      {'stratagem': Stratagem.template, 'dependsOn': <String>[]},
    ],
  };

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    r'$schema': 'titan://campaign/v1',
    'name': name,
    'description': description,
    'tags': tags,
    'entries': entries.map((e) => e.toJson()).toList(),
    if (sharedTestData != null) 'sharedTestData': sharedTestData,
    if (authStratagem != null) 'authStratagem': authStratagem!.toJson(),
    'includeGauntlet': includeGauntlet,
    'gauntletIntensity': gauntletIntensity.name,
    'failurePolicy': failurePolicy.name,
    'timeout': timeout.inMilliseconds,
  };

  /// Deserialize from JSON.
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      entries: (json['entries'] as List<dynamic>)
          .map((e) => CampaignEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      sharedTestData: json['sharedTestData'] as Map<String, dynamic>?,
      includeGauntlet: json['includeGauntlet'] as bool? ?? false,
      gauntletIntensity: GauntletIntensity.values.firstWhere(
        (v) => v.name == (json['gauntletIntensity'] as String? ?? 'standard'),
        orElse: () => GauntletIntensity.standard,
      ),
      failurePolicy: CampaignFailurePolicy.values.firstWhere(
        (v) => v.name == (json['failurePolicy'] as String? ?? 'skipDependents'),
        orElse: () => CampaignFailurePolicy.skipDependents,
      ),
      timeout: Duration(milliseconds: json['timeout'] as int? ?? 300000),
      authStratagem: json['authStratagem'] != null
          ? Stratagem.fromJson(json['authStratagem'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() =>
      'Campaign($name, '
      '${entries.length} entries, '
      'gauntlet: $includeGauntlet)';
}
