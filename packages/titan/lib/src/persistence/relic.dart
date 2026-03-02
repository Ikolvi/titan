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

import 'dart:async';
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

  /// Current schema version. Used for migration support.
  final int version;

  /// Migration functions keyed by the version they migrate FROM.
  ///
  /// Each function receives the raw JSON map and should return
  /// a transformed map compatible with the next version.
  final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
      _migrations;

  final List<void Function()> _unsubscribers = [];
  final Map<String, Timer> _debounceTimers = {};
  bool _disposed = false;

  /// Creates a [Relic] persistence manager.
  ///
  /// - [adapter] — The storage backend to use.
  /// - [entries] — Map of storage keys to their [RelicEntry] configs.
  /// - [prefix] — Optional prefix for storage keys (default: `'titan:'`).
  /// - [version] — Current schema version (default: `1`).
  /// - [migrations] — Map of version → migration function. Each function
  ///   receives the stored data as a `Map<String, Object?>` and returns
  ///   the transformed data for the next version.
  ///
  /// ## Migration Example
  ///
  /// ```dart
  /// final relic = Relic(
  ///   adapter: adapter,
  ///   version: 3,
  ///   migrations: {
  ///     1: (data) => data..['newField'] = 'default',
  ///     2: (data) {
  ///       data['renamed'] = data.remove('oldName');
  ///       return data;
  ///     },
  ///   },
  ///   entries: { ... },
  /// );
  /// ```
  Relic({
    required this.adapter,
    required Map<String, RelicEntry<dynamic>> entries,
    this.prefix = 'titan:',
    this.version = 1,
    Map<int, Map<String, Object?> Function(Map<String, Object?>)>? migrations,
  }) : _entries = Map.unmodifiable(entries),
       _migrations = migrations ?? const {};

  String _prefixedKey(String key) => '$prefix$key';

  /// The storage key for the schema version.
  String get _versionKey => '${prefix}_relic_version';

  /// The registered entry keys.
  Iterable<String> get keys => _entries.keys;

  // ---------------------------------------------------------------------------
  // Hydrate — restore from storage
  // ---------------------------------------------------------------------------

  /// Restores all registered Core values from storage.
  ///
  /// If [version] is greater than 1 and [migrations] are provided,
  /// the stored version is checked and migrations are run sequentially
  /// to bring data up to the current version.
  ///
  /// Keys not found in storage are silently skipped (Cores keep their
  /// initial values). Invalid JSON data for a key is also skipped.
  ///
  /// ```dart
  /// await relic.hydrate();
  /// ```
  Future<void> hydrate() async {
    _assertNotDisposed();

    // Check if migrations are needed
    if (_migrations.isNotEmpty) {
      await _runMigrations();
    }

    for (final entry in _entries.entries) {
      await _hydrateKey(entry.key, entry.value);
    }

    // Store the current version
    if (version > 1 || _migrations.isNotEmpty) {
      await adapter.write(_versionKey, version.toString());
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

  /// Runs migrations from stored version to current version.
  ///
  /// Reads all stored data into a map, runs each migration function
  /// in sequence, then writes the transformed data back to storage.
  Future<void> _runMigrations() async {
    final raw = await adapter.read(_versionKey);
    final storedVersion = raw != null ? int.tryParse(raw) ?? 1 : 1;

    if (storedVersion >= version) return;

    // Read all current data into a map
    final dataMap = <String, Object?>{};
    for (final key in _entries.keys) {
      final stored = await adapter.read(_prefixedKey(key));
      if (stored != null) {
        try {
          dataMap[key] = jsonDecode(stored);
        } catch (_) {
          // Skip invalid data
        }
      }
    }

    // Run migrations sequentially
    var migrated = dataMap;
    for (var v = storedVersion; v < version; v++) {
      final migration = _migrations[v];
      if (migration != null) {
        migrated = migration(migrated);
      }
    }

    // Write migrated data back
    for (final entry in migrated.entries) {
      await adapter.write(
        _prefixedKey(entry.key),
        jsonEncode(entry.value),
      );
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

  /// Enables auto-saving: every Core change is persisted.
  ///
  /// If [debounce] is provided, saves are debounced per-key — rapid
  /// mutations only trigger a single write after the debounce period.
  /// This prevents I/O storms from high-frequency state changes.
  ///
  /// Call [disableAutoSave] or [dispose] to stop.
  ///
  /// ```dart
  /// // Immediate save on every change
  /// relic.enableAutoSave();
  ///
  /// // Debounced save — at most one write per 500 ms per key
  /// relic.enableAutoSave(debounce: Duration(milliseconds: 500));
  /// ```
  void enableAutoSave({Duration? debounce}) {
    _assertNotDisposed();

    // Avoid double-subscribing
    disableAutoSave();

    for (final entry in _entries.entries) {
      final key = entry.key;
      final relicEntry = entry.value;

      final unsub = relicEntry.core.listen((_) {
        if (debounce != null) {
          _debounceTimers[key]?.cancel();
          _debounceTimers[key] = Timer(debounce, () {
            _persistKey(key, relicEntry);
          });
        } else {
          _persistKey(key, relicEntry);
        }
      });
      _unsubscribers.add(unsub);
    }
  }

  /// Disables auto-saving and cancels any pending debounce timers.
  void disableAutoSave() {
    for (final unsub in _unsubscribers) {
      unsub();
    }
    _unsubscribers.clear();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
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
