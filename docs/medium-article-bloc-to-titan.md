# 🏛️ "I Broke Up With BLoC and Started Dating a Titan" — A Flutter Dev's Migration Guide

*A feature-by-feature survival guide for Flutter developers ready to trade ceremony for superpowers.*

---

**TL;DR**: BLoC taught us discipline. Titan gives us that discipline with 70% less code, auto-tracking reactivity, and 20+ built-in primitives so you can stop gluing packages together like it's arts and crafts day.

**Repository**: [github.com/Ikolvi/titan](https://github.com/Ikolvi/titan) · **License**: MIT

---

## The Five Stages of BLoC Grief

You know the drill. You start a new feature. You need a counter. So you write:

- An abstract event class
- A concrete event class (or three)
- A state class (or a freezed union with 4 variants)
- A Bloc class with event handlers
- A BlocProvider
- A BlocBuilder
- Possibly a BlocListener
- Maybe a BlocSelector
- And at some point, you forgot what the feature was supposed to do

You've written 120 lines of code. The counter goes up and down.

**Congratulations. You are an enterprise developer now. 🎉**

---

## What If I Told You…

What if there was a state management architecture where:

- You don't write event classes. **Ever.**
- You don't write state classes. You just… have state.
- Your widgets know *exactly* which piece of state they use and only rebuild for that piece. **Automatically.**
- Pagination, form validation, persistence, undo/redo, data fetching, error tracking, logging, routing, and a debug overlay are **all built in**.
- It has 2,277+ tests and 30 tracked benchmarks running on every commit.
- It has mythology-inspired names because, honestly, why not.

That's [**Titan**](https://github.com/Ikolvi/titan).

---

## The Name Thing (Yes, There Are Mythology Names)

Before we dive in — yes, Titan uses mythology-inspired names for its concepts. Before you roll your eyes, hear me out: the names actually make things *easier* to remember because they describe what the thing **does**.

Here's your translation cheat sheet:

> **BLoC / Cubit** → **Pillar** (it holds your feature up)
>
> **State class** → **Core** (the beating heart of your data)
>
> **Computed value** → **Derived** (forged from existing state)
>
> **bloc.add(event)** → **Strike** (a decisive action)
>
> **BlocBuilder** → **Vestige** (the trace of state in UI)
>
> **BlocProvider** → **Beacon** (it shines state into the tree)
>
> **BlocObserver** → **Oracle** (it sees everything)

Once you spend 10 minutes with the naming, you'll never want to go back to `MyFeatureBloc`/`MyFeatureEvent`/`MyFeatureState`.

---

## Round 1: The Counter (a.k.a. "Hello World, But Make It Enterprise")

### With BLoC (35+ lines)

```dart
// === Events ===
abstract class CounterEvent {}
class IncrementPressed extends CounterEvent {}
class DecrementPressed extends CounterEvent {}

// === State ===
class CounterState {
  final int count;
  const CounterState(this.count);
}

// === Bloc ===
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(0)) {
    on<IncrementPressed>((event, emit) {
      emit(CounterState(state.count + 1));
    });
    on<DecrementPressed>((event, emit) {
      emit(CounterState(state.count - 1));
    });
  }
}

// === Widget ===
BlocProvider(
  create: (_) => CounterBloc(),
  child: BlocBuilder<CounterBloc, CounterState>(
    builder: (context, state) => Text('${state.count}'),
  ),
)

// === Dispatch ===
context.read<CounterBloc>().add(IncrementPressed());
```

### With Titan (12 lines)

```dart
// === Pillar ===
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
}

// === Widget ===
Beacon(
  pillars: [CounterPillar.new],
  child: Vestige<CounterPillar>(
    builder: (_, c) => Text('${c.count.value}'),
  ),
)

// === Call ===
context.pillar<CounterPillar>().increment();
```

**What just happened?**

- No event classes. You call methods like a normal human.
- No state class. `core(0)` *is* your state.
- No `emit()`. Assigning `count.value++` triggers updates automatically.
- No `BlocSelector` needed. The widget auto-tracks that it reads `count.value` and rebuilds *only* when that specific value changes.

**Lines saved**: ~65%. **Sanity saved**: immeasurable.

---

## Round 2: Computed / Derived Values

With BLoC, if you want a computed value (say, `isCartEmpty` derived from `items.length`), you either:

1. Compute it in the state class and hope consumers use it
2. Create a selector and pray nobody reads raw state instead
3. Create a separate stream and merge it (lol)

### BLoC Way

```dart
// In your state class...
class CartState {
  final List<Item> items;
  bool get isEmpty => items.isEmpty;  // Computed in state
  double get total => items.fold(0, (s, i) => s + i.price);
  const CartState(this.items);
}

// Widget still rebuilds on ANY state change:
BlocBuilder<CartBloc, CartState>(
  builder: (_, state) => Text('Total: ${state.total}'),
)

// Need selective rebuild? Extra widget:
BlocSelector<CartBloc, CartState, double>(
  selector: (state) => state.total,
  builder: (_, total) => Text('Total: $total'),
)
```

### Titan Way

```dart
class CartPillar extends Pillar {
  late final items = nexusList<Item>([]);  // Reactive list!
  late final isEmpty = derived(() => items.isEmpty);
  late final total = derived(
    () => items.fold(0.0, (s, i) => s + i.price),
  );

  void addItem(Item i) => items.add(i);  // O(1), auto-notifies
}

// This widget ONLY rebuilds when total changes.
// Not when items change. Not when isEmpty changes. Just total.
Vestige<CartPillar>(
  builder: (_, cart) => Text('Total: ${cart.total.value}'),
)
```

**The magic**: `Derived` values are lazy (not computed until read), cached (only recompute when dependencies change), and participate in the same auto-tracking system. No selectors. No extra widgets. Just read `.value` and the engine figures it out.

---

## Round 3: Feature-by-Feature Showdown

Since Medium doesn't support tables (because apparently we live in the dark ages), here's the comparison in a format that actually renders:

### ⚡ Boilerplate Per Feature

- **BLoC**: High — events + states + mappers + builder widgets
- **Titan**: Low — Pillar + Cores. That's it.

### 🎯 Rebuild Granularity

- **BLoC**: Widget-level. `BlocBuilder` rebuilds on *any* state emission. Need fine-grained? Add `BlocSelector` per field.
- **Titan**: Sub-widget, per-Core. A widget reading `name.value` won't rebuild when `age.value` changes. Automatic. Zero config.

### 🔍 State Selection / Filtering

- **BLoC**: `BlocSelector<B, S, T>` — extra widget, extra type parameters, easy to forget.
- **Titan**: Free. Just read the value you want. Auto-tracked.

### 🔗 Computed / Derived Values

- **BLoC**: DIY. Compute in state class or create stream combiners.
- **Titan**: `derived(() => ...)` — lazy, cached, auto-tracked, chainable.

### 📡 Cross-Feature Communication

- **BLoC**: Pass blocs to each other? Stream subscriptions? BlocListener chains?
- **Titan**: `Herald` — a built-in event bus. `emit(QuestCompleted())` in one Pillar, `listen<QuestCompleted>(...)` in another. Zero coupling.

### 📄 Pagination

- **BLoC**: Roll your own. Write a `PaginationState` with `items`, `page`, `hasMore`, `isLoading`, `error`… for the 47th time.
- **Titan**: `codex<T>(fetcher)` — built-in cursor & offset pagination with loading states. One line.

### 📝 Form Validation

- **BLoC**: Glue together `formz` or hand-roll validation state for every field.
- **Titan**: `scroll<String>(validators: [...])` + `scrollGroup(scrolls)` — reactive dirty/touched/valid tracking with async validators.

### 💾 Persistence

- **BLoC**: Install `hydrated_bloc`. Implement `fromJson`/`toJson`. Hope serialization doesn't silently fail.
- **Titan**: `relic<T>(key, adapter)` — built-in, pluggable storage backends, auto-save.

### ⏪ Undo / Redo

- **BLoC**: There's a package for that. Maybe. Probably unmaintained.
- **Titan**: `epoch<T>(initial, maxHistory: 50)` — built-in. Call `epoch.undo()` and `epoch.redo()`. Done.

### 🌊 Data Fetching (SWR)

- **BLoC**: Write your own caching layer, or depend on another package, or just fetch-and-pray.
- **Titan**: `quarry<T>(fetcher)` — stale-while-revalidate, automatic retry, request deduplication, error recovery.

### 🧪 Middleware on State

- **BLoC**: `BlocOverrides`? Transformers? It's complicated.
- **Titan**: `core(100, conduits: [ClampConduit(min: 0, max: 100)])` — middleware pipeline directly on each Core. Clamp, validate, transform, log.

### 🪝 Hooks

- **BLoC**: Not a thing. Want hooks? Add `flutter_hooks` + `flutter_bloc` glue.
- **Titan**: `Spark` widget with 28 built-in hooks (`useCore`, `useDerived`, `useEffect`, `useMemo`, `useFuture`, `useRef`…). Hooks are first-class citizens.

### 🗺️ Routing

- **BLoC**: "Use GoRouter." Routing is Not Our Problem™.
- **Titan**: `Atlas` — a Navigator 2.0 router that integrates with Pillars. Routes can own Pillars. Guards read reactive state. Deep linking out of the box.

### 🔐 Auth

- **BLoC**: Roll your own auth state. Manage tokens manually.
- **Titan**: `Argus` — abstract auth base with `signIn`/`signOut` contract, `Garrison` guard factory, `CoreRefresh` token bridge.

### 🐛 Debug Overlay

- **BLoC**: `BlocObserver` shows you logs. No visual overlay.
- **Titan**: `Lens` — a draggable 4-tab debug panel showing all reactive state at runtime, with live updates.

### 🔥 Reactive Collections

- **BLoC**: Emit a new list every time. Copy-on-write. Spread operators everywhere.
- **Titan**: `nexusList<T>()`, `nexusMap<K,V>()`, `nexusSet<T>()` — mutate in-place with O(1) notifications. No copies. Add, remove, swap, toggle — all reactive.

### ❌ Error Tracking

- **BLoC**: `addError()` + `onError` override. One error at a time.
- **Titan**: `Vigil` — centralized error tracking with severity levels, pluggable handlers, and error streams.

### 📊 Performance Monitoring

- **BLoC**: ???
- **Titan**: `Colossus` — frame monitoring (`Pulse`), page load tracking (`Stride`), memory monitoring (`Vessel`), rebuild counting (`Echo`), gesture recording & replay (`Shade`), and exportable reports (`Decree` + `Inscribe`).

### 🧬 Code Generation

- **BLoC**: Optional but common (freezed for state unions).
- **Titan**: None. Zero. No build runners. No generated files. No waiting for code gen during hot reload.

### 🏰 Circuit Breaker

- **BLoC**: Write your own, or find a package on pub.dev last updated in 2022.
- **Titan**: `Portcullis` — reactive circuit breaker with closed/open/half-open states, trip records, configurable thresholds. Built-in.

### 🔄 Retry Queue (Dead Letter Queue)

- **BLoC**: Good luck. Roll a `Timer` and a `Queue` and pretend it's fine.
- **Titan**: `Anvil<T>` — a dead letter queue with exponential/linear/fixed backoff, status tracking, and auto-retry.

### 🏗️ Rate Limiting

- **BLoC**: A `Throttle` stream transformer? Maybe? Or yet another package.
- **Titan**: `Moat` — reactive rate limiter with token bucket algorithm and `MoatPool` for multi-key limiting.

### 🔥 Priority Task Queue

- **BLoC**: You're on your own.
- **Titan**: `Pyre<T>` — priority queue with configurable concurrency, backpressure handling, and per-task results.

### 🚩 Feature Flags

- **BLoC**: Firebase Remote Config? LaunchDarkly SDK? Another external dependency.
- **Titan**: `Banner` — reactive feature flags with evaluation rules, percentage rollouts, user targeting. Built into the Pillar lifecycle.

### 🔎 Search & Filtering

- **BLoC**: Write a `where` clause in your `mapEventToState`… wait, that's deprecated.
- **Titan**: `Sieve<T>` — reactive search/filter with auto-tracked results.

### 🔐 Async Mutex / Semaphore

- **BLoC**: Doesn't exist. Hope your async handlers don't race.
- **Titan**: `Embargo` — async mutex with leases, timeout support, and deadlock detection.

### 📋 Workflow Orchestration

- **BLoC**: Chain some events? Nest some `on<>` handlers? Pray?
- **Titan**: `Saga<T>` — multi-step workflow with rollback support. `Volley<T>` — batch async operations. `Tether` — sequential action chains.

### 📈 Data Aggregation

- **BLoC**: Manually compute running averages in your bloc. Fun.
- **Titan**: `Census<T>` — windowed data aggregation with min/max/avg/sum over time.

### 🏥 Service Health Monitoring

- **BLoC**: Not even in the vocabulary.
- **Titan**: `Warden` — periodic service health checks with reactive status tracking.

### ⚖️ Conflict Resolution

- **BLoC**: ???
- **Titan**: `Arbiter<T>` — configurable conflict resolution strategies (last-write-wins, first-write-wins, custom merge).

### 🏊 Resource Pooling

- **BLoC**: It's a state management library, not an infrastructure framework.
- **Titan**: `Lode<T>` — generic async resource pool with leases and configurable pool size. For DB connections, HTTP clients, whatever.

### 📊 Quota & Budget

- **BLoC**: ???
- **Titan**: `Tithe` — rate-aware quota management with reactive budget tracking.

### 🔗 Data Pipelines

- **BLoC**: Stream transformers, maybe. With lots of boilerplate.
- **Titan**: `Sluice<T>` — multi-stage data pipeline with per-stage metrics, overflow handling, and reactive status.

### ⏰ Job Scheduling

- **BLoC**: `Timer.periodic` and a dream.
- **Titan**: `Clarion` — cron-style job scheduler with retry policies, run history, and reactive job state.

### 📜 Event Sourcing

- **BLoC**: Ironic — BLoC is "event-driven" but doesn't have an event store.
- **Titan**: `Tapestry<E>` — event store with append-only streams, projections (`TapestryWeave`), and snapshot replay.

### 🕸️ DAG Execution

- **BLoC**: What even is this?
- **Titan**: `Lattice` — directed acyclic graph executor for complex startup sequences or dependency-ordered task execution.

---

## Round 4: The Migration Path (It's Not All-or-Nothing)

Good news: you don't have to rewrite your entire app on a Saturday night fueled by energy drinks and regret. Titan coexists peacefully with BLoC:

```dart
// Old and new, side by side
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => OldLegacyBloc()),  // Keep this
  ],
  child: Beacon(
    pillars: [NewHotnessPillar.new],                // Add this
    child: MyApp(),
  ),
)
```

### Recommended Strategy: Bottom-Up

1. **Pick your simplest BLoC.** The one that makes you sad when you open it.
2. **Rewrite it as a Pillar.** Usually takes 5 minutes.
3. **Replace `BlocProvider` with `Beacon`** and `BlocBuilder` with `Vestige`.
4. **Run your tests.** (You have tests, right? Right??)
5. **Repeat** until your codebase no longer makes you question your career choices.

### The Conversion Cheat Sheet

> **Event class** → Delete it. Just make a method on your Pillar.
>
> **State class** → Delete it. Use `core(initialValue)` for each field.
>
> **`on<Event>((event, emit) {...})`** → A method body with `strike(() {...})`.
>
> **`emit(NewState(...))`** → `someCore.value = newValue` (inside a strike).
>
> **`BlocBuilder<B, S>`** → `Vestige<P>(builder: ...)`.
>
> **`BlocSelector<B, S, T>`** → Just use `Vestige`. Auto-tracking handles it.
>
> **`BlocListener<B, S>`** → `watch(() { ... })` inside the Pillar.
>
> **`MultiBlocProvider`** → `Beacon(pillars: [...])`.
>
> **`context.read<B>()`** → `context.pillar<P>()`.
>
> **`BlocObserver`** → `TitanObserver` (Oracle).

---

## Round 5: Real-World Example — A Todo Feature

### BLoC Version (~90 lines)

```dart
// --- Events ---
abstract class TodoEvent {}
class LoadTodos extends TodoEvent {}
class AddTodo extends TodoEvent { final String title; AddTodo(this.title); }
class ToggleTodo extends TodoEvent { final int index; ToggleTodo(this.index); }
class DeleteTodo extends TodoEvent { final int index; DeleteTodo(this.index); }

// --- State ---
class TodoState {
  final List<Todo> todos;
  final bool isLoading;
  final String? error;
  int get remaining => todos.where((t) => !t.done).length;
  const TodoState({this.todos = const [], this.isLoading = false, this.error});
  TodoState copyWith({List<Todo>? todos, bool? isLoading, String? error}) =>
    TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
}

// --- Bloc ---
class TodoBloc extends Bloc<TodoEvent, TodoState> {
  final TodoRepo repo;
  TodoBloc(this.repo) : super(const TodoState()) {
    on<LoadTodos>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final todos = await repo.fetchAll();
        emit(state.copyWith(todos: todos, isLoading: false));
      } catch (e) {
        emit(state.copyWith(error: e.toString(), isLoading: false));
      }
    });
    on<AddTodo>((event, emit) {
      emit(state.copyWith(
        todos: [...state.todos, Todo(title: event.title)],
      ));
    });
    on<ToggleTodo>((event, emit) {
      final updated = [...state.todos];
      updated[event.index] = updated[event.index].toggle();
      emit(state.copyWith(todos: updated));
    });
    on<DeleteTodo>((event, emit) {
      final updated = [...state.todos];
      updated.removeAt(event.index);
      emit(state.copyWith(todos: updated));
    });
  }
}

// --- Widget ---
BlocProvider(
  create: (ctx) => TodoBloc(ctx.read<TodoRepo>())..add(LoadTodos()),
  child: BlocBuilder<TodoBloc, TodoState>(
    builder: (_, state) {
      if (state.isLoading) return CircularProgressIndicator();
      if (state.error != null) return Text('Error: ${state.error}');
      return ListView.builder(
        itemCount: state.todos.length,
        itemBuilder: (_, i) => TodoTile(
          todo: state.todos[i],
          onToggle: () => context.read<TodoBloc>().add(ToggleTodo(i)),
          onDelete: () => context.read<TodoBloc>().add(DeleteTodo(i)),
        ),
      );
    },
  ),
)
```

### Titan Version (~35 lines)

```dart
// === Pillar ===
class TodoPillar extends Pillar {
  final TodoRepo repo;
  TodoPillar(this.repo);

  late final todos = nexusList<Todo>([]);
  late final isLoading = core(false);
  late final error = core<String?>(null);
  late final remaining = derived(
    () => todos.where((t) => !t.done).length,
  );

  @override
  void onInit() => loadTodos();

  Future<void> loadTodos() => strikeAsync(() async {
    isLoading.value = true;
    error.value = null;
    try {
      final result = await repo.fetchAll();
      todos.replaceAll(result);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  });

  void add(String title) => todos.add(Todo(title: title));
  void toggle(int i) => todos[i] = todos[i].toggle();
  void delete(int i) => todos.removeAt(i);
}

// === Widget ===
Beacon(
  create: () => TodoPillar(context.pillar<TodoRepo>()),
  child: Vestige<TodoPillar>(
    builder: (_, p) {
      if (p.isLoading.value) return CircularProgressIndicator();
      if (p.error.value != null) return Text('Error: ${p.error.value}');
      return ListView.builder(
        itemCount: p.todos.length,
        itemBuilder: (_, i) => TodoTile(
          todo: p.todos[i],
          onToggle: () => p.toggle(i),
          onDelete: () => p.delete(i),
        ),
      );
    },
  ),
)
```

Notice: no event classes, no `copyWith`, no spread operators to clone lists. `nexusList` mutates in place with O(1) notifications. `remaining` auto-recomputes. The widget auto-tracks exactly which Cores it reads.

---

## "But I Like BLoC's Event Tracing!"

Fair point. BLoC's event-driven architecture gives you a nice log of what happened and when. Titan answers this differently:

- **Oracle** (`TitanObserver`) — global observer that hooks into Core changes, Pillar lifecycle, and errors. Same visibility, less ceremony.
- **Vigil** — centralized error tracking with severity and stream-based reporting.
- **Chronicle** — structured logging built into every Pillar (`log.info(...)`, `log.warning(...)`, etc.).
- **Annals** — an actual audit trail primitive for tracking business events with timestamps.
- **Colossus** — enterprise-grade performance monitoring that makes BlocObserver look like `print()`.

You're not losing observability. You're gaining a *lot* more of it.

---

## "Okay, But How's the Testing Story?"

Testing a Pillar is absurdly simple because there's no event indirection:

```dart
test('increment increases count', () {
  final pillar = CounterPillar();
  pillar.initialize();  // Required lifecycle step

  expect(pillar.count.value, 0);
  pillar.increment();
  expect(pillar.count.value, 1);

  pillar.dispose();
});
```

Compare that with BLoC testing:

```dart
blocTest<CounterBloc, CounterState>(
  'emits [CounterState(1)] when IncrementPressed is added',
  build: () => CounterBloc(),
  act: (bloc) => bloc.add(IncrementPressed()),
  expect: () => [const CounterState(1)],
);
```

Both work fine, but with Titan you're testing a normal Dart class with normal method calls. No test DSL to learn. No special matchers. Just call methods, check values. Your existing Dart testing knowledge is all you need.

Titan also ships with **Crucible** — a test utility that lets you create pre-configured test environments with snapshot verification.

---

## Round 7: The Infrastructure That Makes BLoC Blush

Here's where it gets absurd. Titan doesn't just handle state management. It ships an entire **infrastructure & resilience layer** called **titan_basalt** — 23 reactive primitives for problems that real production apps face and BLoC has absolutely no answer for.

Let me paint a picture.

You're building a production app. Your API is flaky. Your users have bad connections. You need rate limiting, retry queues, circuit breakers, feature flags, conflict resolution, resource pooling, and a job scheduler.

With BLoC, here's your shopping list:

1. Find a circuit breaker package (good luck)
2. Find a rate limiting package (maybe)
3. Build your own retry queue (definitely)
4. Firebase Remote Config for feature flags (new dependency + account + dashboard)
5. Hand-roll conflict resolution (how hard can it be? *extremely*)
6. Build a resource pool from scratch (Pool on pub.dev, last updated: 2023)
7. `Timer.periodic` for job scheduling (and pretend it's professional)

Now glue them all together. Make sure they share lifecycle with your blocs. Make sure they clean up properly. Make sure they're testable. Have fun.

With Titan, here's the equivalent:

```dart
class PaymentPillar extends Pillar {
  late final apiBreaker = portcullis(
    threshold: 5,
    resetTimeout: Duration(seconds: 30),
  );

  late final retryQueue = anvil<PaymentRequest>(
    maxRetries: 3,
    backoff: AnvilBackoff.exponential(Duration(seconds: 1)),
    processor: (req) => processPayment(req),
  );

  late final apiLimiter = moat(
    maxTokens: 10,
    refillInterval: Duration(seconds: 1),
  );

  late final cache = trove<String, PaymentResult>(
    maxSize: 100,
    ttl: Duration(minutes: 5),
  );

  late final featureFlags = banner(flags: [
    BannerFlag('new_checkout', defaultValue: false),
    BannerFlag('apple_pay', defaultValue: true),
  ]);

  late final syncResolver = arbiter<Order>(
    strategy: ArbiterStrategy.lastWriteWins,
  );

  late final dbPool = lode<DbConnection>(
    create: () async => DbConnection.open(),
    maxSize: 5,
  );

  late final nightly = clarion(name: 'cleanup');
}
```

**Every single one** of these integrates with the Pillar lifecycle — created in `late final` initializers, auto-disposed when the Pillar is disposed, reactive state exposed as Cores you can read in your UI.

Want to show a "service degraded" banner when the circuit breaker trips? Just read `apiBreaker.state.value` in a `Vestige`. It's reactive. It updates automatically.

Want to show retry queue depth in a debug panel? `retryQueue.pending.value`. Done.

This is what I mean when I say Titan is an **architecture**, not a state management library. BLoC manages state. Titan manages your entire application's infrastructure — reactively, with lifecycle, with tests.

**767+ tests** cover titan_basalt alone. That's more tests than some state management libraries have in total.

---

## The Batteries That BLoC Doesn't Include

Here's every built-in primitive you get for free when you `import 'package:titan/titan.dart'`:

> **Core** — reactive mutable state
>
> **Derived** — lazy computed values
>
> **Watch** — reactive side effects
>
> **Strike** — batched mutations
>
> **Herald** — event bus
>
> **Vigil** — error tracking
>
> **Chronicle** — structured logging
>
> **Epoch** — undo/redo with history
>
> **Flux** — debounce, throttle, stream operators
>
> **Relic** — state persistence
>
> **Scroll** — form validation
>
> **Codex** — pagination
>
> **Quarry** — data fetching with SWR
>
> **Conduit** — state middleware
>
> **Prism** — fine-grained state projections
>
> **Nexus** — reactive collections (List, Map, Set)
>
> **Loom** — finite state machines
>
> **Aegis** — type-safe IDs
>
> **Sigil** — unique tokens

And from the companion packages:

> **Vestige** — consumer widget (auto-tracking)
>
> **Spark** — hooks widget (28 hooks)
>
> **Beacon** — provider widget
>
> **Confluence** — multi-Pillar consumer
>
> **Obs** — lightweight reactive widget
>
> **Atlas** — Navigator 2.0 router
>
> **Sentinel** — route guards
>
> **Argus** — authentication
>
> **Colossus** — performance monitoring suite
>
> **Lens** — debug overlay

And from **titan_basalt** (infrastructure & resilience — `import 'package:titan_basalt/titan_basalt.dart'`):

> **Trove** — reactive cache with TTL and eviction policies
>
> **Moat** — rate limiter (token bucket)
>
> **Portcullis** — circuit breaker
>
> **Anvil** — dead letter / retry queue
>
> **Pyre** — priority task queue with backpressure
>
> **Banner** — feature flags with targeting rules
>
> **Sieve** — reactive search & filtering
>
> **Lattice** — DAG executor
>
> **Embargo** — async mutex / semaphore
>
> **Census** — windowed data aggregation
>
> **Warden** — service health monitor
>
> **Arbiter** — conflict resolution strategies
>
> **Lode** — async resource pool
>
> **Tithe** — quota & budget management
>
> **Sluice** — multi-stage data pipeline
>
> **Clarion** — job scheduler
>
> **Tapestry** — event store with projections
>
> **Saga** — multi-step workflow orchestration
>
> **Volley** — batch async operations
>
> **Tether** — sequential action chains
>
> **Annals** — audit trail

With BLoC, you'd need to install and integrate separate packages for *each* of these — if they even exist as packages. Most of these patterns don't have mature pub.dev packages at all. With Titan, they're all integrated into the same reactive engine, all auto-disposed with Pillar lifecycle, all sharing the same dependency graph. It's not a state management library with extras bolted on. It's an **architecture**.

---

## Quick Reference: BLoC → Titan

For developers who just want the translation and want to get moving:

> `Bloc<E, S>` → `Pillar`
>
> `Cubit<S>` → `Pillar` (same thing — Pillar handles both patterns)
>
> `Event` classes → Methods on Pillar
>
> `State` classes → `core(initialValue)` fields
>
> `emit(state)` → `coreField.value = newValue`
>
> `state.copyWith(...)` → Just set the Cores you need
>
> `on<Event>((e, emit) {...})` → A regular method with `strike(() {...})`
>
> `BlocProvider` → `Beacon`
>
> `MultiBlocProvider` → `Beacon(pillars: [...])`
>
> `BlocBuilder` → `Vestige`
>
> `BlocSelector` → `Vestige` (auto-tracking = free selectors)
>
> `BlocListener` → `watch()` or `VestigeListener`
>
> `BlocConsumer` → `VestigeConsumer`
>
> `context.read<B>()` → `context.pillar<P>()`
>
> `context.watch<B>()` → Use inside `Vestige` builder
>
> `BlocObserver` → `TitanObserver`
>
> `bloc.stream` → `core.listen(...)` or `core.asStream()`
>
> `HydratedBloc` → `relic<T>(key, adapter)`
>
> `bloc_test` → Standard `test()` with method calls
>
> `buildWhen:` → Automatic (only reads trigger rebuilds)
>
> `listenWhen:` → `core.select((v) => ...)` or `Prism`

---

## Installation

```yaml
dependencies:
  titan: ^1.0.0            # Core reactive engine
  titan_bastion: ^1.0.0    # Flutter widgets (Vestige, Beacon, Spark)
  titan_basalt: ^1.0.0     # Infrastructure & resilience (Trove, Moat, Portcullis...)
  # Optional:
  titan_atlas: ^1.0.0      # Routing
  titan_argus: ^1.0.0      # Auth
  titan_colossus: ^1.0.0   # Performance monitoring
```

---

## The Bottom Line

BLoC is a solid, battle-tested library. It brought discipline to Flutter state management when the ecosystem desperately needed it. We respect BLoC.

But it's 2026 now. We have signal-based reactivity. We have auto-tracking. We don't need to write event classes for a counter. We don't need to manually wire selectors for every field. We don't need to install 8 packages to get pagination, forms, persistence, and undo/redo.

**Titan takes every lesson BLoC taught us and removes every compromise it forced on us.**

It's one architecture, from prototype to production. One dependency graph, from counter to enterprise dashboard. One reactive engine, sub-microsecond fast, with 2,277+ tests and 30 benchmarks proving it on every commit.

Your BLoC code will still work. Your BLoC patterns will translate cleanly. And tomorrow morning, you'll open that one feature that has 4 event classes, 3 state variants, and a `mapEventToState` that was deprecated two years ago — and you'll rewrite it as a 15-line Pillar.

And you'll smile.

---

**Get started**: [github.com/Ikolvi/titan](https://github.com/Ikolvi/titan)

**Full documentation**: [github.com/Ikolvi/titan/tree/main/docs](https://github.com/Ikolvi/titan/tree/main/docs)

**Packages on pub.dev**: [titan](https://pub.dev/packages/titan) · [titan_basalt](https://pub.dev/packages/titan_basalt) · [titan_bastion](https://pub.dev/packages/titan_bastion) · [titan_atlas](https://pub.dev/packages/titan_atlas) · [titan_argus](https://pub.dev/packages/titan_argus) · [titan_colossus](https://pub.dev/packages/titan_colossus)

---

*If this article saved you from writing one more event class, give it a 👏. If it saved you from writing five, give it fifty.*
