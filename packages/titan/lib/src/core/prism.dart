import 'computed.dart';
import 'state.dart';

// =============================================================================
// Prism — Fine-Grained, Memoized State Projections
// =============================================================================
//
// A Prism creates a read-only reactive view over one or more source Cores.
// Unlike Derived (which auto-tracks any reactive read), Prism provides:
//
// - Explicit source declaration for predictable dependencies
// - Multi-source combining with full type safety (up to 4 sources)
// - Built-in structural equality helpers for collections
// - Composition from other Prisms or Derived values
//
// =============================================================================

/// **Prism** — A fine-grained, memoized state projection.
///
/// Creates a read-only reactive view by selecting a sub-value from one
/// or more [Core]s. Only notifies dependents when the projected value
/// actually changes — enabling surgical widget rebuilds.
///
/// ## Single-Source
///
/// ```dart
/// final user = Core(User(name: 'Kael', level: 10, health: 100));
///
/// // Only triggers when name changes, not level or health
/// final userName = Prism(user, (u) => u.name);
/// print(userName.value); // 'Kael'
/// ```
///
/// ## Multi-Source
///
/// ```dart
/// final firstName = Core('Kael');
/// final lastName = Core('the Brave');
///
/// final fullName = Prism.combine2(
///   firstName, lastName,
///   (first, last) => '$first $last',
/// );
/// print(fullName.value); // 'Kael the Brave'
/// ```
///
/// ## Structural Equality
///
/// ```dart
/// final items = Core(<String>['sword', 'shield']);
///
/// // Uses list equality — won't re-notify if same elements
/// final weapons = Prism(
///   items,
///   (list) => list.where((i) => i != 'potion').toList(),
///   equals: PrismEquals.list,
/// );
/// ```
///
/// ## In a Pillar
///
/// ```dart
/// class QuestPillar extends Pillar {
///   late final quest = core(Quest(...));
///   late final questTitle = prism(quest, (q) => q.title);
///   late final questReward = prism(quest, (q) => q.reward);
/// }
/// ```
class Prism<T> extends TitanComputed<T> {
  /// Creates a Prism that projects a sub-value from a single source.
  ///
  /// For type-safe selectors, prefer [Prism.of] or the [prism] extension
  /// on [Core]: `source.prism((v) => v.field)`.
  ///
  /// ```dart
  /// final user = Core(User(name: 'Alice', age: 30));
  /// final age = Prism.of(user, (u) => u.age);
  /// ```
  Prism(
    TitanState<dynamic> source,
    T Function(dynamic sourceValue) selector, {
    String? name,
    bool Function(T previous, T next)? equals,
  }) : super(() => selector(source.value), name: name, equals: equals);

  /// Type-safe factory for creating a Prism from a typed source.
  ///
  /// Provides full type inference for the selector function.
  ///
  /// ```dart
  /// final user = Core(User(name: 'Alice', age: 30));
  /// final age = Prism.of(user, (u) => u.age);
  /// ```
  static Prism<R> of<S, R>(
    TitanState<S> source,
    R Function(S value) selector, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    return Prism<R>(
      source,
      (v) => selector(v as S),
      name: name,
      equals: equals,
    );
  }

  /// Creates a Prism by combining two sources with full type safety.
  ///
  /// ```dart
  /// final price = Core(29.99);
  /// final quantity = Core(3);
  ///
  /// final total = Prism.combine2(
  ///   price, quantity,
  ///   (p, q) => p * q,
  /// );
  /// ```
  static Prism<R> combine2<A, B, R>(
    TitanState<A> source1,
    TitanState<B> source2,
    R Function(A a, B b) combiner, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    return Prism._compute(
      () => combiner(source1.value, source2.value),
      name: name,
      equals: equals,
    );
  }

  /// Creates a Prism by combining three sources with full type safety.
  ///
  /// ```dart
  /// final subtotal = Prism.combine3(
  ///   price, quantity, discount,
  ///   (p, q, d) => p * q * (1 - d),
  /// );
  /// ```
  static Prism<R> combine3<A, B, C, R>(
    TitanState<A> source1,
    TitanState<B> source2,
    TitanState<C> source3,
    R Function(A a, B b, C c) combiner, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    return Prism._compute(
      () => combiner(source1.value, source2.value, source3.value),
      name: name,
      equals: equals,
    );
  }

  /// Creates a Prism by combining four sources with full type safety.
  ///
  /// ```dart
  /// final summary = Prism.combine4(
  ///   name, level, health, mana,
  ///   (n, l, h, m) => '$n (Lv$l) HP:$h MP:$m',
  /// );
  /// ```
  static Prism<R> combine4<A, B, C, D, R>(
    TitanState<A> source1,
    TitanState<B> source2,
    TitanState<C> source3,
    TitanState<D> source4,
    R Function(A a, B b, C c, D d) combiner, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    return Prism._compute(
      () => combiner(
        source1.value,
        source2.value,
        source3.value,
        source4.value,
      ),
      name: name,
      equals: equals,
    );
  }

  /// Creates a Prism that projects from a [TitanComputed] (Derived/Prism).
  ///
  /// Useful for composing projections from other derived values.
  ///
  /// ```dart
  /// final fullName = derived(() => '${first.value} ${last.value}');
  /// final initials = Prism.fromDerived(
  ///   fullName,
  ///   (name) => name.split(' ').map((w) => w[0]).join(),
  /// );
  /// ```
  static Prism<R> fromDerived<S, R>(
    TitanComputed<S> source,
    R Function(S sourceValue) selector, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    return Prism._compute(
      () => selector(source.value),
      name: name,
      equals: equals,
    );
  }

  /// Internal constructor that takes a raw compute function.
  Prism._compute(
    super.compute, {
    super.name,
    super.equals,
  });

  @override
  String toString() {
    final label = name != null ? '($name)' : '';
    return 'Prism$label<$T>: $value';
  }
}

// =============================================================================
// PrismEquals — Structural equality helpers
// =============================================================================

/// Structural equality comparators for use with [Prism].
///
/// When projecting collections from state, default `==` checks identity
/// rather than contents. Use these helpers for deep equality:
///
/// ```dart
/// final activeUsers = Prism(
///   users,
///   (list) => list.where((u) => u.isActive).toList(),
///   equals: PrismEquals.list,
/// );
/// ```
abstract final class PrismEquals {
  /// Compares two [List]s element-by-element using `==`.
  ///
  /// Returns `true` if both lists have the same length and all
  /// elements at corresponding indices are equal.
  ///
  /// ```dart
  /// final items = Prism(
  ///   cart,
  ///   (c) => c.items.map((i) => i.name).toList(),
  ///   equals: PrismEquals.list,
  /// );
  /// ```
  static bool list<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Compares two [Set]s by checking both contain the same elements.
  ///
  /// ```dart
  /// final tags = Prism(
  ///   post,
  ///   (p) => p.tags.toSet(),
  ///   equals: PrismEquals.set,
  /// );
  /// ```
  static bool set<T>(Set<T> a, Set<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Compares two [Map]s by checking both have the same keys and values.
  ///
  /// ```dart
  /// final scores = Prism(
  ///   game,
  ///   (g) => g.playerScores,
  ///   equals: PrismEquals.map,
  /// );
  /// ```
  static bool map<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

// =============================================================================
// Core extension — .prism() for ergonomic API
// =============================================================================

/// Extension on [TitanState] providing the [prism] method for ergonomic
/// sub-value selection.
extension PrismCoreExtension<T> on TitanState<T> {
  /// Creates a [Prism] that projects a sub-value from this Core.
  ///
  /// Only notifies when the selected value changes — enabling
  /// fine-grained reactivity for complex state objects.
  ///
  /// This is similar to [select], but returns a [Prism] instance
  /// with better semantics and structural equality support.
  ///
  /// ```dart
  /// final user = Core(User(name: 'Alice', age: 30));
  ///
  /// // Only rebuilds when name changes
  /// final userName = user.prism((u) => u.name);
  ///
  /// // With structural equality for collections
  /// final friends = user.prism(
  ///   (u) => u.friendNames.toList(),
  ///   equals: PrismEquals.list,
  /// );
  /// ```
  Prism<R> prism<R>(
    R Function(T value) selector, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    return Prism<R>(this, (v) => selector(v as T), name: name, equals: equals);
  }
}
