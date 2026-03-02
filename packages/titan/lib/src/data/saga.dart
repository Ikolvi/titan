/// Saga — Multi-step async workflow orchestration with compensation.
///
/// A Saga coordinates a sequence of async steps, executing them in order
/// and automatically rolling back completed steps (compensation) if any
/// step fails. All progress is reactive via [Core] state nodes.
///
/// ## Why "Saga"?
///
/// In distributed systems, a Saga is a pattern for managing long-running
/// transactions with compensating actions. Titan's Saga brings this
/// enterprise pattern to client-side state management.
///
/// ## Usage
///
/// ```dart
/// class CheckoutPillar extends Pillar {
///   late final checkout = saga<Order>(
///     steps: [
///       SagaStep(
///         name: 'validate',
///         execute: (_) async => await validateCart(),
///         compensate: (_) async => await restoreCart(),
///       ),
///       SagaStep(
///         name: 'payment',
///         execute: (_) async => await chargeCard(),
///         compensate: (_) async => await refundCard(),
///       ),
///       SagaStep(
///         name: 'confirm',
///         execute: (_) async => await placeOrder(),
///       ),
///     ],
///   );
///
///   Future<void> placeOrder() => checkout.run();
/// }
/// ```
library;

import 'dart:async';

import '../core/state.dart';

/// The status of a [Saga] execution.
enum SagaStatus {
  /// The saga has not been started.
  idle,

  /// The saga is currently executing steps.
  running,

  /// All steps completed successfully.
  completed,

  /// A step failed; compensation is in progress.
  compensating,

  /// The saga failed and compensation is complete.
  failed,
}

/// A single step in a [Saga] workflow.
///
/// Each step has an [execute] function and an optional [compensate]
/// function that undoes the step's effects on failure.
///
/// ```dart
/// SagaStep(
///   name: 'charge',
///   execute: (_) async => await chargeCard(amount),
///   compensate: (_) async => await refundCard(amount),
/// )
/// ```
class SagaStep<T> {
  /// Human-readable name for this step (used in logging/debugging).
  final String name;

  /// The async function to execute for this step.
  ///
  /// Receives the accumulated result from previous steps (or `null`
  /// for the first step). Returns a value that is passed to the
  /// next step.
  final Future<T?> Function(T? previousResult) execute;

  /// Optional compensating action that undoes this step's effects.
  ///
  /// Called in reverse order when a later step fails. Receives
  /// the result produced by [execute].
  final Future<void> Function(T? result)? compensate;

  /// Creates a saga step.
  const SagaStep({required this.name, required this.execute, this.compensate});
}

/// A multi-step async workflow orchestrator with compensating actions.
///
/// Executes a sequence of [SagaStep]s in order. If any step fails,
/// previously completed steps are compensated (rolled back) in
/// reverse order. Progress, status, and errors are all reactive
/// [Core] values.
///
/// ```dart
/// final saga = Saga<String>(
///   steps: [
///     SagaStep(name: 'step1', execute: (_) async => 'one'),
///     SagaStep(name: 'step2', execute: (_) async => 'two'),
///   ],
/// );
///
/// await saga.run();
/// print(saga.status); // SagaStatus.completed
/// ```
class Saga<T> {
  /// The steps to execute in order.
  final List<SagaStep<T>> steps;

  /// Reactive status of the saga.
  final TitanState<SagaStatus> _status;

  /// Reactive current step index (-1 when not started).
  final TitanState<int> _currentStep;

  /// Reactive error (null when no error).
  final TitanState<Object?> _error;

  /// Reactive final result (null until completed).
  final TitanState<T?> _result;

  /// Completed step results (for compensation).
  final List<T?> _stepResults = [];

  /// Optional callback on completion.
  final void Function(T? result)? onComplete;

  /// Optional callback on failure.
  final void Function(Object error, String failedStep)? onError;

  /// Optional callback on each step completion.
  final void Function(String stepName, int index, int total)? onStepComplete;

  /// Creates a Saga workflow.
  ///
  /// - [steps] — The ordered list of workflow steps.
  /// - [onComplete] — Called when all steps succeed.
  /// - [onError] — Called when a step fails (after compensation).
  /// - [onStepComplete] — Called after each successful step.
  /// - [name] — Debug name prefix for internal Cores.
  Saga({
    required this.steps,
    this.onComplete,
    this.onError,
    this.onStepComplete,
    String? name,
  }) : _status = TitanState<SagaStatus>(
         SagaStatus.idle,
         name: name != null ? '${name}_status' : null,
       ),
       _currentStep = TitanState<int>(
         -1,
         name: name != null ? '${name}_step' : null,
       ),
       _error = TitanState<Object?>(
         null,
         name: name != null ? '${name}_error' : null,
       ),
       _result = TitanState<T?>(
         null,
         name: name != null ? '${name}_result' : null,
       );

  /// The current saga status (reactive).
  SagaStatus get status => _status.value;

  /// The underlying reactive status Core.
  TitanState<SagaStatus> get statusCore => _status;

  /// The current step index (reactive), -1 when not started.
  int get currentStep => _currentStep.value;

  /// The underlying reactive step Core.
  TitanState<int> get currentStepCore => _currentStep;

  /// The current error, if any (reactive).
  Object? get error => _error.value;

  /// The final result, if completed (reactive).
  T? get result => _result.value;

  /// The name of the current step, or null if not running.
  String? get currentStepName {
    final idx = _currentStep.peek();
    if (idx < 0 || idx >= steps.length) return null;
    return steps[idx].name;
  }

  /// The total number of steps.
  int get totalSteps => steps.length;

  /// Progress as a fraction (0.0 to 1.0).
  ///
  /// Reads [currentStep] reactively.
  double get progress {
    final step = _currentStep.value;
    if (step < 0) return 0.0;
    return (step + 1) / steps.length;
  }

  /// Whether the saga is currently running.
  bool get isRunning => _status.peek() == SagaStatus.running;

  /// Execute the saga workflow.
  ///
  /// Runs all steps in order. On failure, compensates completed steps
  /// in reverse order. Returns the final result on success.
  ///
  /// Throws if the saga is already running.
  ///
  /// ```dart
  /// final result = await saga.run();
  /// ```
  Future<T?> run() async {
    if (_status.peek() == SagaStatus.running ||
        _status.peek() == SagaStatus.compensating) {
      throw StateError('Saga is already running.');
    }

    _status.value = SagaStatus.running;
    _error.value = null;
    _result.value = null;
    _stepResults.clear();

    T? previousResult;

    for (var i = 0; i < steps.length; i++) {
      _currentStep.value = i;
      final step = steps[i];

      try {
        final stepResult = await step.execute(previousResult);
        _stepResults.add(stepResult);
        previousResult = stepResult;
        onStepComplete?.call(step.name, i, steps.length);
      } catch (e) {
        // Step failed — compensate
        _error.value = e;
        await _compensate(i - 1);
        _status.value = SagaStatus.failed;
        onError?.call(e, step.name);
        return null;
      }
    }

    _result.value = previousResult;
    _status.value = SagaStatus.completed;
    onComplete?.call(previousResult);
    return previousResult;
  }

  /// Compensate completed steps in reverse order.
  Future<void> _compensate(int fromIndex) async {
    _status.value = SagaStatus.compensating;

    for (var i = fromIndex; i >= 0; i--) {
      final step = steps[i];
      final result = i < _stepResults.length ? _stepResults[i] : null;
      _currentStep.value = i;

      try {
        await step.compensate?.call(result);
      } catch (_) {
        // Compensation failures are swallowed — best effort.
        // In production, these would be logged via Vigil.
      }
    }
  }

  /// Reset the saga to idle state.
  ///
  /// Clears the error, result, and step progress.
  void reset() {
    _status.value = SagaStatus.idle;
    _currentStep.value = -1;
    _error.value = null;
    _result.value = null;
    _stepResults.clear();
  }

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [
    _status,
    _currentStep,
    _error,
    _result,
  ];

  /// Dispose all internal state.
  void dispose() {
    _status.dispose();
    _currentStep.dispose();
    _error.dispose();
    _result.dispose();
  }

  @override
  String toString() =>
      'Saga(status: ${_status.peek()}, step: ${_currentStep.peek()}/${steps.length})';
}
