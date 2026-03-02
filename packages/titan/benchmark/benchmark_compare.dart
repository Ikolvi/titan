// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

// =============================================================================
// Titan Benchmark Comparator
// =============================================================================
//
// Standalone tool to compare any two saved benchmark result files.
//
// Usage:
//   dart run benchmark/benchmark_compare.dart <baseline> <current>
//
// Examples:
//   dart run benchmark/benchmark_compare.dart \
//     benchmark/results/history/0.1.0_2025-01-01T00-00-00.json \
//     benchmark/results/latest.json
//
//   dart run benchmark/benchmark_compare.dart \
//     benchmark/results/history/pre-optimization.json \
//     benchmark/results/history/post-optimization.json
//
// =============================================================================

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart run benchmark/benchmark_compare.dart <baseline> <current>');
    print('');
    print('Examples:');
    print('  dart run benchmark/benchmark_compare.dart \\');
    print('    benchmark/results/history/v0.1.0.json \\');
    print('    benchmark/results/latest.json');
    exit(1);
  }

  final baselineFile = File(args[0]);
  final currentFile = File(args[1]);

  if (!baselineFile.existsSync()) {
    print('Error: Baseline file not found: ${args[0]}');
    exit(1);
  }
  if (!currentFile.existsSync()) {
    print('Error: Current file not found: ${args[1]}');
    exit(1);
  }

  final baseline =
      jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
  final current =
      jsonDecode(currentFile.readAsStringSync()) as Map<String, dynamic>;

  final baselineBench = baseline['benchmarks'] as Map<String, dynamic>? ?? {};
  final currentBench = current['benchmarks'] as Map<String, dynamic>? ?? {};

  // Collect all metric names
  final allNames = <String>{...baselineBench.keys, ...currentBench.keys};

  print('');
  print('═══════════════════════════════════════════════════════════════════');
  print('  TITAN BENCHMARK COMPARISON');
  print('═══════════════════════════════════════════════════════════════════');
  print('');
  print('  Baseline: v${baseline['version']} (${baseline['timestamp']})');
  print('  Current:  v${current['version']} (${current['timestamp']})');
  print('');
  print('${'  Metric'.padRight(38)} ${'Baseline'.padRight(18)} '
      '${'Current'.padRight(18)} ${'Change'.padRight(10)} Flag');
  print('  ${'─' * 95}');

  var regressions = 0;
  var improvements = 0;
  var unchanged = 0;
  var newMetrics = 0;
  var removedMetrics = 0;

  // Group by suite for nice output
  final grouped = <String, List<String>>{};
  for (final name in allNames) {
    final suite = _getSuite(name, currentBench, baselineBench);
    grouped.putIfAbsent(suite, () => []).add(name);
  }

  for (final suite in ['core', 'extended', 'enterprise', 'unknown']) {
    final names = grouped[suite];
    if (names == null || names.isEmpty) continue;

    names.sort();
    final suiteLabel = suite[0].toUpperCase() + suite.substring(1);
    print('');
    print('  ── $suiteLabel ${'─' * (60 - suiteLabel.length)}');

    for (final name in names) {
      final hasBaseline = baselineBench.containsKey(name);
      final hasCurrent = currentBench.containsKey(name);

      if (hasBaseline && hasCurrent) {
        final bData = baselineBench[name] as Map<String, dynamic>;
        final cData = currentBench[name] as Map<String, dynamic>;
        final bValue = (bData['value'] as num).toDouble();
        final cValue = (cData['value'] as num).toDouble();
        final unit = cData['unit'] as String? ?? '';

        final bStr = _formatVal(bValue, unit);
        final cStr = _formatVal(cValue, unit);
        final change = _calculateChange(cValue, bValue, unit);
        final changeStr = _formatChange(change);
        final flag = _flag(change);

        if (change > 10) {
          regressions++;
        } else if (change < -10) {
          improvements++;
        } else {
          unchanged++;
        }

        print('  ${name.padRight(36)} ${bStr.padRight(18)} '
            '${cStr.padRight(18)} $changeStr $flag');
      } else if (hasCurrent) {
        final cData = currentBench[name] as Map<String, dynamic>;
        final cValue = (cData['value'] as num).toDouble();
        final unit = cData['unit'] as String? ?? '';
        newMetrics++;
        print('  ${name.padRight(36)} ${'—'.padRight(18)} '
            '${_formatVal(cValue, unit).padRight(18)} ${'NEW'.padLeft(10)} 🆕');
      } else {
        final bData = baselineBench[name] as Map<String, dynamic>;
        final bValue = (bData['value'] as num).toDouble();
        final unit = bData['unit'] as String? ?? '';
        removedMetrics++;
        print('  ${name.padRight(36)} '
            '${_formatVal(bValue, unit).padRight(18)} ${'—'.padRight(18)} '
            '${'REMOVED'.padLeft(10)} ❌');
      }
    }
  }

  print('');
  print('  ${'─' * 95}');
  print('');
  print('  Summary:');
  print('    🔴 Regressions (>10%):  $regressions');
  print('    🟢 Improvements (>10%): $improvements');
  print('    ⚪ Unchanged (±10%):    $unchanged');
  if (newMetrics > 0) print('    🆕 New metrics:          $newMetrics');
  if (removedMetrics > 0) print('    ❌ Removed metrics:      $removedMetrics');
  print('');

  // Exit code for CI usage
  if (regressions > 0) {
    print('  ⚠ $regressions regression(s) detected!');
    exit(1);
  } else {
    print('  ✓ No significant regressions');
    exit(0);
  }
}

String _getSuite(String name, Map<String, dynamic> current,
    Map<String, dynamic> baseline) {
  final data = (current[name] ?? baseline[name]) as Map<String, dynamic>?;
  return (data?['suite'] as String?) ?? 'unknown';
}

double _calculateChange(double current, double previous, String unit) {
  if (previous == 0) return 0;
  final higherIsBetter = unit.contains('/sec') || unit == 'x';
  final pctChange = ((current - previous) / previous) * 100;
  return higherIsBetter ? -pctChange : pctChange;
}

String _formatChange(double change) {
  final sign = change > 0 ? '+' : '';
  return '($sign${change.toStringAsFixed(1)}%)'.padLeft(10);
}

String _flag(double change) {
  if (change > 20) return '🔴';
  if (change > 10) return '🟡';
  if (change < -20) return '🟢';
  if (change < -10) return '💚';
  return '  ';
}

String _formatVal(double value, String unit) {
  String formatted;
  if (value >= 1e6) {
    formatted = '${(value / 1e6).toStringAsFixed(1)}M';
  } else if (value >= 1e3) {
    formatted = '${(value / 1e3).toStringAsFixed(1)}K';
  } else if (value >= 1) {
    formatted = value.toStringAsFixed(2);
  } else {
    formatted = value.toStringAsFixed(3);
  }
  return '$formatted $unit';
}
