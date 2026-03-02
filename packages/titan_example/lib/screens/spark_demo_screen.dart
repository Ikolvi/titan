import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:titan_bastion/titan_bastion.dart';

/// Spark Demo Screen — comprehensive hooks showcase.
///
/// Demonstrates all Spark hooks:
/// - **Core**: [useCore], [useDerived], [useEffect], [useMemo], [useRef]
/// - **Controllers**: [useTextController], [useAnimationController],
///   [useFocusNode]
/// - **Async**: [useStream], [useFuture]
/// - **State**: [useCallback], [usePrevious], [useReducer],
///   [useValueListenable], [useValueChanged]
/// - **Timing**: [useDebounced]
/// - **Lifecycle**: [useAnimation], [useAppLifecycleState], [useIsMounted]
class SparkDemoScreen extends Spark {
  const SparkDemoScreen({super.key});

  @override
  Widget ignite(BuildContext context) {
    // --- Reactive state hooks ---
    final count = useCore(0, name: 'counter');
    final heroName = useCore('Kael', name: 'hero-name');
    final doubled = useDerived(() => count.value * 2);
    final prevCount = usePrevious(count.value);

    // --- Controller hooks (auto-disposed) ---
    final nameCtrl = useTextController(
      text: heroName.value,
      fieldId: 'hero_name_spark',
    );
    final charCount = useValueListenable(nameCtrl);
    final anim = useAnimationController(
      duration: const Duration(milliseconds: 600),
    );
    final opacity = useAnimation(anim);
    final focusNode = useFocusNode(debugLabel: 'hero-name');

    // --- Debounced hero name (updates 500ms after typing stops) ---
    final debouncedName = useDebounced(heroName.value, _kDebounceDuration);

    // --- Memoized callbacks (stable references for child widgets) ---
    final increment = useCallback(() => count.value++, const []);
    final reset = useCallback(() => count.value = 0, const []);

    // --- Lifecycle hooks ---
    final renderCount = useRef(0);
    renderCount.value++;
    final isMounted = useIsMounted();
    final lifecycle = useAppLifecycleState();

    useEffect(() {
      anim.repeat(reverse: true);
      return null;
    }, const []);

    final greeting = useMemo(() => 'Hail, ${heroName.value}! (computed)', [
      heroName.value,
    ]);

    // --- Fire a snackbar when count crosses a milestone ---
    useValueChanged<int, void>(count.value, (oldValue, _) {
      if (count.value > 0 && count.value % 5 == 0 && isMounted()) {
        // Schedule to post-frame — showSnackBar cannot be called during build.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (isMounted()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🏆 Milestone! Count reached ${count.value}'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        });
      }
      return;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Spark Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // --- Section: Reactive State ---
            _sectionTitle('useCore, useDerived & usePrevious'),
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
                    Text(
                      'Previous: ${prevCount ?? "–"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'useValueChanged fires at every 5th count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: increment,
                          icon: const Icon(Icons.add),
                          label: const Text('Increment'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: reset,
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
            _sectionTitle(
              'useTextController, useFocusNode, '
              'useValueListenable & useDebounced',
            ),
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
                    Text(
                      'Characters: ${charCount.text.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Debounced (500ms): ${debouncedName ?? "…"}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.deepPurple),
                    ),
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

            // --- Section: useAnimation ---
            _sectionTitle('useAnimationController & useAnimation'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Opacity(
                      opacity: opacity,
                      child: const Icon(Icons.star, size: 48),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Opacity: ${opacity.toStringAsFixed(2)} '
                      '(useAnimation rebuilds per-frame)',
                    ),
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

            const SizedBox(height: 16),

            // --- Section: useFuture ---
            _sectionTitle('useFuture (async data)'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _HeroLookupSpark(),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: useReducer ---
            _sectionTitle('useReducer (reducer pattern)'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _QuestCounterSpark(),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: useAppLifecycleState ---
            _sectionTitle('useAppLifecycleState'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      lifecycle == AppLifecycleState.resumed
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: lifecycle == AppLifecycleState.resumed
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text('Lifecycle: ${lifecycle.name}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- Section: useStream ---
            _sectionTitle('useStream (live quest feed)'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _QuestFeedSpark(),
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

const _kDebounceDuration = Duration(milliseconds: 500);

// =============================================================================
// _HeroLookupSpark — demonstrates useFuture + useIsMounted
// =============================================================================

/// Simulates fetching a hero from a remote API.
Future<Map<String, dynamic>> _fetchHero(String name) async {
  await Future<void>.delayed(const Duration(seconds: 1));
  return {'name': name, 'class': 'Sentinel', 'glory': 2450, 'rank': 'Champion'};
}

/// Shows [useFuture] with [AsyncValue.when] pattern. The hero data
/// loads asynchronously and [useIsMounted] guards post-async safety.
class _HeroLookupSpark extends Spark {
  const _HeroLookupSpark();

  @override
  Widget ignite(BuildContext context) {
    final snapshot = useFuture(_fetchHero('Kael'), keys: const ['Kael']);

    return snapshot.when(
      onData: (hero) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${hero['name']} — ${hero['class']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Glory: ${hero['glory']}  •  Rank: ${hero['rank']}'),
        ],
      ),
      onLoading: () => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading hero data…'),
        ],
      ),
      onError: (e, _) => Text('Error: $e'),
    );
  }
}

// =============================================================================
// _QuestCounterSpark — demonstrates useReducer
// =============================================================================

/// Uses [useReducer] with a discriminated action type to manage quest
/// completion state — a compact alternative to a full Pillar when state
/// is local to one widget.
class _QuestCounterSpark extends Spark {
  const _QuestCounterSpark();

  @override
  Widget ignite(BuildContext context) {
    final store = useReducer<int, String>(
      (state, action) => switch (action) {
        'complete' => state + 1,
        'fail' => (state - 1).clamp(0, 999),
        'reset' => 0,
        _ => state,
      },
      initialState: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Quests completed: ${store.state}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => store.dispatch('complete'),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete'),
            ),
            OutlinedButton.icon(
              onPressed: () => store.dispatch('fail'),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Fail'),
            ),
            TextButton.icon(
              onPressed: () => store.dispatch('reset'),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// _QuestFeedSpark — demonstrates useStream
// =============================================================================

/// Simulated quest activity feed that emits events periodically.
///
/// Emits a new quest event every 2 seconds. Used by the Spark demo to
/// showcase [useStream] with live-updating data.
Stream<List<String>> _questActivityStream() async* {
  const events = [
    'Kael accepted "Dragon Slayer" quest',
    'Scout completed "Forest Patrol"',
    'Sentinel reached Level 12',
    'Oracle discovered a hidden passage',
    'Builder forged legendary armor',
    'Kael earned 150 glory points',
  ];

  final accumulated = <String>[];
  for (final event in events) {
    accumulated.add(event);
    yield List.of(accumulated);
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

/// Uses [useStream] to subscribe to a live quest event feed.
///
/// Demonstrates `AsyncValue.when()` pattern for rendering loading, error,
/// and data states from a stream subscription. The stream auto-cancels
/// when the widget is disposed.
class _QuestFeedSpark extends Spark {
  const _QuestFeedSpark();

  @override
  Widget ignite(BuildContext context) {
    final feed = useStream(_questActivityStream());

    return feed.when(
      onData: (events) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final event in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(event)),
                ],
              ),
            ),
        ],
      ),
      onLoading: () => const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Waiting for quest activity...'),
        ],
      ),
      onError: (e, _) => Text('Feed error: $e'),
    );
  }
}
