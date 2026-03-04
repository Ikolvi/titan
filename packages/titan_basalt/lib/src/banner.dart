import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:titan/titan.dart';

// =============================================================================
// Banner — Reactive Feature Flags
// =============================================================================

/// A rule that determines feature flag state based on evaluation context.
///
/// Rules receive a context map and return whether the flag should be enabled.
///
/// ```dart
/// final premiumOnly = BannerRule(
///   name: 'is-premium',
///   evaluate: (ctx) => ctx['tier'] == 'premium',
///   reason: 'Premium subscription required',
/// );
/// ```
class BannerRule {
  /// Creates a rule with a [name], [evaluate] function, and optional [reason].
  const BannerRule({required this.name, required this.evaluate, this.reason});

  /// Human-readable rule name.
  final String name;

  /// Evaluates whether the rule passes for the given [context].
  final bool Function(Map<String, dynamic> context) evaluate;

  /// Optional explanation for why this rule exists.
  final String? reason;

  @override
  String toString() => 'BannerRule($name)';
}

/// Configuration for a single feature flag.
///
/// A [BannerFlag] defines the default state, targeting rules, rollout
/// percentage, and expiration for a feature flag.
///
/// ```dart
/// final flag = BannerFlag(
///   name: 'new-checkout',
///   description: 'Redesigned checkout flow',
///   defaultValue: false,
///   rollout: 0.25, // 25% of users
///   rules: [
///     BannerRule(
///       name: 'is-beta',
///       evaluate: (ctx) => ctx['beta'] == true,
///     ),
///   ],
/// );
/// ```
class BannerFlag {
  /// Creates a feature flag configuration.
  const BannerFlag({
    required this.name,
    this.defaultValue = false,
    this.rules = const [],
    this.rollout,
    this.expiresAt,
    this.description,
  }) : assert(
         rollout == null || (rollout >= 0.0 && rollout <= 1.0),
         'rollout must be between 0.0 and 1.0',
       );

  /// Unique identifier for this flag.
  final String name;

  /// Value when no rules match and no override is set.
  final bool defaultValue;

  /// Rules evaluated in order; first matching rule determines state.
  ///
  /// If no rules match, [rollout] is checked, then [defaultValue] is used.
  final List<BannerRule> rules;

  /// Percentage of users that should see this feature (0.0–1.0).
  ///
  /// Uses deterministic hashing so the same user always gets the same
  /// result for a given flag. Pass `userId` to [Banner.isEnabled] for
  /// sticky assignment.
  final double? rollout;

  /// When set, the flag automatically evaluates to [defaultValue] after
  /// this timestamp.
  final DateTime? expiresAt;

  /// Human-readable description of the feature.
  final String? description;

  @override
  String toString() => 'BannerFlag($name, default=$defaultValue)';
}

/// Result of evaluating a feature flag.
///
/// Includes the resolved value and the reason it was resolved that way.
class BannerEvaluation {
  /// Creates an evaluation result.
  const BannerEvaluation({
    required this.flagName,
    required this.enabled,
    required this.reason,
    this.matchedRule,
  });

  /// Which flag was evaluated.
  final String flagName;

  /// The resolved enabled/disabled state.
  final bool enabled;

  /// Why this value was resolved (override, rule match, rollout, default, expired).
  final BannerReason reason;

  /// If resolved by a rule, which rule matched.
  final String? matchedRule;

  @override
  String toString() =>
      'BannerEvaluation($flagName=$enabled, reason=$reason'
      '${matchedRule != null ? ', rule=$matchedRule' : ''})';
}

/// The reason a feature flag resolved to its value.
enum BannerReason {
  /// An explicit override was set via [Banner.setOverride].
  forceOverride,

  /// A [BannerRule] matched and determined the value.
  rule,

  /// The flag's [BannerFlag.rollout] percentage determined the value.
  rollout,

  /// No rules or rollout applied; [BannerFlag.defaultValue] was used.
  defaultValue,

  /// The flag has passed its [BannerFlag.expiresAt] timestamp.
  expired,

  /// The flag name was not found in the registry.
  notFound,
}

/// A reactive feature flag registry with targeting rules and rollout control.
///
/// **Banner** manages a collection of feature flags with reactive state,
/// percentage-based rollout, context-aware targeting rules, developer
/// overrides, and expiration. Each flag's enabled state is a reactive
/// [Core<bool>] that triggers UI rebuilds when updated.
///
/// ## Quick start
///
/// ```dart
/// class AppPillar extends Pillar {
///   late final flags = banner(
///     flags: [
///       BannerFlag(name: 'dark-mode', defaultValue: false),
///       BannerFlag(
///         name: 'new-checkout',
///         rollout: 0.5,
///         description: 'Redesigned checkout flow',
///       ),
///       BannerFlag(
///         name: 'premium-feature',
///         rules: [
///           BannerRule(
///             name: 'is-premium',
///             evaluate: (ctx) => ctx['tier'] == 'premium',
///           ),
///         ],
///       ),
///     ],
///   );
///
///   late final showNewCheckout = derived(
///     () => flags['new-checkout'].value,
///   );
/// }
/// ```
///
/// ## Rollout percentages
///
/// Use `rollout` for gradual feature rollout. The result is deterministic
/// per `userId` — the same user always gets the same result:
///
/// ```dart
/// flags.isEnabled('new-checkout', userId: 'user-42'); // consistent result
/// ```
///
/// ## Developer overrides
///
/// Force flag values during development or QA:
///
/// ```dart
/// flags.override('dark-mode', true);   // Force enable
/// flags.clearOverride('dark-mode');     // Back to normal evaluation
/// ```
///
/// ## Remote config integration
///
/// Bulk-update flags from a backend (Firebase Remote Config, LaunchDarkly, etc.):
///
/// ```dart
/// flags.updateFlags({'dark-mode': true, 'new-checkout': false});
/// ```
class Banner {
  /// Creates a feature flag registry with the given [flags].
  ///
  /// An optional [name] aids debugging. Pass [now] to override the
  /// clock for testing expiration behavior.
  Banner({
    required List<BannerFlag> flags,
    this.name,
    @visibleForTesting DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    for (final flag in flags) {
      final r = flag.rollout;
      if (r != null && (r < 0.0 || r > 1.0)) {
        throw ArgumentError.value(
          r,
          'rollout',
          'rollout must be between 0.0 and 1.0 (flag "${flag.name}")',
        );
      }
      _configs[flag.name] = flag;
      _states[flag.name] = TitanState<bool>(flag.defaultValue);
    }
    _enabledCount = TitanComputed<int>(
      () => _states.values.where((s) => s.value).length,
    );
    _totalCount = TitanComputed<int>(() => _states.length);
  }

  /// Optional name for debugging.
  final String? name;

  final DateTime Function() _now;
  final Map<String, BannerFlag> _configs = {};
  final Map<String, TitanState<bool>> _states = {};
  final Map<String, bool> _overrides = {};
  final Map<String, bool> _remoteValues = {};
  late final TitanComputed<int> _enabledCount;
  late final TitanComputed<int> _totalCount;

  // ---------------------------------------------------------------------------
  // Evaluation
  // ---------------------------------------------------------------------------

  /// Returns whether the flag [flagName] is enabled.
  ///
  /// Evaluation priority:
  /// 1. Override (set via [override])
  /// 2. Expired check (if [BannerFlag.expiresAt] has passed)
  /// 3. Rules (first matching [BannerRule] wins)
  /// 4. Rollout percentage (deterministic per [userId])
  /// 5. Remote value (set via [updateFlags])
  /// 6. Default value
  ///
  /// Pass [context] for rule evaluation and [userId] for sticky rollout.
  bool isEnabled(
    String flagName, {
    Map<String, dynamic>? context,
    String? userId,
  }) {
    return evaluate(flagName, context: context, userId: userId).enabled;
  }

  /// Evaluates a flag and returns the full [BannerEvaluation] with reason.
  ///
  /// ```dart
  /// final eval = flags.evaluate('new-checkout', userId: 'user-42');
  /// print(eval.reason); // BannerReason.rollout
  /// ```
  BannerEvaluation evaluate(
    String flagName, {
    Map<String, dynamic>? context,
    String? userId,
  }) {
    final config = _configs[flagName];
    if (config == null) {
      return BannerEvaluation(
        flagName: flagName,
        enabled: false,
        reason: BannerReason.notFound,
      );
    }

    // 1. Override
    final overrideValue = _overrides[flagName];
    if (overrideValue != null) {
      _updateState(flagName, overrideValue);
      return BannerEvaluation(
        flagName: flagName,
        enabled: overrideValue,
        reason: BannerReason.forceOverride,
      );
    }

    // 2. Expiration
    if (config.expiresAt != null && _now().isAfter(config.expiresAt!)) {
      _updateState(flagName, config.defaultValue);
      return BannerEvaluation(
        flagName: flagName,
        enabled: config.defaultValue,
        reason: BannerReason.expired,
      );
    }

    // 3. Rules (first match wins)
    if (config.rules.isNotEmpty && context != null) {
      for (final rule in config.rules) {
        if (rule.evaluate(context)) {
          _updateState(flagName, true);
          return BannerEvaluation(
            flagName: flagName,
            enabled: true,
            reason: BannerReason.rule,
            matchedRule: rule.name,
          );
        }
      }
    }

    // 4. Rollout percentage
    if (config.rollout != null && userId != null) {
      final enabled = _isInRollout(flagName, userId, config.rollout!);
      _updateState(flagName, enabled);
      return BannerEvaluation(
        flagName: flagName,
        enabled: enabled,
        reason: BannerReason.rollout,
      );
    }

    // 5. Remote value
    final remoteValue = _remoteValues[flagName];
    if (remoteValue != null) {
      _updateState(flagName, remoteValue);
      return BannerEvaluation(
        flagName: flagName,
        enabled: remoteValue,
        reason: BannerReason.defaultValue,
      );
    }

    // 6. Default
    _updateState(flagName, config.defaultValue);
    return BannerEvaluation(
      flagName: flagName,
      enabled: config.defaultValue,
      reason: BannerReason.defaultValue,
    );
  }

  /// Accesses the reactive [Core<bool>] for a flag by name.
  ///
  /// Use this in [Derived] computations or Vestige builders:
  ///
  /// ```dart
  /// late final showFeature = derived(() => flags['new-checkout'].value);
  /// ```
  ///
  /// Throws [ArgumentError] if the flag is not registered.
  Core<bool> operator [](String flagName) {
    final state = _states[flagName];
    if (state == null) {
      throw ArgumentError('Unknown banner flag: "$flagName"');
    }
    return state;
  }

  // ---------------------------------------------------------------------------
  // Overrides (dev / testing)
  // ---------------------------------------------------------------------------

  /// Forces a flag to the given [value], bypassing all rules and rollout.
  ///
  /// Use during development or QA testing:
  ///
  /// ```dart
  /// flags.setOverride('dark-mode', true);
  /// ```
  void setOverride(String flagName, bool value) {
    if (!_configs.containsKey(flagName)) {
      throw ArgumentError('Unknown banner flag: "$flagName"');
    }
    _overrides[flagName] = value;
    _updateState(flagName, value);
  }

  /// Removes the override for a flag, returning to normal evaluation.
  void clearOverride(String flagName) {
    _overrides.remove(flagName);
    // Re-evaluate with default (no context/userId available here)
    final config = _configs[flagName];
    if (config != null) {
      _updateState(flagName, config.defaultValue);
    }
  }

  /// Removes all overrides.
  void clearAllOverrides() {
    final overriddenNames = _overrides.keys.toList();
    _overrides.clear();
    for (final name in overriddenNames) {
      final config = _configs[name];
      if (config != null) {
        _updateState(name, config.defaultValue);
      }
    }
  }

  /// Whether a flag currently has an active override.
  bool hasOverride(String flagName) => _overrides.containsKey(flagName);

  /// Returns a copy of all active overrides.
  Map<String, bool> get overrides => Map.unmodifiable(_overrides);

  // ---------------------------------------------------------------------------
  // Remote config / bulk updates
  // ---------------------------------------------------------------------------

  /// Updates flag values from an external source (Firebase, LaunchDarkly, etc.).
  ///
  /// Values set here take effect when no override is active and no rules match.
  /// This allows remote config to set base values that rules can still override.
  ///
  /// ```dart
  /// // From remote config
  /// flags.updateFlags({
  ///   'dark-mode': true,
  ///   'new-checkout': false,
  /// });
  /// ```
  void updateFlags(Map<String, bool> values) {
    for (final entry in values.entries) {
      _remoteValues[entry.key] = entry.value;
      if (_configs.containsKey(entry.key) &&
          !_overrides.containsKey(entry.key)) {
        _updateState(entry.key, entry.value);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers a new flag at runtime.
  ///
  /// Throws [ArgumentError] if a flag with the same name already exists.
  void register(BannerFlag flag) {
    if (_configs.containsKey(flag.name)) {
      throw ArgumentError('Banner flag "${flag.name}" is already registered');
    }
    _configs[flag.name] = flag;
    _states[flag.name] = TitanState<bool>(flag.defaultValue);
  }

  /// Removes a flag from the registry.
  ///
  /// Returns `true` if the flag existed and was removed.
  bool unregister(String flagName) {
    _overrides.remove(flagName);
    _remoteValues.remove(flagName);
    _configs.remove(flagName);
    final state = _states.remove(flagName);
    return state != null;
  }

  // ---------------------------------------------------------------------------
  // Inspection
  // ---------------------------------------------------------------------------

  /// All registered flag names.
  List<String> get names => _configs.keys.toList(growable: false);

  /// Whether a flag with [flagName] is registered.
  bool has(String flagName) => _configs.containsKey(flagName);

  /// The number of registered flags.
  int get count => _configs.length;

  /// Reactive count of currently enabled flags.
  ///
  /// This is a [Derived] that auto-updates when any flag state changes.
  Derived<int> get enabledCount => _enabledCount;

  /// Reactive total count of registered flags.
  Derived<int> get totalCount => _totalCount;

  /// Returns the [BannerFlag] configuration for a flag.
  ///
  /// Returns `null` if the flag is not registered.
  BannerFlag? config(String flagName) => _configs[flagName];

  /// Returns a snapshot of all flag states as a map.
  Map<String, bool> get snapshot => _states.map((k, v) => MapEntry(k, v.value));

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Reactive nodes managed by this Banner for Pillar lifecycle integration.
  Iterable<ReactiveNode> get managedNodes => [
    ..._states.values,
    _enabledCount,
    _totalCount,
  ];

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _updateState(String flagName, bool value) {
    final state = _states[flagName];
    if (state != null && state.value != value) {
      state.value = value;
    }
  }

  /// Deterministic rollout check using FNV-1a hash.
  ///
  /// The same (flagName, userId) pair always produces the same result,
  /// ensuring sticky user assignment.
  bool _isInRollout(String flagName, String userId, double percentage) {
    final key = '$flagName:$userId';
    final bytes = utf8.encode(key);
    // FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final bucket = (hash % 10000) / 10000.0;
    return bucket < percentage;
  }

  @override
  String toString() {
    final label = name != null ? ' "$name"' : '';
    return 'Banner$label(${_configs.length} flags, '
        '${_states.values.where((s) => s.value).length} enabled)';
  }
}
