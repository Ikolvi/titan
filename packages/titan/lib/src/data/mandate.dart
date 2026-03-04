import '../core/computed.dart';
import '../core/state.dart';

// ---------------------------------------------------------------------------
// Mandate — Reactive Policy Engine
// ---------------------------------------------------------------------------

/// Combination strategy for evaluating multiple [Writ] rules.
///
/// Controls how individual writ results are combined into a final
/// [MandateVerdict].
///
/// ```dart
/// // All writs must pass (default)
/// final access = Mandate(writs: rules, strategy: MandateStrategy.allOf);
///
/// // At least one writ must pass
/// final feature = Mandate(writs: rules, strategy: MandateStrategy.anyOf);
///
/// // Passing writs must outweigh failing writs (by weight)
/// final approval = Mandate(writs: rules, strategy: MandateStrategy.majority);
/// ```
enum MandateStrategy {
  /// All writs must pass (logical AND). Default.
  allOf,

  /// At least one writ must pass (logical OR).
  anyOf,

  /// Passing writs must outweigh failing writs (by weight).
  majority,
}

/// A single policy rule evaluated by a [Mandate].
///
/// Each Writ has a reactive [evaluate] function that reads Core values.
/// When those Cores change, the Writ automatically re-evaluates via
/// the reactive engine's dependency tracking.
///
/// ```dart
/// Writ(
///   name: 'is-admin',
///   evaluate: () => userRole.value == 'admin',
///   reason: 'Admin access required',
///   description: 'User must have admin role',
/// )
/// ```
class Writ {
  /// Creates a policy rule.
  ///
  /// - [name] — Unique identifier for this writ.
  /// - [evaluate] — Reactive function. Reads Core values for auto-tracking.
  /// - [description] — Human-readable description of the rule.
  /// - [reason] — Denial reason shown when this writ fails.
  /// - [weight] — Weight for [MandateStrategy.majority] (default: 1).
  const Writ({
    required this.name,
    required this.evaluate,
    this.description,
    this.reason,
    this.weight = 1,
  });

  /// Unique identifier for this writ.
  final String name;

  /// Reactive evaluation function.
  ///
  /// Reading Core values inside this function automatically registers
  /// them as dependencies. When any dependency changes, the writ
  /// re-evaluates automatically.
  final bool Function() evaluate;

  /// Human-readable description of this policy rule.
  final String? description;

  /// Denial reason shown when this writ fails.
  final String? reason;

  /// Weight for [MandateStrategy.majority] strategy (default: 1).
  ///
  /// Higher weights give this writ more influence in majority votes.
  final int weight;
}

/// Details of a [Writ] that failed evaluation.
///
/// Included in [MandateDenial.violations] to explain why access was denied.
class WritViolation {
  /// Creates a writ violation record.
  const WritViolation({required this.writName, this.reason});

  /// Name of the writ that failed.
  final String writName;

  /// Human-readable denial reason (from [Writ.reason]).
  final String? reason;

  @override
  String toString() => reason != null
      ? 'WritViolation($writName: $reason)'
      : 'WritViolation($writName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WritViolation &&
          writName == other.writName &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(writName, reason);
}

/// Result of evaluating a [Mandate]'s policies.
///
/// Use pattern matching to handle the result:
///
/// ```dart
/// switch (pillar.editAccess.verdict.value) {
///   case MandateGrant():
///     return EditButton();
///   case MandateDenial(:final violations):
///     return DeniedBanner(violations);
/// }
/// ```
sealed class MandateVerdict {
  const MandateVerdict();

  /// Whether the mandate was granted.
  bool get isGranted;

  /// Whether the mandate was denied.
  bool get isDenied => !isGranted;

  /// List of writs that failed. Empty for [MandateGrant].
  List<WritViolation> get violations;
}

/// All required writs passed — access is granted.
class MandateGrant extends MandateVerdict {
  /// Creates a grant verdict.
  const MandateGrant();

  @override
  bool get isGranted => true;

  @override
  List<WritViolation> get violations => const [];

  @override
  String toString() => 'MandateGrant()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MandateGrant;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// One or more required writs failed — access is denied.
class MandateDenial extends MandateVerdict {
  /// Creates a denial verdict with the list of failed writs.
  const MandateDenial({required this.violations});

  @override
  bool get isGranted => false;

  /// Details of each failed writ.
  @override
  final List<WritViolation> violations;

  @override
  String toString() {
    final reasons = violations.map((v) => v.writName).join(', ');
    return 'MandateDenial([$reasons])';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MandateDenial) return false;
    if (violations.length != other.violations.length) return false;
    for (var i = 0; i < violations.length; i++) {
      if (violations[i] != other.violations[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(violations);
}

/// Reactive policy evaluation engine.
///
/// Mandate evaluates [Writ] policies reactively — when any [Core] read
/// inside a Writ's evaluation function changes, the verdict automatically
/// re-evaluates and downstream [Vestige] widgets rebuild.
///
/// ```dart
/// class DocumentPillar extends Pillar {
///   late final currentUser = core<User?>(null);
///   late final document = core<Document?>(null);
///
///   late final editAccess = mandate(
///     writs: [
///       Writ(
///         name: 'authenticated',
///         evaluate: () => currentUser.value != null,
///         reason: 'Must be logged in',
///       ),
///       Writ(
///         name: 'is-owner',
///         evaluate: () => document.value?.ownerId == currentUser.value?.id,
///         reason: 'Only the owner can edit',
///       ),
///     ],
///   );
/// }
///
/// // In UI — auto-rebuilds on auth/document changes:
/// Vestige<DocumentPillar>(
///   builder: (_, p) => p.editAccess.isGranted.value
///     ? EditButton()
///     : DeniedBanner(p.editAccess.violations.value),
/// )
/// ```
///
/// See also:
/// - [Writ] — individual policy rule
/// - [MandateVerdict] — sealed evaluation result
/// - [MandateStrategy] — combination mode
class Mandate {
  final String? _name;
  MandateStrategy _strategy;

  // Internal writ tracking
  final List<Writ> _writs = [];
  final Map<String, TitanComputed<bool>> _writResults = {};

  // Trigger for structural changes (add/remove writ, strategy change)
  late final TitanState<int> _revision;

  // Composite reactive outputs
  late final TitanComputed<MandateVerdict> _verdict;
  late final TitanComputed<bool> _isGranted;
  late final TitanComputed<List<WritViolation>> _violations;

  bool _isDisposed = false;

  /// Creates a reactive policy engine.
  ///
  /// - [writs] — Initial list of policy rules.
  /// - [strategy] — How to combine writ results (default: [MandateStrategy.allOf]).
  /// - [name] — Debug name for reactive nodes.
  ///
  /// ```dart
  /// final access = Mandate(
  ///   writs: [
  ///     Writ(name: 'admin', evaluate: () => role.value == 'admin'),
  ///   ],
  /// );
  /// ```
  Mandate({
    List<Writ> writs = const [],
    MandateStrategy strategy = MandateStrategy.allOf,
    String? name,
  }) : _strategy = strategy,
       _name = name {
    _revision = TitanState<int>(0, name: '${name ?? 'mandate'}_revision');

    // Register initial writs
    for (final writ in writs) {
      _registerWrit(writ);
    }

    // Composite: verdict
    _verdict = TitanComputed<MandateVerdict>(() {
      // Read revision to re-evaluate on structural changes
      _revision.value;
      return _evaluate();
    }, name: '${name ?? 'mandate'}_verdict');

    // Composite: isGranted
    _isGranted = TitanComputed<bool>(() {
      return _verdict.value.isGranted;
    }, name: '${name ?? 'mandate'}_isGranted');

    // Composite: violations
    _violations = TitanComputed<List<WritViolation>>(() {
      return _verdict.value.violations;
    }, name: '${name ?? 'mandate'}_violations');
  }

  // ---------------------------------------------------------------------------
  // Reactive Queries
  // ---------------------------------------------------------------------------

  /// Overall verdict. Reactive — auto-updates when dependencies change.
  ///
  /// ```dart
  /// switch (pillar.editAccess.verdict.value) {
  ///   case MandateGrant():
  ///     return EditButton();
  ///   case MandateDenial(:final violations):
  ///     return DeniedBanner(violations);
  /// }
  /// ```
  TitanComputed<MandateVerdict> get verdict => _verdict;

  /// Convenience: reactive boolean — `true` when the mandate is granted.
  ///
  /// ```dart
  /// if (pillar.editAccess.isGranted.value) { ... }
  /// ```
  TitanComputed<bool> get isGranted => _isGranted;

  /// All current violations. Empty when fully granted.
  ///
  /// ```dart
  /// for (final v in pillar.editAccess.violations.value) {
  ///   print('${v.writName}: ${v.reason}');
  /// }
  /// ```
  TitanComputed<List<WritViolation>> get violations => _violations;

  /// Check a single writ by name.
  ///
  /// Returns the cached [TitanComputed<bool>] that reactively tracks
  /// that writ's dependencies. Throws [StateError] if no writ with
  /// that name exists.
  ///
  /// ```dart
  /// if (pillar.editAccess.can('is-owner').value) { ... }
  /// ```
  TitanComputed<bool> can(String writName) {
    final result = _writResults[writName];
    if (result == null) {
      throw StateError('No writ named "$writName" in Mandate');
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Dynamic Writ Management
  // ---------------------------------------------------------------------------

  /// Add a writ. Triggers reactive re-evaluation.
  ///
  /// Throws [ArgumentError] if a writ with the same name already exists.
  void addWrit(Writ writ) {
    _assertNotDisposed();
    if (_writResults.containsKey(writ.name)) {
      throw ArgumentError(
        'Writ "${writ.name}" already exists. '
        'Use replaceWrit() to update it.',
      );
    }
    _registerWrit(writ);
    _bumpRevision();
  }

  /// Add multiple writs at once. Triggers a single re-evaluation.
  void addWrits(List<Writ> writs) {
    _assertNotDisposed();
    for (final writ in writs) {
      if (_writResults.containsKey(writ.name)) {
        throw ArgumentError('Writ "${writ.name}" already exists.');
      }
    }
    for (final writ in writs) {
      _registerWrit(writ);
    }
    _bumpRevision();
  }

  /// Remove a writ by name. Triggers reactive re-evaluation.
  ///
  /// Returns `true` if the writ was found and removed.
  bool removeWrit(String name) {
    _assertNotDisposed();
    final computed = _writResults.remove(name);
    if (computed == null) return false;
    computed.dispose();
    _writs.removeWhere((w) => w.name == name);
    _bumpRevision();
    return true;
  }

  /// Replace a writ with the same name. Triggers reactive re-evaluation.
  ///
  /// Throws [StateError] if no writ with that name exists.
  void replaceWrit(Writ writ) {
    _assertNotDisposed();
    final existing = _writResults[writ.name];
    if (existing == null) {
      throw StateError('No writ named "${writ.name}" to replace.');
    }
    existing.dispose();
    _writs.removeWhere((w) => w.name == writ.name);
    _registerWrit(writ);
    _bumpRevision();
  }

  /// Change the combination strategy. Triggers re-evaluation.
  void updateStrategy(MandateStrategy strategy) {
    _assertNotDisposed();
    if (_strategy == strategy) return;
    _strategy = strategy;
    _bumpRevision();
  }

  // ---------------------------------------------------------------------------
  // Inspection
  // ---------------------------------------------------------------------------

  /// Names of all registered writs.
  List<String> get writNames => _writs.map((w) => w.name).toList();

  /// Number of registered writs.
  int get writCount => _writs.length;

  /// Whether a writ with this name exists.
  bool hasWrit(String name) => _writResults.containsKey(name);

  /// The current combination strategy.
  MandateStrategy get strategy => _strategy;

  /// The debug name, if provided.
  String? get name => _name;

  /// Whether this Mandate has been disposed.
  bool get isDisposed => _isDisposed;

  // ---------------------------------------------------------------------------
  // Pillar Integration
  // ---------------------------------------------------------------------------

  /// All managed reactive nodes for Pillar auto-disposal.
  List<TitanComputed<dynamic>> get managedNodes => [
    _verdict,
    _isGranted,
    _violations,
    ..._writResults.values,
  ];

  /// All managed state nodes for Pillar auto-disposal.
  List<TitanState<dynamic>> get managedStateNodes => [_revision];

  /// Dispose all internal reactive nodes.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final computed in _writResults.values) {
      computed.dispose();
    }
    _writResults.clear();
    _writs.clear();
    _verdict.dispose();
    _isGranted.dispose();
    _violations.dispose();
    _revision.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _registerWrit(Writ writ) {
    _writs.add(writ);
    _writResults[writ.name] = TitanComputed<bool>(
      writ.evaluate,
      name: '${_name ?? 'mandate'}_writ_${writ.name}',
    );
  }

  void _bumpRevision() {
    _revision.value = _revision.value + 1;
  }

  MandateVerdict _evaluate() {
    if (_writs.isEmpty) return const MandateGrant();

    List<WritViolation>? violations;
    var passWeight = 0;
    var failWeight = 0;

    for (final writ in _writs) {
      final result = _writResults[writ.name];
      if (result == null) continue;

      if (result.value) {
        passWeight += writ.weight;
      } else {
        failWeight += writ.weight;
        (violations ??= []).add(
          WritViolation(writName: writ.name, reason: writ.reason),
        );
      }
    }

    switch (_strategy) {
      case MandateStrategy.allOf:
        return violations == null
            ? const MandateGrant()
            : MandateDenial(violations: violations);

      case MandateStrategy.anyOf:
        return passWeight > 0
            ? const MandateGrant()
            : MandateDenial(violations: violations ?? const []);

      case MandateStrategy.majority:
        return passWeight > failWeight
            ? const MandateGrant()
            : MandateDenial(violations: violations ?? const []);
    }
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use a disposed Mandate');
    }
  }

  @override
  String toString() =>
      'Mandate(${_name ?? 'unnamed'}, '
      'writs: ${_writs.length}, strategy: ${_strategy.name})';
}
