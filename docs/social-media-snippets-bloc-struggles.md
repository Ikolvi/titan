# Social Media Snippets — "5 Problems That Make BLoC Cry"

Content derived from `docs/medium-article-where-bloc-struggles.md`.

---

## Twitter/X Thread (10 tweets)

### Tweet 1 (Hook)

> 🏋️ Every state management framework handles a counter.
>
> But what happens when you need pagination + circuit breakers + form validation + undo/redo + cross-feature events in ONE feature?
>
> BLoC calls in sick. Riverpod files for overtime. GetX pretends it's fine.
>
> Titan was built for this. 🧵👇

### Tweet 2 (Problem 1)

> PROBLEM 1: E-Commerce Checkout
>
> You need: cart + form validation + persistence + undo + cross-feature events
>
> BLoC approach:
> • 250+ lines
> • 5 packages (flutter_bloc, hydrated_bloc, formz, custom undo, custom event bus)
> • 4 files
>
> Titan approach:
> • ~60 lines
> • 0 extra packages
> • 1 file

### Tweet 3 (Titan checkout code)

> Here's the Titan checkout in 15 lines:
>
> ```dart
> class CheckoutPillar extends Pillar {
>   late final items = nexusList<CartItem>([]);
>   late final total = derived(() =>
>     items.fold(0.0, (s, i) => s + i.price));
>   late final zip = scroll<String>(
>     validators: [Validators.required()],
>     asyncValidators: [_verifyZipCode],
>   );
>   late final history = epoch<List>([]);
>   late final saved = relic<List>('cart');
> }
> ```
>
> Cart. Forms. Persistence. Undo. One Pillar.

### Tweet 4 (Problem 2)

> PROBLEM 2: Real-Time Dashboard
>
> Need: pagination + health monitoring + rate limiting + circuit breaker + search
>
> BLoC: 3-4 Blocs, 2-3 custom services, 2+ packages, no circuit breaker available
>
> Titan: 1 Pillar with codex + warden + moat + portcullis + sieve
>
> All declarative. All built-in.

### Tweet 5 (Problem 3)

> PROBLEM 3: Multi-Step Registration (11 fields)
>
> BLoC + Formz:
> • 11 FormzInput subclasses
> • 1 massive state with 25-param copyWith
> • 400-500 lines of infrastructure
> • No undo. No persistence.
>
> Titan:
> • scroll<String>() × 11
> • scrollGroup() × 4
> • epoch() for undo
> • relic() for persistence
> • ~80 lines total

### Tweet 6 (Problem 4 — the killer)

> PROBLEM 4: One user action triggers 6 features
>
> User likes a post → update count, user list, notifications, analytics, feed ranking, achievements
>
> BLoC options:
> A) God Object (PostBloc imports 5 other Blocs)
> B) Stream spaghetti
> C) Accept chaos
>
> Titan: Herald 📯
>
> ```dart
> emit(PostLiked(postId: id));
> ```
>
> Zero coupling. Zero imports. Everyone just listens.

### Tweet 7 (Herald visual)

> The Herald pattern is the #1 reason teams switch to Titan.
>
> Your PostPillar emits an event.
> It has NO idea who's listening.
>
> UserPillar? Listening.
> AnalyticsPillar? Listening.
> AchievementPillar? Listening.
>
> Add a 7th feature? One listen() call. Nothing else changes.
>
> This is what "separation of concerns" was supposed to be.

### Tweet 8 (Problem 5)

> PROBLEM 5: Production monitoring
>
> BLoC gives you: BlocObserver (onChange → print())
>
> Titan gives you:
> 🛡️ Vigil — error tracking with severity
> 📜 Chronicle — structured logging
> 🏰 Portcullis — circuit breaker
> 🏊 Moat — rate limiting
> ⚒️ Anvil — retry with backoff
> 💓 Pulse — frame monitoring
> 🧠 Vessel — memory tracking
> 🔁 Echo — rebuild counting
> 👤 Shade — gesture recording
> 📊 Decree — perf reports

### Tweet 9 (Final score)

> THE FINAL SCORE across all 5 problems:
>
> | | BLoC | Titan |
> |--|------|-------|
> | Extra packages | 8-12 | 0 |
> | Boilerplate | 1,000+ lines | ~200 |
> | Hand-rolled features | 15+ | 0 |
> | copyWith methods | ∞ | 0 |
> | Production monitoring | print() | Full telemetry |
>
> 2,277+ tests. 30 benchmarks. MIT license.

### Tweet 10 (CTA)

> Titan is open source, MIT licensed, with 2,277+ tests and 30 tracked benchmarks running on every commit.
>
> No code generation. No build runners. Just reactive state management that scales from counter to enterprise.
>
> 🏛️ github.com/Ikolvi/titan
>
> Full article: [link to Medium post]

---

## LinkedIn Post

> **"Every Flutter state management framework handles a counter. Here's what happens when you need more."**
>
> I've been building Flutter apps for years. I've used BLoC, Riverpod, Provider, GetX — each taught me something valuable. But each also left painful gaps when apps got real.
>
> I just published an article exploring 5 real-world scenarios where traditional state management struggles:
>
> 1️⃣ **E-Commerce Checkout** — Cart + forms + persistence + undo + cross-feature events. BLoC needs 5 packages and 250+ lines. Titan needs 1 file and ~60 lines.
>
> 2️⃣ **Real-Time Dashboard** — Pagination + health monitoring + rate limiting + circuit breaking. BLoC doesn't even have a circuit breaker. Titan's Portcullis is one declaration.
>
> 3️⃣ **Multi-Step Forms** — 11 validated fields with async checks. BLoC + Formz = 400+ lines of infrastructure. Titan's Scroll + ScrollGroup = ~80 lines with undo and persistence included.
>
> 4️⃣ **Cross-Feature Communication** — When one action triggers 6 features. BLoC forces tight coupling or stream spaghetti. Titan's Herald event bus provides zero-coupling communication.
>
> 5️⃣ **Production Monitoring** — BLoC gives you `print()`. Titan gives you circuit breakers, rate limiting, retry queues, frame monitoring, memory tracking, rebuild counting, and exportable performance reports. Built-in.
>
> The key insight: every app eventually needs pagination, form validation, persistence, error tracking, and cross-feature communication. You either get them from one integrated, tested system — or you play Frankenstein with 8 packages.
>
> Titan has 2,277+ tests, 30 tracked benchmarks, and zero code generation. MIT licensed.
>
> 🏛️ Check it out: github.com/Ikolvi/titan
>
> What's the biggest pain point in your current state management setup? I'd love to hear.
>
> #Flutter #Dart #StateManagement #OpenSource #MobileDevs #Programming

---

## Reddit Post (r/FlutterDev)

### Title

**"5 real-world problems where BLoC (and friends) struggle — and how Titan solves them without extra packages"**

### Body

> Hey r/FlutterDev,
>
> I wrote an article exploring 5 genuinely hard problems that every production Flutter app faces — and where popular state management solutions run into walls.
>
> **Not a "counter vs counter" comparison.** These are real scenarios:
>
> 1. **E-Commerce Checkout**: Cart + reactive totals + form validation + persistence + undo + cross-feature events. BLoC needs 5 packages and 250+ lines. Titan does it in ~60 lines with zero extra packages.
>
> 2. **Real-Time Dashboard**: Paginated table + health monitoring + rate limiting + circuit breaker + search. BLoC doesn't have a circuit breaker. Titan has `portcullis()` — one line.
>
> 3. **Multi-Step Registration Form**: 11 fields, 3 async validators, dirty/touch tracking, grouped validity, persistence, undo. BLoC + Formz = 400-500 lines. Titan's Scroll = ~80 lines with undo and persistence built in.
>
> 4. **Cross-Feature Communication**: User likes a post → 6 features need to react. BLoC options: God Object, stream spaghetti, or chaos. Titan's Herald: `emit(PostLiked(...))` — zero coupling.
>
> 5. **Production Monitoring**: BLoC has `BlocObserver`. Titan has circuit breakers (Portcullis), rate limiters (Moat), retry queues (Anvil), frame monitoring (Pulse), memory tracking (Vessel), rebuild counting (Echo), gesture recording & replay (Shade), and exportable performance reports (Decree).
>
> **Stats**: 2,277+ tests, 30 tracked benchmarks in CI, zero code generation, MIT licensed.
>
> Full article: [link]
> GitHub: [github.com/Ikolvi/titan](https://github.com/Ikolvi/titan)
>
> Happy to answer questions about the architecture, migration path, or specific use cases. The article includes side-by-side code comparisons and architecture diagrams for each problem.

---

## Instagram / Carousel Slides (7 slides)

### Slide 1 (Cover)
**"5 Problems That Make BLoC Cry"**
*And how Titan solves them before breakfast*
[Visual: BLoC logo crying, Titan logo with sunglasses]

### Slide 2
**Problem: E-Commerce Checkout**
Cart + Forms + Persistence + Undo + Events

BLoC: 250+ lines, 5 packages, 4 files
Titan: ~60 lines, 0 packages, 1 file

### Slide 3
**Problem: Real-Time Dashboard**
Pagination + Health Monitoring + Rate Limiting + Circuit Breaker

BLoC: "Circuit breaker? What's that?"
Titan: `portcullis()` — one line

### Slide 4
**Problem: 11-Field Registration Form**
Dirty tracking + touch state + async validation + grouped validity

BLoC + Formz: 400+ lines of infrastructure
Titan Scroll: ~80 lines (with undo & persistence free)

### Slide 5
**Problem: Cross-Feature Communication**
1 user tap → 6 features react

BLoC: God Object or Spaghetti
Titan Herald: `emit()` once, everyone listens. Zero coupling.

### Slide 6
**Problem: Production Monitoring**

BLoC: `print()`
Titan: Circuit Breakers • Rate Limiting • Retry Queues • Frame Monitoring • Memory Tracking • Rebuild Counting • Gesture Replay • Performance Reports

### Slide 7 (CTA)
**Titan**: 2,277+ tests. 30 benchmarks. MIT license. Zero code gen.
🏛️ github.com/Ikolvi/titan

---

## Hacker News Submission

### Title
**Titan: Flutter state management with 20+ built-in primitives (pagination, circuit breakers, forms, undo, event bus)**

### Comment
> Titan is a reactive state management architecture for Dart/Flutter. Unlike BLoC/Riverpod/Provider that focus solely on state → UI binding, Titan ships with production primitives that every real app needs:
>
> - Reactive pagination (Codex)
> - Form validation with dirty/touch tracking (Scroll)
> - Circuit breaker (Portcullis)
> - Rate limiter (Moat)
> - Retry queue with backoff (Anvil)
> - Event bus for cross-feature communication (Herald)
> - Persistence (Relic)
> - Undo/redo (Epoch)
> - Frame/memory/rebuild monitoring (Colossus)
> - Priority task queue (Pyre)
> - Async mutex (Embargo)
> - Feature flags (Banner)
> - 20+ more
>
> All integrated with the same auto-tracking reactive engine. Reading `.value` in a widget auto-registers the dependency — no selectors, no manual subscriptions.
>
> 2,277+ tests, 30 tracked benchmarks, zero code generation.
>
> The article linked shows 5 specific scenarios where traditional state management needs 5+ packages and 300+ lines of boilerplate, while Titan handles them declaratively.

---

## Dev.to Tags
`#flutter` `#dart` `#statemanagement` `#opensource` `#mobile`

## Medium Tags
`Flutter` `Dart` `State Management` `Mobile Development` `Open Source` `BLoC` `Software Architecture`
