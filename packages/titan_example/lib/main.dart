import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'pillars/counter_pillar.dart';
import 'pillars/todos_pillar.dart';

void main() {
  // Create the Atlas router — Titan's navigation system
  final atlas = Atlas(
    passages: [
      // Sanctum provides a persistent shell (bottom nav) for its passages
      Sanctum(
        shell: (child) => _AppShell(child: child),
        passages: [
          Passage('/', (_) => const CounterPage(), name: 'counter'),
          Passage('/todos', (_) => const TodoPage(), name: 'todos'),
        ],
      ),
      // Standalone pages outside the shell
      Passage(
        '/counter/details',
        (_) => const CounterDetailPage(),
        shift: Shift.slideUp(),
      ),
      Passage(
        '/about',
        (_) => const AboutPage(),
        shift: Shift.fade(),
        name: 'about',
      ),
    ],
  );

  runApp(
    // Beacon shines Pillar state down to all children
    Beacon(
      pillars: [
        CounterPillar.new,
        TodosPillar.new,
      ],
      // Use MaterialApp.router with Atlas config
      child: MaterialApp.router(
        title: 'Titan Example',
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        routerConfig: atlas.config,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// App Shell — Sanctum's persistent layout (bottom nav)
// ---------------------------------------------------------------------------

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final path = Atlas.current.path;
    final index = path == '/todos' ? 1 : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Titan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.atlas.to('/about'),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          final paths = ['/', '/todos'];
          context.atlas.to(paths[i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Counter',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Todos',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter Page — Vestige auto-tracks Cores, surgical rebuilds
// ---------------------------------------------------------------------------

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vestige rebuilds ONLY when count.value changes
          Vestige<CounterPillar>(
            builder: (context, c) => Text(
              '${c.count.value}',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          const SizedBox(height: 8),
          // This Vestige rebuilds ONLY when label changes
          Vestige<CounterPillar>(
            builder: (context, c) => Text(
              c.label.value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Vestige<CounterPillar>(
            builder: (context, c) => Text('Doubled: ${c.doubled.value}'),
          ),
          const SizedBox(height: 24),
          // Buttons don't need Vestige — they only write, never read
          Builder(builder: (context) {
            final c = context.pillar<CounterPillar>();
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'dec',
                  onPressed: c.decrement,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'reset',
                  onPressed: c.reset,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'inc',
                  onPressed: c.increment,
                  child: const Icon(Icons.add),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.atlas.to('/counter/details'),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter Detail Page — navigated via Atlas with slideUp Shift
// ---------------------------------------------------------------------------

class CounterDetailPage extends StatelessWidget {
  const CounterDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Vestige<CounterPillar>(
              builder: (context, c) => Column(
                children: [
                  Text('Count: ${c.count.value}',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Doubled: ${c.doubled.value}'),
                  const SizedBox(height: 8),
                  Text('Even: ${c.isEven.value}'),
                  const SizedBox(height: 8),
                  Text('Label: ${c.label.value}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Todo Page — demonstrates list management with Vestige
// ---------------------------------------------------------------------------

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input
        Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(builder: (context) {
            final t = context.pillar<TodosPillar>();
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      t.add(value);
                      _controller.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    t.add(_controller.text);
                    _controller.clear();
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            );
          }),
        ),

        // Filter tabs
        Vestige<TodosPillar>(
          builder: (context, t) => SegmentedButton<TodoFilter>(
            segments: const [
              ButtonSegment(value: TodoFilter.all, label: Text('All')),
              ButtonSegment(value: TodoFilter.active, label: Text('Active')),
              ButtonSegment(value: TodoFilter.done, label: Text('Done')),
            ],
            selected: {t.filter.value},
            onSelectionChanged: (s) => t.filter.value = s.first,
          ),
        ),

        // Remaining count
        Padding(
          padding: const EdgeInsets.all(8),
          child: Vestige<TodosPillar>(
            builder: (context, t) =>
                Text('${t.remaining.value} items remaining'),
          ),
        ),

        // Todo list
        Expanded(
          child: Vestige<TodosPillar>(
            builder: (context, t) => ListView.builder(
              itemCount: t.filtered.value.length,
              itemBuilder: (_, i) {
                final todo = t.filtered.value[i];
                return ListTile(
                  leading: Checkbox(
                    value: todo.done,
                    onChanged: (_) => t.toggle(todo.id),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => t.remove(todo.id),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// About Page — navigated via Atlas with fade Shift
// ---------------------------------------------------------------------------

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Titan', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Total Integrated Transfer Architecture Network'),
            SizedBox(height: 24),
            Text('State management: Pillar / Core / Vestige / Beacon'),
            SizedBox(height: 8),
            Text('Navigation: Atlas / Passage / Sanctum / Sentinel'),
            SizedBox(height: 24),
            Text('Built by Ikolvi', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
