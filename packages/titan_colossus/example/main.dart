/// Titan Colossus — Enterprise performance monitoring for Titan.
///
/// This example demonstrates:
/// - [Colossus] — Performance monitoring Pillar
/// - [Tremor] — Configurable performance alerts
/// - [Echo] — Widget rebuild tracking
/// - [Lens] — Debug overlay integration
/// - [Decree] — Performance report generation
/// - [Inscribe] — Report export (Markdown, JSON, HTML)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize performance monitoring (debug mode only)
  if (kDebugMode) {
    Colossus.init(
      tremors: [
        Tremor.fps(), // Alert when FPS < 50
        Tremor.leaks(), // Alert on leak suspects
        Tremor.pageLoad(), // Alert on slow page loads
      ],
      vesselConfig: const VesselConfig(
        leakThreshold: Duration(minutes: 3),
        exemptTypes: {'AuthPillar', 'AppPillar'}, // Long-lived, not leaks
      ),
    );
  }

  runApp(
    // Lens wraps your app with a debug overlay
    Lens(
      enabled: kDebugMode,
      child: const MaterialApp(home: DemoScreen()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Demo Screen — Shows performance monitoring in action
// ---------------------------------------------------------------------------

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Colossus Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Echo tracks rebuild count for this widget
            Echo(
              label: 'CounterDisplay',
              child: const Text('Rebuild-tracked widget'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showReport(context),
              child: const Text('Generate Report'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Lens.toggle(),
              child: const Text('Toggle Debug Overlay'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReport(BuildContext context) {
    if (!kDebugMode) return;

    // Generate a performance Decree
    final decree = Colossus.instance.decree();
    final markdown = Inscribe.markdown(decree);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Health: ${decree.health.name}'),
        content: SingleChildScrollView(child: Text(markdown)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
