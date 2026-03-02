import 'state.dart';

// =============================================================================
// Nexus — Reactive Collections
// =============================================================================
//
// Observable List, Map, and Set with:
//   - In-place mutations (no copy-on-write overhead)
//   - Granular change notifications via NexusChange records
//   - Full Dart collection API surface
//   - Auto-tracking in TitanComputed / TitanEffect scopes
//   - Reactive derived properties (length, isEmpty, etc.)
//
// =============================================================================

// ---------------------------------------------------------------------------
// NexusChange — Granular change records
// ---------------------------------------------------------------------------

/// Describes a change to a [NexusList], [NexusMap], or [NexusSet].
///
/// Use [NexusList.lastChange], [NexusMap.lastChange], or [NexusSet.lastChange]
/// to inspect the most recent change after a notification.
///
/// ```dart
/// final items = NexusList<String>(['a', 'b']);
/// items.addListener(() {
///   switch (items.lastChange) {
///     case NexusInsert(:final index, :final element):
///       print('Inserted $element at $index');
///     case NexusRemove(:final index, :final element):
///       print('Removed $element from $index');
///     case NexusClear():
///       print('Cleared!');
///     default:
///       print('Other change');
///   }
/// });
/// ```
sealed class NexusChange<T> {
  const NexusChange();
}

/// An element was inserted into a list.
final class NexusInsert<T> extends NexusChange<T> {
  /// The index where the element was inserted.
  final int index;

  /// The element that was inserted.
  final T element;

  const NexusInsert(this.index, this.element);

  @override
  String toString() => 'NexusInsert(index: $index, element: $element)';
}

/// An element was removed from a list.
final class NexusRemove<T> extends NexusChange<T> {
  /// The index from which the element was removed.
  final int index;

  /// The element that was removed.
  final T element;

  const NexusRemove(this.index, this.element);

  @override
  String toString() => 'NexusRemove(index: $index, element: $element)';
}

/// An element was updated in a list at a specific index.
final class NexusUpdate<T> extends NexusChange<T> {
  /// The index of the updated element.
  final int index;

  /// The previous value at this index.
  final T oldValue;

  /// The new value at this index.
  final T newValue;

  const NexusUpdate(this.index, this.oldValue, this.newValue);

  @override
  String toString() =>
      'NexusUpdate(index: $index, old: $oldValue, new: $newValue)';
}

/// The collection was cleared.
final class NexusClear<T> extends NexusChange<T> {
  /// The number of elements before clearing.
  final int previousLength;

  const NexusClear(this.previousLength);

  @override
  String toString() => 'NexusClear(previousLength: $previousLength)';
}

/// A key-value pair was set in a map.
final class NexusMapSet<K, V> extends NexusChange<MapEntry<K, V>> {
  /// The key that was set.
  final K key;

  /// The previous value (null if new key).
  final V? oldValue;

  /// The new value.
  final V newValue;

  /// Whether this was a new key (vs. update).
  final bool isNew;

  const NexusMapSet(
    this.key,
    this.oldValue,
    this.newValue, {
    this.isNew = true,
  });

  @override
  String toString() =>
      'NexusMapSet(key: $key, old: $oldValue, new: $newValue, isNew: $isNew)';
}

/// A key-value pair was removed from a map.
final class NexusMapRemove<K, V> extends NexusChange<MapEntry<K, V>> {
  /// The key that was removed.
  final K key;

  /// The value that was removed.
  final V value;

  const NexusMapRemove(this.key, this.value);

  @override
  String toString() => 'NexusMapRemove(key: $key, value: $value)';
}

/// An element was added to a set.
final class NexusSetAdd<T> extends NexusChange<T> {
  /// The element that was added.
  final T element;

  const NexusSetAdd(this.element);

  @override
  String toString() => 'NexusSetAdd($element)';
}

/// An element was removed from a set.
final class NexusSetRemove<T> extends NexusChange<T> {
  /// The element that was removed.
  final T element;

  const NexusSetRemove(this.element);

  @override
  String toString() => 'NexusSetRemove($element)';
}

/// Multiple changes occurred (e.g., addAll, removeWhere).
final class NexusBatch<T> extends NexusChange<T> {
  /// A description of the batch operation.
  final String operation;

  /// How many elements were affected.
  final int count;

  const NexusBatch(this.operation, this.count);

  @override
  String toString() => 'NexusBatch($operation, count: $count)';
}

// ---------------------------------------------------------------------------
// NexusList<T> — Reactive observable list
// ---------------------------------------------------------------------------

/// **NexusList** — A reactive, observable list with granular change tracking.
///
/// Unlike `Core<List<T>>` which creates a full copy on every mutation,
/// `NexusList` mutates in-place and only notifies dependents of the
/// precise change that occurred.
///
/// ## Usage
///
/// ```dart
/// final items = NexusList<String>(['sword', 'shield']);
///
/// items.add('potion');          // NexusInsert(2, 'potion')
/// items.removeAt(0);           // NexusRemove(0, 'sword')
/// items[0] = 'magic shield';   // NexusUpdate(0, 'shield', 'magic shield')
/// items.clear();               // NexusClear(2)
/// ```
///
/// ## In a Pillar
///
/// ```dart
/// class InventoryPillar extends Pillar {
///   late final items = nexusList<String>(['sword', 'shield']);
///   late final itemCount = derived(() => items.length);
/// }
/// ```
///
/// ## Change Tracking
///
/// ```dart
/// items.addListener(() {
///   final change = items.lastChange;
///   if (change is NexusInsert<String>) {
///     print('Added ${change.element} at ${change.index}');
///   }
/// });
/// ```
class NexusList<T> extends TitanState<List<T>> {
  NexusChange<T>? _lastChange;

  /// Creates a reactive list with optional initial elements.
  ///
  /// The provided list is copied — subsequent changes to the original
  /// list will not affect this NexusList.
  ///
  /// ```dart
  /// final items = NexusList<String>(['a', 'b', 'c']);
  /// ```
  NexusList({List<T>? initial, String? name})
    : super(List<T>.of(initial ?? []), name: name);

  /// The most recent change record, or `null` if no changes have occurred.
  ///
  /// Available during listener callbacks to inspect what changed.
  NexusChange<T>? get lastChange => _lastChange;

  // -- Read operations (auto-tracked) --

  /// The current number of elements.
  ///
  /// Auto-tracked in reactive scopes.
  int get length {
    track();
    return peek().length;
  }

  /// Whether the list has no elements.
  bool get isEmpty {
    track();
    return peek().isEmpty;
  }

  /// Whether the list has at least one element.
  bool get isNotEmpty {
    track();
    return peek().isNotEmpty;
  }

  /// The first element.
  ///
  /// Throws [StateError] if the list is empty.
  T get first {
    track();
    return peek().first;
  }

  /// The last element.
  ///
  /// Throws [StateError] if the list is empty.
  T get last {
    track();
    return peek().last;
  }

  /// Returns the element at the given [index].
  ///
  /// Auto-tracked in reactive scopes.
  T operator [](int index) {
    track();
    return peek()[index];
  }

  /// Returns `true` if the list contains [element].
  bool contains(T element) {
    track();
    return peek().contains(element);
  }

  /// Returns the index of [element], or -1 if not found.
  int indexOf(T element) {
    track();
    return peek().indexOf(element);
  }

  /// Returns an iterable of the elements (auto-tracked).
  Iterable<T> get items {
    track();
    return peek();
  }

  // -- Write operations (mutate in-place, notify) --

  /// Adds [element] to the end of the list.
  ///
  /// ```dart
  /// items.add('potion'); // NexusInsert(length, 'potion')
  /// ```
  void add(T element) {
    final list = peek();
    list.add(element);
    _lastChange = NexusInsert(list.length - 1, element);
    notifyDependents();
  }

  /// Adds all [elements] to the end of the list.
  void addAll(Iterable<T> elements) {
    final list = peek();
    final added = elements.toList();
    if (added.isEmpty) return;
    list.addAll(added);
    _lastChange = NexusBatch('addAll', added.length);
    notifyDependents();
  }

  /// Inserts [element] at the given [index].
  ///
  /// ```dart
  /// items.insert(0, 'helmet'); // NexusInsert(0, 'helmet')
  /// ```
  void insert(int index, T element) {
    peek().insert(index, element);
    _lastChange = NexusInsert(index, element);
    notifyDependents();
  }

  /// Sets the element at [index] to [value].
  ///
  /// ```dart
  /// items[0] = 'enchanted sword'; // NexusUpdate(0, old, new)
  /// ```
  void operator []=(int index, T value) {
    final list = peek();
    final old = list[index];
    if (old == value) return;
    list[index] = value;
    _lastChange = NexusUpdate(index, old, value);
    notifyDependents();
  }

  /// Removes the first occurrence of [element].
  ///
  /// Returns `true` if the element was found and removed.
  bool remove(T element) {
    final list = peek();
    final index = list.indexOf(element);
    if (index == -1) return false;
    list.removeAt(index);
    _lastChange = NexusRemove(index, element);
    notifyDependents();
    return true;
  }

  /// Removes the element at [index] and returns it.
  T removeAt(int index) {
    final list = peek();
    final element = list.removeAt(index);
    _lastChange = NexusRemove(index, element);
    notifyDependents();
    return element;
  }

  /// Removes all elements matching [test].
  ///
  /// Returns the number of elements removed.
  int removeWhere(bool Function(T element) test) {
    final list = peek();
    final before = list.length;
    list.removeWhere(test);
    final removed = before - list.length;
    if (removed > 0) {
      _lastChange = NexusBatch('removeWhere', removed);
      notifyDependents();
    }
    return removed;
  }

  /// Retains only elements matching [test].
  ///
  /// Returns the number of elements removed.
  int retainWhere(bool Function(T element) test) {
    final list = peek();
    final before = list.length;
    list.retainWhere(test);
    final removed = before - list.length;
    if (removed > 0) {
      _lastChange = NexusBatch('retainWhere', removed);
      notifyDependents();
    }
    return removed;
  }

  /// Sorts the list in-place using the optional [compare] function.
  void sort([int Function(T a, T b)? compare]) {
    final list = peek();
    if (list.length <= 1) return;
    list.sort(compare);
    _lastChange = NexusBatch('sort', list.length);
    notifyDependents();
  }

  /// Replaces elements in the range [start]–[end] with [replacements].
  void replaceRange(int start, int end, Iterable<T> replacements) {
    peek().replaceRange(start, end, replacements);
    _lastChange = NexusBatch('replaceRange', end - start);
    notifyDependents();
  }

  /// Removes all elements from the list.
  void clear() {
    final list = peek();
    if (list.isEmpty) return;
    final prevLen = list.length;
    list.clear();
    _lastChange = NexusClear(prevLen);
    notifyDependents();
  }

  /// Swaps elements at indices [a] and [b].
  void swap(int a, int b) {
    final list = peek();
    final temp = list[a];
    list[a] = list[b];
    list[b] = temp;
    _lastChange = NexusBatch('swap', 2);
    notifyDependents();
  }

  /// Moves the element at [from] to [to].
  void move(int from, int to) {
    final list = peek();
    final element = list.removeAt(from);
    list.insert(to, element);
    _lastChange = NexusBatch('move', 1);
    notifyDependents();
  }

  @override
  String toString() {
    final label = name != null ? '($name)' : '';
    return 'NexusList$label<$T>[${peek().length}]';
  }
}

// ---------------------------------------------------------------------------
// NexusMap<K, V> — Reactive observable map
// ---------------------------------------------------------------------------

/// **NexusMap** — A reactive, observable map with granular change tracking.
///
/// Mutates in-place and provides precise [NexusChange] records describing
/// what key-value pairs were added, updated, or removed.
///
/// ## Usage
///
/// ```dart
/// final scores = NexusMap<String, int>({'Alice': 10});
///
/// scores['Bob'] = 20;           // NexusMapSet('Bob', null, 20, isNew: true)
/// scores['Alice'] = 15;         // NexusMapSet('Alice', 10, 15, isNew: false)
/// scores.remove('Bob');         // NexusMapRemove('Bob', 20)
/// ```
///
/// ## In a Pillar
///
/// ```dart
/// class ScorePillar extends Pillar {
///   late final scores = nexusMap<String, int>({});
///   late final topPlayer = derived(
///     () => scores.isEmpty ? 'None' : scores.entries.reduce(
///       (a, b) => a.value > b.value ? a : b,
///     ).key,
///   );
/// }
/// ```
class NexusMap<K, V> extends TitanState<Map<K, V>> {
  NexusChange<MapEntry<K, V>>? _lastChange;

  /// Creates a reactive map with optional initial entries.
  ///
  /// The provided map is copied — subsequent changes to the original
  /// map will not affect this NexusMap.
  ///
  /// ```dart
  /// final scores = NexusMap<String, int>({'Alice': 10, 'Bob': 20});
  /// ```
  NexusMap({Map<K, V>? initial, String? name})
    : super(Map<K, V>.of(initial ?? {}), name: name);

  /// The most recent change record.
  NexusChange<MapEntry<K, V>>? get lastChange => _lastChange;

  // -- Read operations (auto-tracked) --

  /// The number of key-value pairs.
  int get length {
    track();
    return peek().length;
  }

  /// Whether the map is empty.
  bool get isEmpty {
    track();
    return peek().isEmpty;
  }

  /// Whether the map has at least one entry.
  bool get isNotEmpty {
    track();
    return peek().isNotEmpty;
  }

  /// Returns the keys (auto-tracked).
  Iterable<K> get keys {
    track();
    return peek().keys;
  }

  /// Returns the values (auto-tracked).
  Iterable<V> get values {
    track();
    return peek().values;
  }

  /// Returns the entries (auto-tracked).
  Iterable<MapEntry<K, V>> get entries {
    track();
    return peek().entries;
  }

  /// Returns the value for [key], or `null` if absent.
  V? operator [](K key) {
    track();
    return peek()[key];
  }

  /// Whether the map contains [key].
  bool containsKey(K key) {
    track();
    return peek().containsKey(key);
  }

  /// Whether the map contains [value].
  bool containsValue(V value) {
    track();
    return peek().containsValue(value);
  }

  // -- Write operations --

  /// Sets the [key] to [value].
  ///
  /// Notifies even if the key already existed with the same value —
  /// use [putIfChanged] if you want to skip on equal values.
  void operator []=(K key, V value) {
    final map = peek();
    final isNew = !map.containsKey(key);
    final old = map[key];
    map[key] = value;
    _lastChange = NexusMapSet(key, old, value, isNew: isNew);
    notifyDependents();
  }

  /// Sets [key] to [value] only if the value actually changed.
  ///
  /// Returns `true` if the value was set (i.e., it changed).
  bool putIfChanged(K key, V value) {
    final map = peek();
    if (map.containsKey(key) && map[key] == value) return false;
    final isNew = !map.containsKey(key);
    final old = map[key];
    map[key] = value;
    _lastChange = NexusMapSet(key, old, value, isNew: isNew);
    notifyDependents();
    return true;
  }

  /// Sets [key] to [value] if the key is not already present.
  ///
  /// Returns the existing value if present, or [value] if inserted.
  V putIfAbsent(K key, V Function() ifAbsent) {
    final map = peek();
    if (map.containsKey(key)) return map[key] as V;
    final value = ifAbsent();
    map[key] = value;
    _lastChange = NexusMapSet(key, null, value);
    notifyDependents();
    return value;
  }

  /// Adds all entries from [other].
  void addAll(Map<K, V> other) {
    if (other.isEmpty) return;
    peek().addAll(other);
    _lastChange = NexusBatch('addAll', other.length);
    notifyDependents();
  }

  /// Removes the entry for [key].
  ///
  /// Returns the removed value, or `null` if the key was not found.
  V? remove(K key) {
    final map = peek();
    if (!map.containsKey(key)) return null;
    final value = map.remove(key);
    _lastChange = NexusMapRemove(key, value as V);
    notifyDependents();
    return value;
  }

  /// Removes all entries where [test] returns `true`.
  ///
  /// Returns the number of entries removed.
  int removeWhere(bool Function(K key, V value) test) {
    final map = peek();
    final before = map.length;
    map.removeWhere(test);
    final removed = before - map.length;
    if (removed > 0) {
      _lastChange = NexusBatch('removeWhere', removed);
      notifyDependents();
    }
    return removed;
  }

  /// Updates all values using [update].
  void updateAll(V Function(K key, V value) update) {
    final map = peek();
    if (map.isEmpty) return;
    map.updateAll(update);
    _lastChange = NexusBatch('updateAll', map.length);
    notifyDependents();
  }

  /// Removes all entries.
  void clear() {
    final map = peek();
    if (map.isEmpty) return;
    final prevLen = map.length;
    map.clear();
    _lastChange = NexusClear(prevLen);
    notifyDependents();
  }

  @override
  String toString() {
    final label = name != null ? '($name)' : '';
    return 'NexusMap$label<$K, $V>{${peek().length}}';
  }
}

// ---------------------------------------------------------------------------
// NexusSet<T> — Reactive observable set
// ---------------------------------------------------------------------------

/// **NexusSet** — A reactive, observable set with granular change tracking.
///
/// Mutates in-place and provides precise [NexusChange] records describing
/// what elements were added or removed.
///
/// ## Usage
///
/// ```dart
/// final tags = NexusSet<String>({'combat', 'stealth'});
///
/// tags.add('magic');      // NexusSetAdd('magic')
/// tags.remove('stealth'); // NexusSetRemove('stealth')
/// tags.toggle('combat');  // NexusSetRemove('combat') — removes if present
/// tags.toggle('archery'); // NexusSetAdd('archery') — adds if absent
/// ```
///
/// ## In a Pillar
///
/// ```dart
/// class TagPillar extends Pillar {
///   late final tags = nexusSet<String>({'dart', 'flutter'});
///   late final tagCount = derived(() => tags.length);
/// }
/// ```
class NexusSet<T> extends TitanState<Set<T>> {
  NexusChange<T>? _lastChange;

  /// Creates a reactive set with optional initial elements.
  ///
  /// ```dart
  /// final tags = NexusSet<String>({'a', 'b', 'c'});
  /// ```
  NexusSet({Set<T>? initial, String? name})
    : super(Set<T>.of(initial ?? {}), name: name);

  /// The most recent change record.
  NexusChange<T>? get lastChange => _lastChange;

  // -- Read operations (auto-tracked) --

  /// The number of elements.
  int get length {
    track();
    return peek().length;
  }

  /// Whether the set is empty.
  bool get isEmpty {
    track();
    return peek().isEmpty;
  }

  /// Whether the set has at least one element.
  bool get isNotEmpty {
    track();
    return peek().isNotEmpty;
  }

  /// Whether the set contains [element].
  bool contains(T element) {
    track();
    return peek().contains(element);
  }

  /// Returns the elements (auto-tracked).
  Iterable<T> get elements {
    track();
    return peek();
  }

  // -- Write operations --

  /// Adds [element] to the set.
  ///
  /// Returns `true` if the element was added (i.e., not already present).
  bool add(T element) {
    final set = peek();
    if (!set.add(element)) return false;
    _lastChange = NexusSetAdd(element);
    notifyDependents();
    return true;
  }

  /// Adds all [elements] to the set.
  void addAll(Iterable<T> elements) {
    final set = peek();
    final before = set.length;
    set.addAll(elements);
    final added = set.length - before;
    if (added > 0) {
      _lastChange = NexusBatch('addAll', added);
      notifyDependents();
    }
  }

  /// Removes [element] from the set.
  ///
  /// Returns `true` if the element was found and removed.
  bool remove(T element) {
    if (!peek().remove(element)) return false;
    _lastChange = NexusSetRemove(element);
    notifyDependents();
    return true;
  }

  /// Toggles [element]: adds if absent, removes if present.
  ///
  /// Returns `true` if the element is now in the set.
  ///
  /// ```dart
  /// tags.toggle('combat'); // removes it
  /// tags.toggle('combat'); // adds it back
  /// ```
  bool toggle(T element) {
    final set = peek();
    if (set.contains(element)) {
      set.remove(element);
      _lastChange = NexusSetRemove(element);
      notifyDependents();
      return false;
    } else {
      set.add(element);
      _lastChange = NexusSetAdd(element);
      notifyDependents();
      return true;
    }
  }

  /// Removes all elements matching [test].
  ///
  /// Returns the number of elements removed.
  int removeWhere(bool Function(T element) test) {
    final set = peek();
    final before = set.length;
    set.removeWhere(test);
    final removed = before - set.length;
    if (removed > 0) {
      _lastChange = NexusBatch('removeWhere', removed);
      notifyDependents();
    }
    return removed;
  }

  /// Retains only elements matching [test].
  ///
  /// Returns the number of elements removed.
  int retainWhere(bool Function(T element) test) {
    final set = peek();
    final before = set.length;
    set.retainWhere(test);
    final removed = before - set.length;
    if (removed > 0) {
      _lastChange = NexusBatch('retainWhere', removed);
      notifyDependents();
    }
    return removed;
  }

  /// Removes all elements from the set.
  void clear() {
    final set = peek();
    if (set.isEmpty) return;
    final prevLen = set.length;
    set.clear();
    _lastChange = NexusClear(prevLen);
    notifyDependents();
  }

  /// Returns the intersection with [other].
  ///
  /// Does not modify this set — returns a new `Set<T>`.
  Set<T> intersection(Set<T> other) {
    track();
    return peek().intersection(other);
  }

  /// Returns the union with [other].
  ///
  /// Does not modify this set — returns a new `Set<T>`.
  Set<T> union(Set<T> other) {
    track();
    return peek().union(other);
  }

  /// Returns the difference (this - other).
  ///
  /// Does not modify this set — returns a new `Set<T>`.
  Set<T> difference(Set<T> other) {
    track();
    return peek().difference(other);
  }

  @override
  String toString() {
    final label = name != null ? '($name)' : '';
    return 'NexusSet$label<$T>{${peek().length}}';
  }
}
