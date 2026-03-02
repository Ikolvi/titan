import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'imprint.dart';
import 'shade.dart';

// ---------------------------------------------------------------------------
// Phantom — Gesture Replay Engine
// ---------------------------------------------------------------------------

/// **Phantom** — replays recorded [ShadeSession]s as a virtual user.
///
/// Phantom takes a [ShadeSession] and replays every [Imprint] through
/// Flutter's gesture system using [GestureBinding.handlePointerEvent].
/// During replay, [Colossus] collects performance metrics, producing a
/// [Decree] that reflects real-world performance under the recorded
/// interaction pattern.
///
/// ## Why "Phantom"?
///
/// A phantom user — invisible, silent, perfect — walks the same path
/// the original user walked, triggering the same taps, scrolls, and
/// gestures. The Colossus watches, measures, and judges.
///
/// ## Usage
///
/// ```dart
/// final phantom = Phantom();
///
/// // Replay a recorded session
/// await phantom.replay(session);
///
/// // Generate performance report
/// final decree = Colossus.instance.decree();
/// print(decree.summary);
/// ```
///
/// ## Screen Normalization
///
/// If the replay device has a different screen size than the recording
/// device, Phantom normalizes positions proportionally:
///
/// ```dart
/// final phantom = Phantom(normalizePositions: true);
/// await phantom.replay(session);
/// ```
///
/// ## Replay Speed
///
/// Control replay speed with [speedMultiplier]:
///
/// ```dart
/// final phantom = Phantom(speedMultiplier: 2.0); // 2x speed
/// await phantom.replay(session);
/// ```
class Phantom {
  /// Whether to normalize positions based on screen size differences.
  ///
  /// When `true`, recorded positions are scaled proportionally to
  /// fit the current screen size. Defaults to `true`.
  final bool normalizePositions;

  /// Speed multiplier for replay timing.
  ///
  /// - `1.0` = real-time replay
  /// - `2.0` = double speed
  /// - `0.5` = half speed
  final double speedMultiplier;

  /// The [Shade] instance for text controller registry access.
  ///
  /// When set, Phantom directly sets text on registered
  /// [ShadeTextController]s during replay using [setValueSilently],
  /// bypassing the keyboard entirely. If no controller is registered
  /// for a given field, the [onTextInput] callback is used instead.
  final Shade? shade;

  /// Whether to suppress the soft keyboard during replay.
  ///
  /// When `true`, Phantom hides the keyboard after pointer events
  /// that precede text input, preventing the keyboard from flashing
  /// during replay. Defaults to `true`.
  final bool suppressKeyboard;

  /// Whether to intelligently wait for the UI to settle after
  /// pointer-up events (completed taps/gestures).
  ///
  /// When `true`, after each `pointerUp` event Phantom waits for
  /// pending frames and animations to finish before proceeding.
  /// This handles scenarios where:
  /// - An API call is in progress and the UI updates when it resolves
  /// - A dialog or banner appears asynchronously
  /// - A page transition animation is completing
  ///
  /// The wait times out after [settleTimeout] to prevent infinite hangs.
  /// Defaults to `false` for backward compatibility.
  final bool waitForSettled;

  /// Maximum time to wait for the UI to settle after a pointer-up event.
  ///
  /// Only used when [waitForSettled] is `true`. Defaults to 5 seconds.
  final Duration settleTimeout;

  /// Called before each imprint is dispatched.
  ///
  /// Useful for progress tracking. Receives the index and total count.
  void Function(int current, int total)? onProgress;

  /// Called when replay completes.
  void Function(PhantomResult result)? onComplete;

  /// Called if replay is cancelled.
  void Function()? onCancelled;

  /// Called when a text input imprint is encountered during replay.
  ///
  /// The app should update the appropriate text field's controller
  /// with the text from the imprint. Only called when no matching
  /// [ShadeTextController] is found in the [shade] registry.
  void Function(Imprint imprint)? onTextInput;

  /// Called when a text action imprint is encountered during replay.
  ///
  /// The app should perform the text input action (e.g., submit).
  void Function(Imprint imprint)? onTextAction;

  /// Called when a key event imprint is encountered during replay.
  ///
  /// The app can use this to simulate key input or update UI.
  void Function(Imprint imprint)? onKeyEvent;

  /// Whether to validate the current route during replay.
  ///
  /// When `true` and [shade] has a `getCurrentRoute` callback,
  /// Phantom checks the route after each pointer-up event. If the
  /// route has changed from the session's [ShadeSession.startRoute],
  /// the replay is stopped with [PhantomResult.routeChanged] set
  /// to `true`.
  ///
  /// This catches scenarios where an API response redirects the
  /// user (e.g., expired token → login page), making subsequent
  /// replay events invalid.
  final bool validateRoute;

  bool _isReplaying = false;
  bool _cancelRequested = false;

  /// Whether Phantom is currently replaying a session.
  bool get isReplaying => _isReplaying;

  /// Creates a [Phantom] replay engine.
  ///
  /// When [shade] is provided, Phantom uses the text controller
  /// registry to directly set text during replay without opening
  /// the keyboard:
  ///
  /// ```dart
  /// final phantom = Phantom(
  ///   shade: Colossus.instance.shade,
  ///   normalizePositions: true,
  ///   speedMultiplier: 1.0,
  /// );
  /// ```
  Phantom({
    this.normalizePositions = true,
    this.speedMultiplier = 1.0,
    this.shade,
    this.suppressKeyboard = true,
    this.waitForSettled = false,
    this.settleTimeout = const Duration(seconds: 5),
    this.validateRoute = true,
    this.onProgress,
    this.onComplete,
    this.onCancelled,
    this.onTextInput,
    this.onTextAction,
    this.onKeyEvent,
  }) : assert(speedMultiplier > 0, 'speedMultiplier must be positive');

  // -----------------------------------------------------------------------
  // Replay
  // -----------------------------------------------------------------------

  /// Replay a recorded [ShadeSession].
  ///
  /// Dispatches each [Imprint] as a synthetic pointer event through
  /// Flutter's gesture system, preserving relative timing between events.
  ///
  /// Returns a [PhantomResult] with replay statistics.
  ///
  /// ```dart
  /// final result = await phantom.replay(session);
  /// print('Replayed ${result.eventsDispatched} events');
  /// print('Duration: ${result.actualDuration}');
  /// ```
  Future<PhantomResult> replay(ShadeSession session) async {
    if (_isReplaying) {
      throw StateError('Phantom is already replaying a session.');
    }

    if (session.imprints.isEmpty) {
      return PhantomResult(
        sessionName: session.name,
        eventsDispatched: 0,
        eventsSkipped: 0,
        expectedDuration: Duration.zero,
        actualDuration: Duration.zero,
        wasNormalized: false,
        wasCancelled: false,
      );
    }

    _isReplaying = true;
    _cancelRequested = false;

    // Notify Shade that replay is active
    shade?.isReplaying = true;

    final replayStart = DateTime.now();
    var dispatched = 0;
    var skipped = 0;

    // Calculate normalization scale factors
    double scaleX = 1;
    double scaleY = 1;
    if (normalizePositions) {
      final view = PlatformDispatcher.instance.views.first;
      final currentSize = view.physicalSize / view.devicePixelRatio;
      if (session.screenWidth > 0 && session.screenHeight > 0) {
        scaleX = currentSize.width / session.screenWidth;
        scaleY = currentSize.height / session.screenHeight;
      }
    }

    final binding = GestureBinding.instance;

    for (var i = 0; i < session.imprints.length; i++) {
      if (_cancelRequested) {
        _isReplaying = false;
        _cancelRequested = false;
        shade?.isReplaying = false;
        onCancelled?.call();
        return PhantomResult(
          sessionName: session.name,
          eventsDispatched: dispatched,
          eventsSkipped: skipped,
          expectedDuration: session.duration,
          actualDuration: DateTime.now().difference(replayStart),
          wasNormalized: normalizePositions && (scaleX != 1 || scaleY != 1),
          wasCancelled: true,
        );
      }

      final imprint = session.imprints[i];

      // Wait for correct timing
      if (i > 0) {
        final prevTimestamp = session.imprints[i - 1].timestamp;
        final delay = imprint.timestamp - prevTimestamp;
        if (delay > Duration.zero) {
          final scaledDelay = delay * (1.0 / speedMultiplier);
          await Future<void>.delayed(scaledDelay);
        }
      } else if (imprint.timestamp > Duration.zero) {
        // Delay before the first event
        final scaledDelay = imprint.timestamp * (1.0 / speedMultiplier);
        await Future<void>.delayed(scaledDelay);
      }

      if (_cancelRequested) continue;

      // Dispatch based on imprint type
      if (_isPointerImprint(imprint)) {
        // Check if keyboard suppression should preemptively dismiss focus
        if (suppressKeyboard && _nextImprintIsText(i, session.imprints)) {
          // This pointer event precedes a text input — dismiss keyboard
          // to prevent the soft keyboard from flashing during replay
          FocusManager.instance.primaryFocus?.unfocus();
          _hideKeyboard();
        }

        // Build the synthetic pointer event
        final event = _buildPointerEvent(
          imprint,
          scaleX: scaleX,
          scaleY: scaleY,
        );

        if (event != null) {
          binding.handlePointerEvent(event);
          dispatched++;

          // Proactively suppress keyboard after dispatching a pointer
          // event when suppression is enabled
          if (suppressKeyboard && shade != null) {
            _hideKeyboard();
          }

          // Intelligent wait: after a tap completes (pointerUp),
          // wait for the UI to settle. This handles API responses,
          // dialog appearances, and animations completing before
          // the next interaction.
          if (waitForSettled && imprint.type == ImprintType.pointerUp) {
            await _waitForSettled();
          }

          // Route guard: after pointer-up events, check that the
          // route hasn't changed unexpectedly (e.g., API redirect).
          if (validateRoute && imprint.type == ImprintType.pointerUp) {
            final routeResult = _checkRouteValidity(
              session,
              dispatched: dispatched,
              skipped: skipped,
              replayStart: replayStart,
              scaleX: scaleX,
              scaleY: scaleY,
            );
            if (routeResult != null) return routeResult;
          }
        } else {
          skipped++;
        }
      } else if (_isKeyImprint(imprint)) {
        // Key event — notify via callback
        onKeyEvent?.call(imprint);
        dispatched++;
      } else if (imprint.type == ImprintType.textInput) {
        // Text input — try direct controller replay first
        final fieldId = imprint.fieldId;
        final controller = fieldId != null
            ? shade?.getTextController(fieldId)
            : null;

        if (controller != null) {
          // Direct text injection — no keyboard needed
          FocusManager.instance.primaryFocus?.unfocus();
          _hideKeyboard();
          controller.setValueSilently(
            TextEditingValue(
              text: imprint.text ?? '',
              selection: TextSelection(
                baseOffset: imprint.selectionBase ?? 0,
                extentOffset: imprint.selectionExtent ?? 0,
              ),
              composing: TextRange(
                start: imprint.composingBase ?? -1,
                end: imprint.composingExtent ?? -1,
              ),
            ),
          );
          dispatched++;
        } else {
          // Fallback to callback
          onTextInput?.call(imprint);
          dispatched++;
        }
      } else if (imprint.type == ImprintType.textAction) {
        // Text action — notify via callback
        onTextAction?.call(imprint);
        dispatched++;
      } else {
        skipped++;
      }

      onProgress?.call(i + 1, session.imprints.length);
    }

    _isReplaying = false;
    shade?.isReplaying = false;

    final result = PhantomResult(
      sessionName: session.name,
      eventsDispatched: dispatched,
      eventsSkipped: skipped,
      expectedDuration: session.duration,
      actualDuration: DateTime.now().difference(replayStart),
      wasNormalized: normalizePositions && (scaleX != 1 || scaleY != 1),
      wasCancelled: false,
    );

    onComplete?.call(result);
    return result;
  }

  /// Cancel an in-progress replay.
  ///
  /// The replay loop will stop at the next event boundary.
  void cancel() {
    if (_isReplaying) {
      _cancelRequested = true;
    }
  }

  // -----------------------------------------------------------------------
  // Route validation
  // -----------------------------------------------------------------------

  /// Check if the current route still matches the session's start route.
  ///
  /// Returns a [PhantomResult] with [PhantomResult.routeChanged] if the
  /// route has changed, or `null` if the route is still valid.
  PhantomResult? _checkRouteValidity(
    ShadeSession session, {
    required int dispatched,
    required int skipped,
    required DateTime replayStart,
    required double scaleX,
    required double scaleY,
  }) {
    if (session.startRoute == null) return null;
    final getCurrentRoute = shade?.getCurrentRoute;
    if (getCurrentRoute == null) return null;

    final currentRoute = getCurrentRoute();
    if (currentRoute == null) return null;
    if (currentRoute == session.startRoute) return null;

    // Route changed — stop replay
    _isReplaying = false;
    _cancelRequested = false;
    shade?.isReplaying = false;

    final result = PhantomResult(
      sessionName: session.name,
      eventsDispatched: dispatched,
      eventsSkipped: skipped,
      expectedDuration: session.duration,
      actualDuration: DateTime.now().difference(replayStart),
      wasNormalized: normalizePositions && (scaleX != 1 || scaleY != 1),
      wasCancelled: true,
      routeChanged: true,
      invalidRoute: currentRoute,
    );

    onComplete?.call(result);
    return result;
  }

  // -----------------------------------------------------------------------
  // Keyboard suppression
  // -----------------------------------------------------------------------

  /// Whether the next imprint after [index] is a text-related event.
  ///
  /// Used to preemptively dismiss keyboard focus before the pointer
  /// event that would focus a text field.
  bool _nextImprintIsText(int index, List<Imprint> imprints) {
    for (var i = index + 1; i < imprints.length; i++) {
      final next = imprints[i];
      if (next.type == ImprintType.textInput ||
          next.type == ImprintType.textAction) {
        return true;
      }
      // Stop looking if we hit another pointer down (new interaction)
      if (next.type == ImprintType.pointerDown) return false;
    }
    return false;
  }

  /// Hides the soft keyboard via platform channel.
  void _hideKeyboard() {
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  // -----------------------------------------------------------------------
  // Intelligent wait — settle detection
  // -----------------------------------------------------------------------

  /// Wait for the UI to reach an idle state (no pending frames,
  /// no active animations).
  ///
  /// This handles scenarios where a tap triggers an API call, a
  /// dialog, a page transition, or any async operation that
  /// produces frames. Phantom waits until the frame pipeline is
  /// quiet before proceeding to the next event.
  ///
  /// Times out after [settleTimeout] to prevent infinite hangs
  /// (e.g., looping animations, background timers).
  Future<void> _waitForSettled() async {
    // Give the tap a moment to trigger any reactions (setState,
    // navigator push, API call dispatch, etc.)
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final deadline = DateTime.now().add(settleTimeout);
    var idleFrames = 0;
    const requiredIdleFrames = 3;

    while (DateTime.now().isBefore(deadline) && !_cancelRequested) {
      final hasScheduled =
          SchedulerBinding.instance.hasScheduledFrame ||
          SchedulerBinding.instance.transientCallbackCount > 0;

      if (!hasScheduled) {
        idleFrames++;
        if (idleFrames >= requiredIdleFrames) {
          // UI has been idle for several checks — settled
          return;
        }
      } else {
        // Reset the counter — still busy
        idleFrames = 0;
      }

      // Wait one frame interval before checking again
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  // -----------------------------------------------------------------------
  // Event construction
  // -----------------------------------------------------------------------

  /// Builds a synthetic [PointerEvent] from an [Imprint].
  PointerEvent? _buildPointerEvent(
    Imprint imprint, {
    double scaleX = 1,
    double scaleY = 1,
  }) {
    final position = Offset(
      imprint.positionX * scaleX,
      imprint.positionY * scaleY,
    );
    final delta = Offset(imprint.deltaX * scaleX, imprint.deltaY * scaleY);
    final kind =
        PointerDeviceKind.values[imprint.deviceKind.clamp(
          0,
          PointerDeviceKind.values.length - 1,
        )];

    return switch (imprint.type) {
      ImprintType.pointerDown => PointerDownEvent(
        pointer: imprint.pointer,
        position: position,
        kind: kind,
        device: imprint.pointer,
        buttons: imprint.buttons,
        pressure: imprint.pressure,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerMove => PointerMoveEvent(
        pointer: imprint.pointer,
        position: position,
        delta: delta,
        kind: kind,
        device: imprint.pointer,
        buttons: imprint.buttons,
        pressure: imprint.pressure,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerUp => PointerUpEvent(
        pointer: imprint.pointer,
        position: position,
        kind: kind,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerCancel => PointerCancelEvent(
        pointer: imprint.pointer,
        position: position,
        kind: kind,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerHover => PointerHoverEvent(
        pointer: imprint.pointer,
        position: position,
        delta: delta,
        kind: kind,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerScroll => PointerScrollEvent(
        position: position,
        scrollDelta: Offset(
          imprint.scrollDeltaX * scaleX,
          imprint.scrollDeltaY * scaleY,
        ),
        kind: kind,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerAdded => PointerAddedEvent(
        pointer: imprint.pointer,
        position: position,
        kind: kind,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerRemoved => PointerRemovedEvent(
        pointer: imprint.pointer,
        position: position,
        kind: kind,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerPanZoomStart => PointerPanZoomStartEvent(
        pointer: imprint.pointer,
        position: position,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      ImprintType.pointerPanZoomEnd => PointerPanZoomEndEvent(
        pointer: imprint.pointer,
        position: position,
        device: imprint.pointer,
        timeStamp: imprint.timestamp,
      ),
      // PanZoomUpdate and ScrollInertiaCancel are synthesized — skip
      ImprintType.pointerPanZoomUpdate => null,
      ImprintType.pointerScrollInertiaCancel => null,
      // Key & text events are handled separately
      ImprintType.keyDown => null,
      ImprintType.keyUp => null,
      ImprintType.keyRepeat => null,
      ImprintType.textInput => null,
      ImprintType.textAction => null,
    };
  }

  /// Whether this imprint represents a pointer event.
  bool _isPointerImprint(Imprint imprint) {
    return switch (imprint.type) {
      ImprintType.pointerDown ||
      ImprintType.pointerMove ||
      ImprintType.pointerUp ||
      ImprintType.pointerCancel ||
      ImprintType.pointerHover ||
      ImprintType.pointerScroll ||
      ImprintType.pointerScrollInertiaCancel ||
      ImprintType.pointerAdded ||
      ImprintType.pointerRemoved ||
      ImprintType.pointerPanZoomStart ||
      ImprintType.pointerPanZoomUpdate ||
      ImprintType.pointerPanZoomEnd => true,
      _ => false,
    };
  }

  /// Whether this imprint represents a key event.
  bool _isKeyImprint(Imprint imprint) {
    return switch (imprint.type) {
      ImprintType.keyDown || ImprintType.keyUp || ImprintType.keyRepeat => true,
      _ => false,
    };
  }
}

// ---------------------------------------------------------------------------
// PhantomResult — Replay outcome
// ---------------------------------------------------------------------------

/// The result of a [Phantom] replay session.
///
/// Contains statistics about the replay — how many events were
/// dispatched, the actual duration, whether positions were normalized,
/// and whether the replay was cancelled.
///
/// ```dart
/// final result = await phantom.replay(session);
/// if (result.wasCancelled) {
///   print('Replay was cancelled after ${result.eventsDispatched} events');
/// } else {
///   print('Replay complete: ${result.eventsDispatched} events');
///   print('Expected: ${result.expectedDuration}');
///   print('Actual: ${result.actualDuration}');
/// }
/// ```
class PhantomResult {
  /// The name of the replayed session.
  final String sessionName;

  /// Number of events successfully dispatched.
  final int eventsDispatched;

  /// Number of events skipped (unsupported types).
  final int eventsSkipped;

  /// The original recording duration.
  final Duration expectedDuration;

  /// How long the replay actually took.
  final Duration actualDuration;

  /// Whether positions were normalized for screen size differences.
  final bool wasNormalized;

  /// Whether the replay was cancelled before completion.
  final bool wasCancelled;

  /// Whether the replay was stopped due to an unexpected route change.
  ///
  /// When `true`, the app navigated away from the expected route
  /// during replay (e.g., an API response triggered a redirect).
  /// Check [invalidRoute] for the detected route.
  final bool routeChanged;

  /// The unexpected route detected when [routeChanged] is `true`.
  ///
  /// `null` if the route did not change or could not be determined.
  final String? invalidRoute;

  /// Creates a [PhantomResult].
  const PhantomResult({
    required this.sessionName,
    required this.eventsDispatched,
    required this.eventsSkipped,
    required this.expectedDuration,
    required this.actualDuration,
    required this.wasNormalized,
    required this.wasCancelled,
    this.routeChanged = false,
    this.invalidRoute,
  });

  /// Total events in the session (dispatched + skipped).
  int get totalEvents => eventsDispatched + eventsSkipped;

  /// The speed ratio (actual / expected).
  ///
  /// Returns 0 if expected duration is zero.
  double get speedRatio {
    if (expectedDuration == Duration.zero) return 0;
    return actualDuration.inMicroseconds / expectedDuration.inMicroseconds;
  }

  /// Converts this result to a JSON-serializable map.
  Map<String, dynamic> toMap() => {
    'sessionName': sessionName,
    'eventsDispatched': eventsDispatched,
    'eventsSkipped': eventsSkipped,
    'expectedDurationUs': expectedDuration.inMicroseconds,
    'actualDurationUs': actualDuration.inMicroseconds,
    'wasNormalized': wasNormalized,
    'wasCancelled': wasCancelled,
    'routeChanged': routeChanged,
    if (invalidRoute != null) 'invalidRoute': invalidRoute,
    'speedRatio': speedRatio,
  };

  @override
  String toString() =>
      'PhantomResult($sessionName, '
      '$eventsDispatched/$totalEvents events, '
      '${actualDuration.inMilliseconds}ms'
      '${wasCancelled ? ' [CANCELLED]' : ''}'
      '${routeChanged ? ' [ROUTE_CHANGED: $invalidRoute]' : ''})';
}
