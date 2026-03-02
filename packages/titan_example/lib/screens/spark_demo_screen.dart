import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

/// Spark Demo Screen — showcases hooks-style widgets.
///
/// Demonstrates: Spark, useCore, useDerived, useEffect, useMemo, useRef,
/// useTextController, useAnimationController, useFocusNode.
class SparkDemoScreen extends Spark {
  const SparkDemoScreen({super.key});

  @override
  Widget ignite(BuildContext context) {
    // --- Reactive state hooks ---
    final count = useCore(0, name: 'counter');
    final heroName = useCore('Kael', name: 'hero-name');
    final doubled = useDerived(() => count.value * 2);

    // --- Controller hooks (auto-disposed) ---
    final nameCtrl = useTextController(text: heroName.value);
    final anim = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final focusNode = useFocusNode(debugLabel: 'hero-name');

    // --- Lifecycle hooks ---
    final renderCount = useRef(0);
    renderCount.value++;

    useEffect(() {
      anim.repeat(reverse: true);
      return null;
    }, []);

    final greeting = useMemo(() => 'Hail, ${heroName.value}! (computed)', [
      heroName.value,
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Spark Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // --- Section: Reactive State ---
            _sectionTitle('useCore & useDerived'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Count: ${count.value}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text('Doubled: ${doubled.value}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => count.value++,
                          icon: const Icon(Icons.add),
                          label: const Text('Increment'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => count.value = 0,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: Controller Hooks ---
            _sectionTitle('useTextController & useFocusNode'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Hero Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => heroName.value = v,
                    ),
                    const SizedBox(height: 8),
                    Text('Hero: ${heroName.value}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: useMemo ---
            _sectionTitle('useMemo'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  greeting,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: useAnimationController ---
            _sectionTitle('useAnimationController'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    FadeTransition(
                      opacity: anim,
                      child: const Icon(Icons.star, size: 48),
                    ),
                    const SizedBox(height: 8),
                    const Text('Pulsing animation (auto-disposed)'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: useRef ---
            _sectionTitle('useRef (no rebuild)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This Spark rendered ${renderCount.value} time(s)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Info ---
            const Text(
              'This entire screen is a single Spark class — no StatefulWidget, '
              'no createState, no dispose. All hooks auto-manage lifecycle.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
