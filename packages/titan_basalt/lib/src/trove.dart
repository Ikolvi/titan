/// Trove — Reactive in-memory cache with TTL expiry and LRU eviction.
///
/// A Trove manages a typed key-value cache with configurable entry
/// lifetime (TTL, time-to-live) and optional capacity limits (LRU
/// eviction). All cache statistics are reactive [Core] nodes, making
/// hit rates, size, and eviction counts automatically available to
/// the UI and watchers.
///
/// ## Why "Trove"?
///
/// A trove is a store of precious things. Titan's Trove stores your
/// most valuable data — API responses, computed results, session objects —
/// and guards them with time-based expiry and intelligent eviction.
///
/// ## Usage
///
/// ```dart
/// class CatalogPillar extends Pillar {
///   late final productCache = trove<String, Product>(
///     defaultTtl: Duration(minutes: 10),
///     maxEntries: 200,
///     onEvict: (key, value) => log.debug('Evicted product: $key'),
///   );
///
///   Future<Product> getProduct(String id) async {
///     final cached = productCache.get(id);
///     if (cached != null) return cached;
///
///     final product = await api.fetchProduct(id);
///     productCache.put(id, product);
///     return product;
///   }
/// }
/// ```
///
/// ## Features
///
/// - **TTL expiry** — entries expire after a configurable duration
/// - **LRU eviction** — oldest-accessed entries evicted when capacity reached
/// - **Reactive stats** — `size`, `hits`, `misses` are live Cores
/// - **Per-entry TTL** — override the default TTL for individual entries
/// - **Batch operations** — `putAll()`, `getAll()` for efficiency
/// - **Cache inspection** — `containsKey()`, `remainingTtl()`, `isExpired()`
/// - **Pillar integration** — `trove()` factory method with auto-disposal
///
/// ## Get-or-Put Pattern
///
/// ```dart
/// // Fetch from cache, or compute and store
/// final user = userCache.getOrPut('user-42', () async {
///   return await api.fetchUser('42');
/// });
/// ```
///
/// ## Reactive Cache Stats
///
/// ```dart
/// // In a Vestige builder:
/// Text('Cache: ${cache.size.value} entries, '
///      '${cache.hitRate.toStringAsFixed(1)}% hit rate')
/// ```
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// Node in the doubly-linked list for O(1) LRU operations.
class _LruNode<K, V> {
  final K key;
  final V value;
  final DateTime createdAt;
  final DateTime? expiresAt;
  _LruNode<K, V>? prev;
  _LruNode<K, V>? next;

  _LruNode({
    required this.key,
    required this.value,
    required this.createdAt,
    this.expiresAt,
  });

  /// Whether this entry has expired.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Remaining time before expiry, or `null` if no TTL.
  Duration? get remainingTtl {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Eviction reason for the [Trove.onEvict] callback.
enum TroveEvictionReason {
  /// Entry was explicitly removed via [Trove.evict] or [Trove.clear].
  manual,

  /// Entry expired based on its TTL.
  expired,

  /// Entry was evicted to make room for new entries (LRU).
  capacity,
}

/// A reactive in-memory cache with TTL expiry and LRU eviction.
///
/// Each `Trove<K, V>` is a typed key-value cache where entries can
/// expire after a configurable time-to-live (TTL). When the cache
/// reaches its maximum capacity, the least-recently-used (LRU) entry
/// is evicted to make room.
///
/// ## Reactive State
///
/// The following properties are reactive [Core]s that trigger
/// rebuilds when accessed inside [Vestige] or [Derived]:
///
/// - [size] — current number of entries
/// - [hits] — total cache hits
/// - [misses] — total cache misses
///
/// ```dart
/// final cache = Trove<String, User>(
///   defaultTtl: Duration(minutes: 5),
///   maxEntries: 100,
/// );
///
/// cache.put('user-1', user);
/// final user = cache.get('user-1'); // hit!
/// print('Hit rate: ${cache.hitRate}%');
/// ```
class Trove<K, V> {
  /// HashMap for O(1) key lookups.
  final Map<K, _LruNode<K, V>> _store = {};

  /// Doubly-linked list head (most recently used).
  _LruNode<K, V>? _head;

  /// Doubly-linked list tail (least recently used).
  _LruNode<K, V>? _tail;

  /// Default time-to-live for entries. `null` means entries never expire.
  final Duration? defaultTtl;

  /// Maximum number of entries. `null` means unlimited.
  final int? maxEntries;

  /// Called when an entry is evicted (for any reason).
  final void Function(K key, V value, TroveEvictionReason reason)? onEvict;

  /// Periodic cleanup timer for expired entries.
  Timer? _cleanupTimer;

  /// How often to scan for expired entries.
  final Duration cleanupInterval;

  // ---------------------------------------------------------------------------
  // Reactive state — accessible as Cores for UI/watcher integration
  // ---------------------------------------------------------------------------

  /// Reactive entry count.
  final TitanState<int> _size;

  /// Reactive cache hit counter.
  final TitanState<int> _hits;

  /// Reactive cache miss counter.
  final TitanState<int> _misses;

  /// Reactive eviction counter.
  final TitanState<int> _evictions;

  /// Creates a Trove cache.
  ///
  /// - [defaultTtl] — Default time-to-live for entries (null = no expiry).
  /// - [maxEntries] — Maximum cache capacity (null = unlimited).
  /// - [onEvict] — Called when an entry is removed for any reason.
  /// - [cleanupInterval] — How often expired entries are purged (default: 60s).
  /// - [name] — Debug name prefix for internal Cores.
  ///
  /// ```dart
  /// final cache = Trove<String, Product>(
  ///   defaultTtl: Duration(minutes: 10),
  ///   maxEntries: 200,
  ///   name: 'products',
  /// );
  /// ```
  Trove({
    this.defaultTtl,
    this.maxEntries,
    this.onEvict,
    this.cleanupInterval = const Duration(seconds: 60),
    String? name,
  }) : _size = TitanState<int>(0, name: '${name ?? 'trove'}_size'),
       _hits = TitanState<int>(0, name: '${name ?? 'trove'}_hits'),
       _misses = TitanState<int>(0, name: '${name ?? 'trove'}_misses'),
       _evictions = TitanState<int>(0, name: '${name ?? 'trove'}_evictions') {
    if (maxEntries != null && maxEntries! <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'must be positive');
    }
    if (defaultTtl != null) {
      _cleanupTimer = Timer.periodic(cleanupInterval, (_) => _purgeExpired());
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive getters
  // ---------------------------------------------------------------------------

  /// Reactive entry count (read `.value` for the current count).
  TitanState<int> get size => _size;

  /// Reactive cache hit count.
  TitanState<int> get hits => _hits;

  /// Reactive cache miss count.
  TitanState<int> get misses => _misses;

  /// Reactive eviction count.
  TitanState<int> get evictions => _evictions;

  /// Cache hit rate as a percentage (0.0–100.0).
  ///
  /// Returns 0.0 if no lookups have been performed.
  double get hitRate {
    final total = _hits.value + _misses.value;
    if (total == 0) return 0.0;
    return (_hits.value / total) * 100.0;
  }

  /// Cache miss rate as a percentage (0.0–100.0).
  double get missRate {
    final total = _hits.value + _misses.value;
    if (total == 0) return 0.0;
    return (_misses.value / total) * 100.0;
  }

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [
    _size,
    _hits,
    _misses,
    _evictions,
  ];

  // ---------------------------------------------------------------------------
  // Core operations
  // ---------------------------------------------------------------------------

  /// Retrieve a cached value by key.
  ///
  /// Returns `null` if the key is not found or the entry has expired.
  /// Expired entries are lazily evicted on access.
  ///
  /// ```dart
  /// final user = cache.get('user-42');
  /// if (user != null) {
  ///   // cache hit
  /// }
  /// ```
  V? get(K key) {
    final node = _store[key];
    if (node == null) {
      _misses.value++;
      return null;
    }
    if (node.isExpired) {
      _removeNode(node, TroveEvictionReason.expired);
      _misses.value++;
      return null;
    }
    // Move to head (most recently used)
    _moveToHead(node);
    _hits.value++;
    return node.value;
  }

  /// Store a value in the cache.
  ///
  /// - [ttl] — Override the default TTL for this entry (null uses [defaultTtl]).
  ///
  /// If [maxEntries] is set and the cache is full, the least-recently-used
  /// entry is evicted to make room.
  ///
  /// ```dart
  /// cache.put('user-42', user);
  /// cache.put('session', token, ttl: Duration(hours: 1));
  /// ```
  void put(K key, V value, {Duration? ttl}) {
    // If key already exists, remove old node first
    final existing = _store[key];
    if (existing != null) {
      _unlinkNode(existing);
    } else {
      // Evict LRU if at capacity
      _evictIfNeeded();
    }

    final effectiveTtl = ttl ?? defaultTtl;
    final now = DateTime.now();
    final node = _LruNode<K, V>(
      key: key,
      value: value,
      createdAt: now,
      expiresAt: effectiveTtl != null ? now.add(effectiveTtl) : null,
    );
    _store[key] = node;
    _addToHead(node);
    _size.value = _store.length;
  }

  /// Retrieve a cached value, or compute and store it if absent.
  ///
  /// This provides an atomic get-or-set pattern. If the key exists
  /// and has not expired, the cached value is returned immediately.
  /// Otherwise, [ifAbsent] is called to produce the value, which is
  /// then stored in the cache before being returned.
  ///
  /// ```dart
  /// final user = cache.putIfAbsent('user-42', () => User(name: 'Kael'));
  /// ```
  V putIfAbsent(K key, V Function() ifAbsent, {Duration? ttl}) {
    final existing = get(key);
    if (existing != null) return existing;

    final value = ifAbsent();
    put(key, value, ttl: ttl);
    return value;
  }

  /// Async version of [putIfAbsent] for async value computation.
  ///
  /// ```dart
  /// final product = await cache.getOrPut('product-1', () async {
  ///   return await api.fetchProduct('1');
  /// });
  /// ```
  Future<V> getOrPut(
    K key,
    Future<V> Function() ifAbsent, {
    Duration? ttl,
  }) async {
    final existing = get(key);
    if (existing != null) return existing;

    final value = await ifAbsent();
    put(key, value, ttl: ttl);
    return value;
  }

  /// Store multiple entries at once.
  ///
  /// ```dart
  /// cache.putAll({'a': valueA, 'b': valueB}, ttl: Duration(minutes: 5));
  /// ```
  void putAll(Map<K, V> entries, {Duration? ttl}) {
    for (final entry in entries.entries) {
      put(entry.key, entry.value, ttl: ttl);
    }
  }

  /// Retrieve multiple values at once.
  ///
  /// Returns a map of found keys to their values. Missing or expired
  /// entries are omitted from the result.
  ///
  /// ```dart
  /// final results = cache.getAll(['a', 'b', 'c']);
  /// // results may contain 0–3 entries
  /// ```
  Map<K, V> getAll(Iterable<K> keys) {
    final result = <K, V>{};
    for (final key in keys) {
      final value = get(key);
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  /// Remove a specific entry from the cache.
  ///
  /// Returns the evicted value, or `null` if the key was not found.
  ///
  /// ```dart
  /// final removed = cache.evict('user-42');
  /// ```
  V? evict(K key) {
    final node = _store[key];
    if (node == null) return null;
    _removeNode(node, TroveEvictionReason.manual);
    return node.value;
  }

  /// Remove all entries from the cache and reset statistics.
  ///
  /// ```dart
  /// cache.clear();
  /// ```
  void clear() {
    // Walk the linked list and fire callbacks
    var node = _head;
    while (node != null) {
      final next = node.next;
      onEvict?.call(node.key, node.value, TroveEvictionReason.manual);
      _evictions.value++;
      node = next;
    }
    _store.clear();
    _head = null;
    _tail = null;
    _size.value = 0;
  }

  /// Remove all entries without triggering eviction callbacks. Resets stats.
  void reset() {
    _store.clear();
    _head = null;
    _tail = null;
    _size.value = 0;
    _hits.value = 0;
    _misses.value = 0;
    _evictions.value = 0;
  }

  // ---------------------------------------------------------------------------
  // Inspection
  // ---------------------------------------------------------------------------

  /// Whether the cache contains a non-expired entry for [key].
  ///
  /// ```dart
  /// if (cache.containsKey('session')) {
  ///   // still valid
  /// }
  /// ```
  bool containsKey(K key) {
    final node = _store[key];
    if (node == null) return false;
    if (node.isExpired) {
      _removeNode(node, TroveEvictionReason.expired);
      return false;
    }
    return true;
  }

  /// Whether a cached entry has expired (returns `false` if key not found).
  bool isExpired(K key) {
    final node = _store[key];
    if (node == null) return false;
    return node.isExpired;
  }

  /// Remaining TTL for a cached entry.
  ///
  /// Returns `null` if the key is not found or has no TTL.
  Duration? remainingTtl(K key) {
    final node = _store[key];
    if (node == null) return null;
    return node.remainingTtl;
  }

  /// All non-expired keys currently in the cache.
  List<K> get keys {
    _purgeExpired();
    return _store.keys.toList();
  }

  /// Whether the cache is empty.
  bool get isEmpty => _store.isEmpty;

  /// Whether the cache has entries.
  bool get isNotEmpty => _store.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Dispose the cache, cancelling the cleanup timer.
  ///
  /// After disposal, the cache should not be used.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _store.clear();
    _head = null;
    _tail = null;
    _size.dispose();
    _hits.dispose();
    _misses.dispose();
    _evictions.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internals — O(1) doubly-linked list operations
  // ---------------------------------------------------------------------------

  /// Add a node to the head of the LRU list (most recently used).
  void _addToHead(_LruNode<K, V> node) {
    node.prev = null;
    node.next = _head;
    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;
    _tail ??= node;
  }

  /// Unlink a node from the doubly-linked list (does NOT remove from map).
  void _unlinkNode(_LruNode<K, V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      _head = node.next;
    }
    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      _tail = node.prev;
    }
    node.prev = null;
    node.next = null;
  }

  /// Move an existing node to the head (most recently used).
  void _moveToHead(_LruNode<K, V> node) {
    if (node == _head) return; // already at head
    _unlinkNode(node);
    _addToHead(node);
  }

  /// Remove a node fully (from map + list) and fire the eviction callback.
  void _removeNode(_LruNode<K, V> node, TroveEvictionReason reason) {
    _store.remove(node.key);
    _unlinkNode(node);
    _size.value = _store.length;
    _evictions.value++;
    onEvict?.call(node.key, node.value, reason);
  }

  /// Evict the tail (least recently used) entry if at capacity.
  void _evictIfNeeded() {
    if (maxEntries == null || _store.length < maxEntries!) return;
    if (_tail != null) {
      _removeNode(_tail!, TroveEvictionReason.capacity);
    }
  }

  /// Purge all expired entries.
  void _purgeExpired() {
    final expired = <_LruNode<K, V>>[];
    for (final node in _store.values) {
      if (node.isExpired) expired.add(node);
    }
    for (final node in expired) {
      _removeNode(node, TroveEvictionReason.expired);
    }
  }

  @override
  String toString() =>
      'Trove<$K, $V>(size: ${_size.value}, '
      'hits: ${_hits.value}, misses: ${_misses.value}, '
      'hitRate: ${hitRate.toStringAsFixed(1)}%)';
}
