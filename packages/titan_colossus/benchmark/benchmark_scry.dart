// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

// =============================================================================
// Scry Performance Benchmarks — AI Agent Intelligence Pipeline
// =============================================================================
//
// Run with: cd packages/titan_colossus && flutter test benchmark/benchmark_scry.dart
//
// Measures the performance of the Scry observation and intelligence pipeline.
// These benchmarks profile how quickly the AI agent can perceive and reason
// about a screen, which directly impacts agent loop responsiveness.
//
// Benchmarks:
//   1.  observe() — small screen (10 glyphs)
//   2.  observe() — medium screen (50 glyphs)
//   3.  observe() — large screen (200 glyphs)
//   4.  observe() — stress test (500 glyphs)
//   5.  observe() — form-heavy screen (20 fields)
//   6.  observe() — list screen (100 list items)
//   7.  observe() — dialog overlay screen
//   8.  observe() — data-rich screen (30 key-value pairs)
//   9.  formatGaze() — small gaze
//   10. formatGaze() — large gaze
//   11. Full pipeline: observe + formatGaze at scale
//   12. observe() throughput (iterations/sec)
// =============================================================================

void main() {
  test('Scry Performance Benchmarks', () {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  SCRY PERFORMANCE BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    _benchObserveSmall();
    _benchObserveMedium();
    _benchObserveLarge();
    _benchObserveStress();
    _benchObserveForm();
    _benchObserveList();
    _benchObserveOverlay();
    _benchObserveDataRich();
    _benchFormatSmall();
    _benchFormatLarge();
    _benchFullPipeline();
    _benchObserveThroughput();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL SCRY BENCHMARKS COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _ms(Stopwatch sw) {
  final ms = sw.elapsedMilliseconds;
  final us = sw.elapsedMicroseconds;
  if (ms > 0) return '${ms}ms'.padLeft(10);
  return '${us}µs'.padLeft(10);
}

String _pad(int n) => n.toString().padLeft(7);

/// Build a raw glyph map matching the Relay wire format.
Map<String, dynamic> _glyph({
  required String label,
  String widgetType = 'Text',
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 48,
  bool interactive = false,
  String? interactionType,
  String? fieldId,
  String? currentValue,
  String? semanticRole,
  int depth = 5,
  String? key,
  List<String>? ancestors,
  bool enabled = true,
}) {
  return {
    'l': label,
    'wt': widgetType,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'ia': interactive,
    if (interactionType != null) 'it': interactionType,
    if (fieldId != null) 'fid': fieldId,
    if (currentValue != null) 'cv': currentValue,
    if (semanticRole != null) 'sr': semanticRole,
    'd': depth,
    if (key != null) 'k': key,
    if (ancestors != null) 'anc': ancestors,
    'en': enabled,
  };
}

/// Build a small screen with mixed content (buttons, text, nav).
List<Map<String, dynamic>> _smallScreen() {
  return [
    _glyph(label: 'Home', widgetType: 'Text', y: 50, depth: 3),
    _glyph(
      label: 'Submit',
      widgetType: 'ElevatedButton',
      y: 200,
      interactive: true,
      interactionType: 'tap',
    ),
    _glyph(label: 'Welcome back', widgetType: 'Text', y: 100),
    _glyph(
      label: 'Cancel',
      widgetType: 'TextButton',
      y: 200,
      x: 150,
      interactive: true,
      interactionType: 'tap',
    ),
    _glyph(label: 'Status: Active', widgetType: 'Text', y: 150),
    _glyph(
      label: 'Settings',
      widgetType: 'NavigationDestination',
      y: 750,
      interactive: true,
      interactionType: 'tap',
      ancestors: ['NavigationBar'],
    ),
    _glyph(
      label: 'Profile',
      widgetType: 'NavigationDestination',
      y: 750,
      x: 100,
      interactive: true,
      interactionType: 'tap',
      ancestors: ['NavigationBar'],
    ),
    _glyph(label: 'Version 2.1.0', widgetType: 'Text', y: 700),
    _glyph(
      label: 'Help',
      widgetType: 'IconButton',
      y: 50,
      x: 350,
      interactive: true,
      interactionType: 'tap',
    ),
    _glyph(label: 'Last synced: 5m ago', widgetType: 'Text', y: 160),
  ];
}

/// Build a medium screen with 50 glyphs.
List<Map<String, dynamic>> _mediumScreen() {
  final glyphs = <Map<String, dynamic>>[];
  // AppBar title
  glyphs.add(
    _glyph(
      label: 'Dashboard',
      widgetType: 'Text',
      y: 50,
      depth: 3,
      ancestors: ['AppBar'],
    ),
  );
  // Navigation tabs
  for (var i = 0; i < 5; i++) {
    glyphs.add(
      _glyph(
        label: 'Tab ${i + 1}',
        widgetType: 'NavigationDestination',
        y: 750,
        x: i * 80.0,
        interactive: true,
        interactionType: 'tap',
        ancestors: ['NavigationBar'],
      ),
    );
  }
  // Data pairs
  for (var i = 0; i < 10; i++) {
    glyphs.add(
      _glyph(
        label: 'Field $i: Value $i',
        widgetType: 'Text',
        y: 100.0 + i * 30,
      ),
    );
  }
  // Buttons
  for (var i = 0; i < 8; i++) {
    glyphs.add(
      _glyph(
        label: 'Action $i',
        widgetType: 'ElevatedButton',
        y: 400.0 + i * 40,
        interactive: true,
        interactionType: 'tap',
      ),
    );
  }
  // Text content
  for (var i = 0; i < 22; i++) {
    glyphs.add(
      _glyph(
        label: 'Content line $i with some description text',
        widgetType: 'Text',
        y: 100.0 + i * 25,
        x: 20,
      ),
    );
  }
  // Destructive actions
  glyphs.addAll([
    _glyph(
      label: 'Delete',
      widgetType: 'TextButton',
      y: 600,
      interactive: true,
      interactionType: 'tap',
    ),
    _glyph(
      label: 'Reset',
      widgetType: 'TextButton',
      y: 630,
      interactive: true,
      interactionType: 'tap',
    ),
    _glyph(
      label: 'Sign Out',
      widgetType: 'TextButton',
      y: 660,
      interactive: true,
      interactionType: 'tap',
    ),
    _glyph(label: 'Are you sure?', widgetType: 'Text', y: 660, x: 100),
  ]);
  return glyphs;
}

/// Build a large screen with N glyphs.
List<Map<String, dynamic>> _largeScreen(int count) {
  final glyphs = <Map<String, dynamic>>[];
  for (var i = 0; i < count; i++) {
    final isButton = i % 5 == 0;
    final isNav = i % 40 == 0 && i > 0;
    final isField = i % 7 == 0;
    glyphs.add(
      _glyph(
        label: isField
            ? 'Field $i: Data $i'
            : isButton
            ? 'Button $i'
            : 'Item $i description text',
        widgetType: isNav
            ? 'NavigationDestination'
            : isButton
            ? 'ElevatedButton'
            : 'Text',
        y: (i * 30.0) % 800,
        x: (i * 50.0) % 400,
        interactive: isButton || isNav,
        interactionType: (isButton || isNav) ? 'tap' : null,
        depth: (i % 20) + 1,
        ancestors: isNav ? ['NavigationBar'] : null,
      ),
    );
  }
  return glyphs;
}

/// Build a form screen with N text fields.
List<Map<String, dynamic>> _formScreen(int fieldCount) {
  final glyphs = <Map<String, dynamic>>[];
  // Title
  glyphs.add(
    _glyph(
      label: 'Registration Form',
      widgetType: 'Text',
      y: 50,
      ancestors: ['AppBar'],
    ),
  );
  // Fields with labels
  for (var i = 0; i < fieldCount; i++) {
    final labels = [
      'Name',
      'Email',
      'Password',
      'Phone',
      'Address',
      'City',
      'State',
      'Zip',
      'Country',
      'Company',
      'Title',
      'Department',
      'Notes',
      'Website',
      'LinkedIn',
      'Twitter',
      'Bio',
      'Referral Code',
      'Billing Email',
      'Tax ID',
    ];
    final label = labels[i % labels.length];
    final suffix = i >= labels.length ? ' ${i ~/ labels.length + 1}' : '';
    glyphs.add(
      _glyph(
        label: '$label$suffix',
        widgetType: 'TextField',
        y: 100.0 + i * 60,
        interactive: true,
        interactionType: 'tap',
        fieldId: 'field_$i',
        currentValue: i % 3 == 0 ? 'filled value $i' : '',
        semanticRole: 'textField',
      ),
    );
  }
  // Submit button
  glyphs.add(
    _glyph(
      label: 'Submit',
      widgetType: 'ElevatedButton',
      y: 100.0 + fieldCount * 60 + 40,
      interactive: true,
      interactionType: 'tap',
    ),
  );
  return glyphs;
}

/// Build a list screen with N ListTile items.
List<Map<String, dynamic>> _listScreen(int itemCount) {
  final glyphs = <Map<String, dynamic>>[];
  glyphs.add(
    _glyph(label: 'Items', widgetType: 'Text', y: 50, ancestors: ['AppBar']),
  );
  for (var i = 0; i < itemCount; i++) {
    glyphs.add(
      _glyph(
        label: 'Item $i',
        widgetType: 'ListTile',
        y: 100.0 + i * 60,
        interactive: true,
        interactionType: 'tap',
      ),
    );
  }
  return glyphs;
}

/// Build an overlay/dialog screen.
List<Map<String, dynamic>> _dialogScreen() {
  return [
    // Background content
    _glyph(label: 'Home', widgetType: 'Text', y: 50, depth: 3),
    _glyph(
      label: 'Open',
      widgetType: 'ElevatedButton',
      y: 200,
      interactive: true,
      interactionType: 'tap',
      depth: 5,
    ),
    // Dialog
    {'wt': 'AlertDialog', 'l': '', 'd': 20, 'ia': false, 'y': 300.0},
    _glyph(label: 'Confirm Action', widgetType: 'Text', y: 300, depth: 22),
    _glyph(
      label: 'Are you sure you want to proceed?',
      widgetType: 'Text',
      y: 340,
      depth: 22,
    ),
    _glyph(
      label: 'Cancel',
      widgetType: 'TextButton',
      y: 400,
      x: 100,
      interactive: true,
      interactionType: 'tap',
      depth: 23,
    ),
    _glyph(
      label: 'Confirm',
      widgetType: 'FilledButton',
      y: 400,
      x: 250,
      interactive: true,
      interactionType: 'tap',
      depth: 23,
    ),
  ];
}

/// Build a data-rich screen with N key-value pairs.
List<Map<String, dynamic>> _dataRichScreen(int pairCount) {
  final glyphs = <Map<String, dynamic>>[];
  glyphs.add(
    _glyph(label: 'Details', widgetType: 'Text', y: 50, ancestors: ['AppBar']),
  );
  // Inline key: value pairs
  for (var i = 0; i < pairCount ~/ 2; i++) {
    glyphs.add(
      _glyph(
        label: 'Metric $i: ${1000 + i * 42}',
        widgetType: 'Text',
        y: 100.0 + i * 30,
      ),
    );
  }
  // Proximity pairs (label on left, value on right)
  for (var i = pairCount ~/ 2; i < pairCount; i++) {
    final row = i - pairCount ~/ 2;
    glyphs.add(
      _glyph(label: 'Stat $i', widgetType: 'Text', y: 500.0 + row * 30, x: 20),
    );
    glyphs.add(
      _glyph(
        label: '${2000 + i}',
        widgetType: 'Text',
        y: 500.0 + row * 30,
        x: 300,
      ),
    );
  }
  return glyphs;
}

// ---------------------------------------------------------------------------
// 1. observe() — Small Screen (10 glyphs)
// ---------------------------------------------------------------------------

void _benchObserveSmall() {
  print('┌─ 1. observe() — Small Screen (10 glyphs) ────────────');

  const scry = Scry();
  final screen = _smallScreen();

  const count = 10000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/home');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 2. observe() — Medium Screen (50 glyphs)
// ---------------------------------------------------------------------------

void _benchObserveMedium() {
  print('┌─ 2. observe() — Medium Screen (50 glyphs) ───────────');

  const scry = Scry();
  final screen = _mediumScreen();

  const count = 5000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/dashboard');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 3. observe() — Large Screen (200 glyphs)
// ---------------------------------------------------------------------------

void _benchObserveLarge() {
  print('┌─ 3. observe() — Large Screen (200 glyphs) ───────────');

  const scry = Scry();
  final screen = _largeScreen(200);

  const count = 1000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/complex');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 4. observe() — Stress Test (500 glyphs)
// ---------------------------------------------------------------------------

void _benchObserveStress() {
  print('┌─ 4. observe() — Stress Test (500 glyphs) ────────────');

  const scry = Scry();
  final screen = _largeScreen(500);

  const count = 200;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/stress');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 5. observe() — Form Screen (20 fields)
// ---------------------------------------------------------------------------

void _benchObserveForm() {
  print('┌─ 5. observe() — Form Screen (20 fields) ─────────────');

  const scry = Scry();
  final screen = _formScreen(20);

  const count = 5000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/register');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 6. observe() — List Screen (100 items)
// ---------------------------------------------------------------------------

void _benchObserveList() {
  print('┌─ 6. observe() — List Screen (100 items) ─────────────');

  const scry = Scry();
  final screen = _listScreen(100);

  const count = 1000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/items');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 7. observe() — Dialog Overlay Screen
// ---------------------------------------------------------------------------

void _benchObserveOverlay() {
  print('┌─ 7. observe() — Dialog Overlay Screen ───────────────');

  const scry = Scry();
  final screen = _dialogScreen();

  const count = 10000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/confirm');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 8. observe() — Data-Rich Screen (30 KV pairs)
// ---------------------------------------------------------------------------

void _benchObserveDataRich() {
  print('┌─ 8. observe() — Data-Rich Screen (30 KV pairs) ──────');

  const scry = Scry();
  final screen = _dataRichScreen(30);

  const count = 5000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.observe(screen, route: '/details');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 9. formatGaze() — Small Gaze
// ---------------------------------------------------------------------------

void _benchFormatSmall() {
  print('┌─ 9. formatGaze() — Small Gaze ───────────────────────');

  const scry = Scry();
  final gaze = scry.observe(_smallScreen(), route: '/home');

  const count = 10000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.formatGaze(gaze);
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 10. formatGaze() — Large Gaze
// ---------------------------------------------------------------------------

void _benchFormatLarge() {
  print('┌─ 10. formatGaze() — Large Gaze ──────────────────────');

  const scry = Scry();
  final gaze = scry.observe(_mediumScreen(), route: '/dashboard');

  const count = 5000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    scry.formatGaze(gaze);
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  ${_pad(count)} calls:  ${_ms(sw)}  ($perOp µs/op)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 11. Full Pipeline: observe + formatGaze at Scale
// ---------------------------------------------------------------------------

void _benchFullPipeline() {
  print('┌─ 11. Full Pipeline: observe + formatGaze ────────────');

  const scry = Scry();
  final screens = [
    _smallScreen(),
    _mediumScreen(),
    _largeScreen(200),
    _formScreen(10),
    _listScreen(50),
    _dialogScreen(),
    _dataRichScreen(20),
  ];

  const cycles = 500;
  final sw = Stopwatch()..start();
  for (var i = 0; i < cycles; i++) {
    final screen = screens[i % screens.length];
    final gaze = scry.observe(screen, route: '/test');
    scry.formatGaze(gaze);
  }
  sw.stop();

  final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
  print('│  ${_pad(cycles)} cycles:  ${_ms(sw)}  ($perCycle µs/cycle)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 12. observe() Throughput (ops/sec)
// ---------------------------------------------------------------------------

void _benchObserveThroughput() {
  print('┌─ 12. observe() Throughput ────────────────────────────');

  const scry = Scry();
  final screen = _mediumScreen();

  // Run for ~1 second and count iterations
  var count = 0;
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < 1000) {
    scry.observe(screen, route: '/bench');
    count++;
  }
  sw.stop();

  final opsPerSec = (count / sw.elapsedMicroseconds * 1e6).toStringAsFixed(0);
  print('│  $opsPerSec ops/sec (50-glyph screen)');
  print('└───────────────────────────────────────────────────────');
  print('');
}
