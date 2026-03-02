# Titan — The State Management Architecture That Learns From Every Mistake Before It

*Why we built another state management solution, and why this one is different.*

---

## The Problem Every Flutter Developer Knows

You've been there. You start a new Flutter project, full of ambition. You pick a state management solution — the one everyone recommends — and for the first two screens, everything works beautifully.

Then the app grows.

Suddenly you're writing event classes, state classes, mappers, and freezed models for a feature that should take twenty minutes. You're debugging widgets that rebuild when they shouldn't. You're wrapping half your widget tree in providers, consumers, and selectors just to pass a boolean two levels down. You're fighting the framework instead of building your product.

We've lived through every era of Flutter state management. `setState` spaghetti. BLoC ceremony. Provider's `context.watch` gotchas. Riverpod's code generation. GetX's magic that stops being magical at scale. Each one solved something. Each one left something painful behind.

**Titan** was built by developers who used all of them — and asked: *What if we could keep every lesson learned and leave every compromise behind?*

---

## The Story Behind the Name

Titan isn't just a name we thought sounded cool (though it does). In mythology, the Titans were the primordial architects — the ones who shaped the world before the gods arrived. They didn't rule through cleverness or trickery. They ruled through *structure*.

That's exactly what Titan does for your app. It gives your state *structure* — not by imposing ceremony, but by making the right pattern the easiest pattern.

Every component in Titan carries a mythology-inspired name. Your state module is a **Pillar** (because it holds everything up). Your reactive state is a **Core** (because it's the beating heart of your feature). Your computed values are **Derived** (because they're forged from what already exists). Your event bus is a **Herald** (because it carries messages between domains).

This isn't just branding. The names tell you *what things do*. When you see a `Sentinel`, you know it guards something. When you see a `Beacon`, you know it broadcasts something. The vocabulary becomes intuition.

---

## What Makes Titan Different

### 1. Auto-Tracking That Actually Works

Most state management solutions require you to *tell* the framework what to watch. You wrap things in `context.watch()`, or `context.select()`, or `ref.watch()`. Miss one, and your UI goes stale. Watch too many, and your UI rebuilds on every breath.

Titan flips this. You just *read* a value. The engine automatically tracks which values each widget reads, and rebuilds *only* that widget when *only* those values change. No annotations. No selectors. No ceremony. It just works — because the reactive engine traces the dependency graph at runtime.

### 2. One Pattern From Prototype to Production

With most frameworks, the way you write code for a prototype is fundamentally different from the way you write code for production. You start with the simple API, then graduate to the "real" API once things get complex. This means rewriting.

In Titan, the same pattern scales from a counter to an enterprise dashboard. A `Pillar` with a `Core` is your counter. That same `Pillar` with Cores, Derived values, Conduit middleware, Persistence, and form validation is your checkout flow. Nothing changes structurally — you just use more of what's already there.

### 3. Built-In Solutions for Real Problems

Every Flutter app eventually needs pagination. Every app needs form validation. Every app needs error tracking, logging, persistence, and undo/redo. Most state management solutions punt on these — "use a separate package."

Titan ships with all of them, fully integrated with the reactive engine:

- **Codex** handles pagination with cursor and offset modes, loading states, and infinite scroll
- **Scroll** handles form validation with dirty tracking, touch state, and group validation
- **Quarry** handles data fetching with stale-while-revalidate, automatic retry, and request deduplication
- **Relic** handles persistence with pluggable storage backends and auto-save
- **Epoch** handles undo/redo with configurable history depth
- **Herald** handles cross-feature communication without coupling
- **Vigil** tracks errors with severity levels, pluggable handlers, and error streams
- **Chronicle** provides structured logging with named loggers and configurable sinks

Each one is a reactive primitive — meaning your UI automatically updates when paginated data arrives, when a form field becomes invalid, when a fetch completes, or when a user undoes their last action. No manual state synchronization required.

### 4. Performance By Design, Not By Accident

Titan's reactive engine operates at sub-microsecond latency for core operations. That's not a marketing claim — it's continuously verified by 30 tracked benchmarks that run on every commit in CI.

The engine uses a dependency graph with topological notification ordering. When a Core changes, only the Derived values and widgets that actually depend on it are re-evaluated — in the correct order, with no glitches, no redundant computations, and no frame drops.

Reactive collections (NexusList, NexusMap, NexusSet) mutate in-place with O(1) amortized operations, avoiding the copy-on-write overhead that plagues immutable state patterns. You call `.add()` on a list — the list mutates, dependents are notified, and zero copies are made.

### 5. Hooks Without the Footguns

React-style hooks are popular for a reason — they eliminate StatefulWidget boilerplate dramatically. But most Dart implementations of hooks either require code generation, fight the framework's widget lifecycle, or sacrifice the reactive tracking that makes everything else work.

Titan's **Spark** widget gives you 13 hooks that compose naturally with the auto-tracking engine. `useCore` gives you reactive state. `useEffect` gives you lifecycle. `useStream` gives you async data. `usePillar` gives you dependency injection. All auto-tracked, all auto-disposed, all playing by the same rules as the rest of the framework.

### 6. Routing That Belongs

Most state management solutions ignore routing entirely — "use GoRouter" or "use auto_route." But routing is state management. The current page, the navigation stack, route parameters, guards, redirects — these are all reactive state that should participate in the same system.

**Atlas** is a Navigator 2.0 router that integrates directly with Pillars. Routes can own Pillars (created on push, disposed on pop). Shells can own Pillars (scoped to the shell lifetime). Guards are just functions that read reactive state. Deep linking, path parameters, query parameters, transitions — all declarative, all type-safe.

---

## How It Compares

| Concern | BLoC | Riverpod | GetX | Titan |
|---------|------|----------|------|-------|
| Boilerplate per feature | High (events, states, mappers) | Medium (providers, notifiers) | Low (but magic) | Low (Pillar + Core) |
| Auto-tracking | No (manual streams) | Partial (ref.watch) | Yes (but imprecise) | Yes (fine-grained, precise) |
| Rebuild granularity | Widget-level | Widget-level | Can over-rebuild | Sub-widget (per-Core) |
| Built-in pagination | No | No | No | Yes (Codex) |
| Built-in form validation | No | No | No | Yes (Scroll) |
| Built-in data fetching | No | Partial (AsyncNotifier) | No | Yes (Quarry with SWR) |
| Built-in persistence | No (use Hydrated BLoC) | No | No (use GetStorage) | Yes (Relic) |
| Built-in undo/redo | No | No | No | Yes (Epoch) |
| Built-in error tracking | No | No | No | Yes (Vigil) |
| Built-in logging | No | No | No | Yes (Chronicle) |
| Event bus | No | No | No | Yes (Herald) |
| Hooks | No | Yes (with riverpod_hooks) | No | Yes (Spark, 13 hooks) |
| Integrated routing | No | No | Yes (GetX routing) | Yes (Atlas, Navigator 2.0) |
| Reactive collections | No | No | Partial (RxList) | Yes (Nexus — List, Map, Set) |
| Middleware on state | No | No | No | Yes (Conduit) |
| Debug overlay | Bloc Observer | No | No | Yes (Lens — 4-tab panel) |
| Code generation required | Optional (freezed) | Optional (riverpod_generator) | No | No |
| Test count | Varies | Varies | Varies | 1,130+ |

---

## The Architecture in One Paragraph

A **Pillar** is your feature's state module. Inside it, you declare **Cores** (mutable reactive values) and **Derived** values (auto-computed from Cores). You mutate state through **Strikes** (batched updates). Your UI uses **Vestiges** (or **Sparks** for hooks-style) that auto-track which Cores they read and rebuild only when those values change. **Beacons** provide Pillars to the widget tree. **Herald** carries events between Pillars without coupling them. Everything is fine-grained, everything is automatic, and everything disposes itself when it's no longer needed.

---

## Who Is This For?

- **Solo developers** who want batteries-included state management without gluing 8 packages together
- **Teams** who want a single, consistent architecture from prototype through production
- **Flutter developers** coming from BLoC/Provider/Riverpod who are tired of boilerplate
- **React developers** who want hooks and signals in Flutter without compromise
- **Performance-focused apps** where unnecessary rebuilds are unacceptable

---

## What You'll Learn Below

The tutorial that follows is called **The Chronicles of Titan** — a 21-chapter narrative where you build *Questboard*, a hero quest-tracking app, from scratch. Each chapter introduces real framework concepts through story. You'll meet Kael, the developer who discovers Titan, and follow along as each new concept solves a real problem in the app.

By the end, you'll have built a production-ready app using every major Titan feature — and you'll understand *why* each one exists, not just *how* to use it.

Let's begin.
