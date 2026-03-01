/// **Relic** — Preserves state across sessions.
///
/// A persistence & hydration layer for Titan Cores. Automatically saves
/// state to a pluggable storage backend and restores it on startup.
///
/// ## Quick Start
///
/// ```dart
/// // 1. Implement an adapter (e.g., SharedPreferences)
/// class PrefsAdapter extends RelicAdapter {
///   final SharedPreferences prefs;
///   PrefsAdapter(this.prefs);
///
///   @override
///   Future<String?> read(String key) async => prefs.getString(key);
///
///   @override
///   Future<void> write(String key, String value) async =>
///       prefs.setString(key, value);
///
///   @override
///   Future<void> delete(String key) async => prefs.remove(key);
/// }
///
/// // 2. Use in a Pillar
/// class SettingsPillar extends Pillar {
///   late final theme = core('light');
///   late final locale = core('en');
///
///   late final relic = Relic(
///     adapter: PrefsAdapter(prefs),
///     entries: {
///       'theme': RelicEntry(
///         core: theme,
///         toJson: (v) => v,
///         fromJson: (v) => v as String,
///       ),
///       'locale': RelicEntry(
///         core: locale,
///         toJson: (v) => v,
///         fromJson: (v) => v as String,
///       ),
///     },
///   );
///
///   @override
///   void onInit() async {
///     await relic.hydrate(); // Restore saved values
///   }
///
///   @override
///   void onDispose() {
///     relic.dispose();
///   }
/// }
/// ```
library;

import 'dart:convert';

import '../core/state.dart';

// ---------------------------------------------------------------------------
// Adapter — pluggable storage backend
// ---------------------------------------------------------------------------

/// A pluggable storage backend for [Relic].
///
/// Implement this to connect Titan persistence to any storage engine:
/// SharedPreferences, Hive, SQLite, secure storage, etc.
///
/// ```dart
/// class InMemoryAdapter extends RelicAdapter {
///   final _store = <String, String>{};
///
///   @override
///   Future<String?> read(String key) async => _store[key];
///
///   @override
///   Future<void> write(String key, String value) async =>
///       _store[key] = value;
///
///   @override
///   Future<void> delete(String key) async => _store.remove(key);
/// }
/// ```
abstract class RelicAdapter {
  /// Read a value from storage by [key]. Returns `null` if not found.
  Future<String?> read(String key);

  /// Write a [value] to storage under the given [key].
  Future<void> write(String key, String value);

  /// Delete the entry at [key] from storage.
  Future<void> delete(String key);
}

/// An in-memory [RelicAdapter] for testing.
///
/// ```dart
/// final adapter = InMemoryRelicAdapter();
/// final relic = Relic(adapter: adapter, entries: {...});
/// ```
class InMemoryRelicAdapter extends RelicAdapter {
  /// The in-memory store.
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> delete(String key) async => store.remove(key);
}

// ---------------------------------------------------------------------------
// RelicEntry — maps a Core to serialization functions
// ---------------------------------------------------------------------------

/// Describes how to persist and restore a single [TitanState] (Core).
///
/// - [core] — The reactive state to persist.
/// - [toJson] — Converts the Core's value to a JSON-encodable value.
/// - [fromJson] — Converts a JSON-decoded value back to the Core's type.
///
/// ```dart
/// RelicEntry<int>(
///   core: count,
///   toJson: (v) => v,       // int is natively JSON-encodable
///   fromJson: (v) => v as int,
/// )
/// ```
class RelicEntry<T> {
  /// The reactive state to persist.
  final TitanState<T> core;

  /// Converts the Core's value to a JSON-encodable object.
  final Object? Function(T value) toJson;

  /// Converts a JSON-decoded object back to the Core's type.
  final T Function(Object? json) fromJson;

  /// Creates a [RelicEntry].
  const RelicEntry({
    required this.core,
    required this.toJson,
    required this.fromJson,
  });

  /// Type-safe serialization (callable from dynamic context).
  Object? serialize() => toJson(core.peek());

  /// Type-safe deserialization + silent set (callable from dynamic context).
  void deserialize(Object? jsonValue) {
    core.silent(fromJson(jsonValue));
  }
}

// ---------------------------------------------------------------------------
// Relic — Persistence & Hydration manager
// ---------------------------------------------------------------------------

/// **Relic** — Preserves state across sessions.
///
/// Manages the persistence and hydration of multiple [TitanState] (Core)
/// values through a pluggable [RelicAdapter].
///
/// ## Features
///
/// - **Hydrate** — Restore saved values on startup with [hydrate]
/// - **Auto-save** — Optionally persist on every change with [enableAutoSave]
/// - **Manual save** — Persist current values with [persist] or [persistKey]
/// - **Clear** — Remove persisted data with [clear] or [clearKey]
///
/// ```dart
/// final relic = Relic(
///   adapter: PrefsAdapter(prefs),
///   entries: {
///     'count': RelicEntry(
///       core: count,
///       toJson: (v) => v,
///       fromJson: (v) => v as int,
///     ),
///   },
/// );
///
/// await relic.hydrate();    // Restore saved state
/// relic.enableAutoSave();   // Auto-persist on changes
/// ```
class Relic {
  /// The storage backend.
  final RelicAdapter adapter;

  /// The map of keys to their persistence entries.
  final Map<String, RelicEntry<dynamic>> _entries;

  /// Prefix for all storage keys to avoid collisions.
  final String prefix;

  final List<void Function()> _unsubscribers = [];
  bool _disposed = false;

  /// Creates a [Relic] persistence manager.
  ///
  /// - [adapter] — The storage backend to use.
  /// - [entries] — Map of storage keys to their [RelicEntry] configs.
  /// - [prefix] — Optional prefix for storage keys (default: `'titan:'`).
  Relic({
    required this.adapter,
    required Map<String, RelicEntry<dynamic>> entries,
    this.prefix = 'titan:',
  }) : _entries = Map.unmodifiable(entries);

  String _prefixedKey(String key) => '$prefix$key';

  /// The registered entry keys.
  Iterable<String> get keys => _entries.keys;

  // ---------------------------------------------------------------------------
  // Hydrate — restore from storage
  // ---------------------------------------------------------------------------

  /// Restores all registered Core values from storage.
  ///
  /// Keys not found in storage are silently skipped (Cores keep their
  /// initial values). Invalid JSON data for a key is also skipped.
  ///
  /// ```dart
  /// await relic.hydrate();
  /// ```
  Future<void> hydrate() async {
    _assertNotDisposed();

    for (final entry in _entries.entries) {
      await _hydrateKey(entry.key, entry.value);
    }
  }

  /// Restores a single Core by its key.
  ///
  /// Returns `true` if the value was successfully restored, `false` if
  /// the key was not found or the data was invalid.
  Future<bool> hydrateKey(String key) async {
    _assertNotDisposed();
    final entry = _entries[key];
    if (entry == null) return false;
    return _hydrateKey(key, entry);
  }

  Future<bool> _hydrateKey(String key, RelicEntry<dynamic> entry) async {
    try {
      final raw = await adapter.read(_prefixedKey(key));
      if (raw == null) return false;

      final jsonValue = jsonDecode(raw);
      entry.deserialize(jsonValue);
      return true;
    } catch (_) {
      // Invalid data — skip gracefully
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Persist — save to storage
  // ---------------------------------------------------------------------------

  /// Persists all registered Core values to storage.
  ///
  /// ```dart
  /// await relic.persist();
  /// ```
  Future<void> persist() async {
    _assertNotDisposed();

    for (final entry in _entries.entries) {
      await _persistKey(entry.key, entry.value);
    }
  }

  /// Persists a single Core by its key.
  ///
  /// Returns `true` if successful, `false` if the key is not registered.
  Future<bool> persistKey(String key) async {
    _assertNotDisposed();
    final entry = _entries[key];
    if (entry == null) return false;
    await _persistKey(key, entry);
    return true;
  }

  Future<void> _persistKey(String key, RelicEntry<dynamic> entry) async {
    final jsonValue = entry.serialize();
    final raw = jsonEncode(jsonValue);
    await adapter.write(_prefixedKey(key), raw);
  }

  // ---------------------------------------------------------------------------
  // Auto-save — persist on every Core change
  // ---------------------------------------------------------------------------

  /// Enables auto-saving: every Core change is immediately persisted.
  ///
  /// Call [disableAutoSave] or [dispose] to stop.
  ///
  /// ```dart
  /// relic.enableAutoSave();
  /// count.value = 42; // Automatically persisted
  /// ```
  void enableAutoSave() {
    _assertNotDisposed();

    // Avoid double-subscribing
    disableAutoSave();

    for (final entry in _entries.entries) {
      final key = entry.key;
      final relicEntry = entry.value;

      final unsub = relicEntry.core.listen((_) {
        _persistKey(key, relicEntry);
      });
      _unsubscribers.add(unsub);
    }
  }

  /// Disables auto-saving.
  void disableAutoSave() {
    for (final unsub in _unsubscribers) {
      unsub();
    }
    _unsubscribers.clear();
  }

  // ---------------------------------------------------------------------------
  // Clear — remove from storage
  // ---------------------------------------------------------------------------

  /// Removes all persisted data for registered keys.
  Future<void> clear() async {
    _assertNotDisposed();
    for (final key in _entries.keys) {
      await adapter.delete(_prefixedKey(key));
    }
  }

  /// Removes persisted data for a single key.
  Future<bool> clearKey(String key) async {
    _assertNotDisposed();
    if (!_entries.containsKey(key)) return false;
    await adapter.delete(_prefixedKey(key));
    return true;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  /// Stops auto-saving and releases resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disableAutoSave();
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'Relic has already been disposed.');
  }
}
