/// Annals — Immutable audit trail for reactive state mutations.
///
/// Annals provides a centralized, append-only log of Core value changes
/// with timestamps, source Pillar types, and optional metadata. Essential
/// for enterprise compliance, debugging, and regulatory requirements.
///
/// ## Why "Annals"?
///
/// Annals are historical records — the definitive chronicle of events.
/// Titan's Annals record every significant state mutation for posterity.
///
/// ## Usage
///
/// ```dart
/// // Enable audit trail
/// Annals.enable();
///
/// // Record a mutation
/// Annals.record(AnnalEntry(
///   coreName: 'balance',
///   pillarType: 'AccountPillar',
///   oldValue: 100,
///   newValue: 200,
///   action: 'deposit',
/// ));
///
/// // Query entries
/// final recent = Annals.entries.take(10);
/// final filtered = Annals.query(pillarType: 'AccountPillar');
///
/// // Export for compliance
/// final json = Annals.export();
/// ```
library;

import 'dart:async';
import 'dart:collection';

/// A single entry in the audit trail.
///
/// Each entry records a state mutation with full context:
/// who changed what, when, and from/to which values.
class AnnalEntry {
  /// The name of the Core that was mutated.
  final String coreName;

  /// The runtime type of the Pillar that owns the Core.
  final String? pillarType;

  /// The value before the mutation.
  final dynamic oldValue;

  /// The value after the mutation.
  final dynamic newValue;

  /// When the mutation occurred.
  final DateTime timestamp;

  /// Optional action/event name that triggered this mutation.
  final String? action;

  /// Optional user identifier for compliance tracking.
  final String? userId;

  /// Optional metadata for additional context.
  final Map<String, dynamic>? metadata;

  /// Creates an audit entry.
  AnnalEntry({
    required this.coreName,
    this.pillarType,
    required this.oldValue,
    required this.newValue,
    DateTime? timestamp,
    this.action,
    this.userId,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to a serializable map.
  Map<String, dynamic> toMap() => {
    'coreName': coreName,
    if (pillarType != null) 'pillarType': pillarType,
    'oldValue': '$oldValue',
    'newValue': '$newValue',
    'timestamp': timestamp.toIso8601String(),
    if (action != null) 'action': action,
    if (userId != null) 'userId': userId,
    if (metadata != null) 'metadata': metadata,
  };

  @override
  String toString() =>
      'AnnalEntry($coreName: $oldValue → $newValue${action != null ? ' [$action]' : ''})';
}

/// Centralized, immutable audit trail manager.
///
/// Records state mutations as [AnnalEntry] objects with configurable
/// retention, filtering, and export capabilities.
///
/// ```dart
/// Annals.enable();
///
/// // Automatic recording via Pillar integration
/// pillar.strike(() {
///   balance.value = newBalance; // Recorded if audit is enabled
/// });
///
/// // Manual recording
/// Annals.record(AnnalEntry(
///   coreName: 'setting',
///   oldValue: oldVal,
///   newValue: newVal,
///   action: 'user_update',
///   userId: currentUser.id,
/// ));
///
/// // Query and export
/// final exports = Annals.export();
/// ```
class Annals {
  Annals._();

  static bool _enabled = false;
  static int _maxEntries = 10000;
  static final Queue<AnnalEntry> _entries = Queue<AnnalEntry>();
  static final StreamController<AnnalEntry> _controller =
      StreamController<AnnalEntry>.broadcast();

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Whether the audit trail is enabled.
  static bool get isEnabled => _enabled;

  /// Enable the audit trail.
  ///
  /// When enabled, calls to [record] store entries and emit them
  /// through [stream].
  static void enable({int maxEntries = 10000}) {
    _enabled = true;
    _maxEntries = maxEntries;
  }

  /// Disable the audit trail.
  ///
  /// New entries are ignored but existing entries are preserved.
  static void disable() {
    _enabled = false;
  }

  /// The maximum number of entries to retain.
  ///
  /// When the limit is reached, oldest entries are evicted (FIFO).
  static int get maxEntries => _maxEntries;

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Record an audit entry.
  ///
  /// Ignored if the audit trail is not [isEnabled].
  ///
  /// ```dart
  /// Annals.record(AnnalEntry(
  ///   coreName: 'email',
  ///   pillarType: 'UserPillar',
  ///   oldValue: 'old@email.com',
  ///   newValue: 'new@email.com',
  ///   action: 'profile_update',
  ///   userId: 'user_123',
  /// ));
  /// ```
  static void record(AnnalEntry entry) {
    if (!_enabled) return;

    _entries.add(entry);

    // Evict oldest when over capacity — O(1) with Queue.removeFirst()
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }

    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  // ---------------------------------------------------------------------------
  // Querying
  // ---------------------------------------------------------------------------

  /// All recorded entries (oldest first).
  static List<AnnalEntry> get entries => List.unmodifiable(_entries.toList());

  /// The number of recorded entries.
  static int get length => _entries.length;

  /// Stream of audit entries as they are recorded.
  static Stream<AnnalEntry> get stream => _controller.stream;

  /// Query entries with optional filters.
  ///
  /// All filters are AND-combined.
  ///
  /// ```dart
  /// final userChanges = Annals.query(
  ///   pillarType: 'UserPillar',
  ///   after: oneHourAgo,
  ///   coreName: 'email',
  /// );
  /// ```
  static List<AnnalEntry> query({
    String? coreName,
    String? pillarType,
    String? action,
    String? userId,
    DateTime? after,
    DateTime? before,
    int? limit,
  }) {
    bool matches(AnnalEntry e) {
      if (coreName != null && e.coreName != coreName) return false;
      if (pillarType != null && e.pillarType != pillarType) return false;
      if (action != null && e.action != action) return false;
      if (userId != null && e.userId != userId) return false;
      if (after != null && !e.timestamp.isAfter(after)) return false;
      if (before != null && !e.timestamp.isBefore(before)) return false;
      return true;
    }

    // Fast path: when limit is specified, collect the last N matches
    // by iterating backwards — avoids materializing the full result.
    if (limit != null && limit > 0) {
      final collected = <AnnalEntry>[];
      final snapshot = _entries.toList();
      for (
        var i = snapshot.length - 1;
        i >= 0 && collected.length < limit;
        i--
      ) {
        if (matches(snapshot[i])) {
          collected.add(snapshot[i]);
        }
      }
      return collected.reversed.toList();
    }

    // No limit — iterate forward and collect all matches.
    return _entries.where(matches).toList();
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Export all entries as a list of serializable maps.
  ///
  /// ```dart
  /// final data = Annals.export();
  /// final json = jsonEncode(data);
  /// ```
  static List<Map<String, dynamic>> export({
    String? pillarType,
    DateTime? after,
    DateTime? before,
  }) {
    final filtered = query(
      pillarType: pillarType,
      after: after,
      before: before,
    );
    return filtered.map((e) => e.toMap()).toList();
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------

  /// Clear all audit entries.
  static void clear() {
    _entries.clear();
  }

  /// Reset the audit system completely.
  ///
  /// Clears all entries and disables auditing.
  static void reset() {
    _entries.clear();
    _enabled = false;
    _maxEntries = 10000;
  }
}
