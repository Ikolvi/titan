import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'pillars/counter_pillar.dart';
import 'pillars/todos_pillar.dart';

void main() {
  runApp(
    // Beacon shines Pillar state down to all children
    Beacon(
      pillars: [
        CounterPillar.new,
        TodosPillar.new,
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Titan Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Titan'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_circle), text: 'Counter'),
              Tab(icon: Icon(Icons.checklist), text: 'Todos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [CounterPage(), TodoPage()],
        ),
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
        ],
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
