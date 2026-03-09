import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:titan_atlas/titan_atlas.dart' show Atlas;

import '../recording/glyph.dart';
import '../recording/tableau.dart';
import '../recording/tableau_capture.dart';
import '../recording/shade.dart';
import '../widgets/shade_text_controller.dart';
import 'stratagem.dart';
import 'verdict.dart';

// ---------------------------------------------------------------------------
// StratagemRunner — Execution Engine
// ---------------------------------------------------------------------------

/// **StratagemRunner** — executes a [Stratagem] against the live app.
///
/// For each step, the runner:
/// 1. Navigates to the Stratagem's `startRoute` (if set)
/// 2. Captures a [Tableau] (current screen state)
/// 3. Resolves the target [Glyph] by label/type
/// 4. Dispatches the action (tap, enter text, scroll, etc.)
/// 5. Waits for the UI to settle
/// 6. Validates expectations
/// 7. Records a [VerdictStep]
///
/// ## Why "StratagemRunner"?
///
/// The general who executes the battle plan. The Stratagem says
/// "tap Login", the Runner finds the button, dispatches the tap,
/// and reports whether the plan succeeded.
///
/// ## Usage
///
/// ```dart
/// final runner = StratagemRunner(shade: Colossus.instance.shade);
/// final verdict = await runner.execute(stratagem);
/// print(verdict.toReport());
/// ```
class StratagemRunner {
  /// The [Shade] instance for text controller access and route info.
  final Shade shade;

  /// Whether to capture screenshots at each step.
  final bool captureScreenshots;

  /// Default settle timeout for each step.
  final Duration defaultSettleTimeout;

  /// Default step timeout.
  final Duration defaultStepTimeout;

  /// Callback invoked after each step completes.
  final void Function(VerdictStep step)? onStepComplete;

  /// Optional callback to navigate to a route programmatically.
  ///
  /// When set, the runner calls this before executing a Stratagem's
  /// steps if the Stratagem has a non-null [Stratagem.startRoute].
  /// Also used by the [StratagemAction.navigate] action.
  ///
  /// The callback should push/replace to the given route and return
  /// a [Future] that completes once navigation settles. Typically
  /// provided by the application's router (e.g. Atlas / GoRouter).
  ///
  /// ```dart
  /// StratagemRunner(
  ///   shade: shade,
  ///   navigateToRoute: (route) async {
  ///     GoRouter.of(context).go(route);
  ///     await Future.delayed(Duration(milliseconds: 500));
  ///   },
  /// );
  /// ```
  final Future<void> Function(String route)? navigateToRoute;

  /// Optional auth [Stratagem] for automatic login handling.
  ///
  /// When set, the runner checks if the app is on the auth screen
  /// before each Stratagem execution by resolving the first step's
  /// target against the current [Tableau]. If found (auth screen
  /// detected), the runner executes the auth steps automatically,
  /// then re-navigates to the Stratagem's `startRoute`.
  ///
  /// The `authStratagem`'s first step target acts as the login
  /// detector — if that element is visible, auth is needed.
  ///
  /// ```dart
  /// StratagemRunner(
  ///   shade: shade,
  ///   authStratagem: Stratagem(
  ///     name: '_auth',
  ///     startRoute: '',
  ///     steps: [
  ///       StratagemStep(id: 1, action: StratagemAction.enterText,
  ///         target: StratagemTarget(label: 'Hero Name'),
  ///         value: 'Kael'),
  ///       StratagemStep(id: 2, action: StratagemAction.tap,
  ///         target: StratagemTarget(label: 'Enter the Questboard')),
  ///     ],
  ///   ),
  /// );
  /// ```
  final Stratagem? authStratagem;

  /// Pointer ID counter for synthetic events.
  int _pointerCounter = 200;

  /// Errors captured during execution via FlutterError hook.
  final List<String> _capturedErrors = [];

  /// Original FlutterError handler (restored after execution).
  void Function(FlutterErrorDetails)? _originalErrorHandler;

  /// Creates a [StratagemRunner].
  StratagemRunner({
    required this.shade,
    this.captureScreenshots = false,
    this.defaultSettleTimeout = const Duration(seconds: 2),
    this.defaultStepTimeout = const Duration(seconds: 10),
    this.onStepComplete,
    this.navigateToRoute,
    this.authStratagem,
  });

  // -----------------------------------------------------------------------
  // Execution
  // -----------------------------------------------------------------------

  /// Execute a [Stratagem] and return the [Verdict].
  ///
  /// Walks through each step, dispatching actions and validating
  /// expectations. Captures screen state at each step via [Tableau].
  Future<Verdict> execute(Stratagem stratagem) async {
    final executedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final verdictSteps = <VerdictStep>[];
    final tableaux = <Tableau>[];
    _capturedErrors.clear();
    bool aborted = false;

    // Hook into FlutterError for API/exception detection
    _installErrorHook();

    // Total execution deadline
    final deadline = DateTime.now().add(stratagem.timeout);

    try {
      // Navigate to startRoute before executing steps
      if (navigateToRoute != null && stratagem.startRoute.isNotEmpty) {
        try {
          await navigateToRoute!(stratagem.startRoute);
          await _waitForSettle(defaultSettleTimeout);
        } catch (e) {
          // Navigation failed — record and continue with current screen
          _capturedErrors.add('startRoute navigation failed: $e');
        }
      }

      // Auth detection: check if auth screen is showing and handle it
      if (authStratagem != null && authStratagem!.steps.isNotEmpty) {
        final authNeeded = await _detectAuthScreen();
        if (authNeeded) {
          await _executeAuthSteps(stratagem);
        }
      }

      for (final step in stratagem.steps) {
        // Check total timeout
        if (DateTime.now().isAfter(deadline)) {
          aborted = true;
        }

        if (aborted) {
          verdictSteps.add(
            VerdictStep.skipped(stepId: step.id, description: step.description),
          );
          continue;
        }

        final verdictStep = await _executeStep(step, stratagem);
        verdictSteps.add(verdictStep);
        onStepComplete?.call(verdictStep);

        // Collect tableau from the step
        if (verdictStep.tableau != null) {
          tableaux.add(verdictStep.tableau!);
        }

        // Check failure policy
        if (verdictStep.status == VerdictStepStatus.failed) {
          if (stratagem.failurePolicy == StratagemFailurePolicy.abortOnFirst) {
            aborted = true;
          }
        }
      }
    } finally {
      _restoreErrorHook();
    }

    stopwatch.stop();

    return Verdict.fromSteps(
      stratagemName: stratagem.name,
      executedAt: executedAt,
      duration: stopwatch.elapsed,
      steps: verdictSteps,
      performance: const VerdictPerformance(),
      tableaux: tableaux,
    );
  }

  // -----------------------------------------------------------------------
  // Step execution
  // -----------------------------------------------------------------------

  /// Execute a single [StratagemStep] and return the [VerdictStep].
  Future<VerdictStep> _executeStep(
    StratagemStep step,
    Stratagem stratagem,
  ) async {
    final stepStopwatch = Stopwatch()..start();

    try {
      // 1. Capture current screen
      final preTableau = await TableauCapture.capture(
        index: step.id,
        enableScreenCapture: captureScreenshots,
      );

      // 2. Resolve target (if action needs one)
      Glyph? resolvedTarget;
      if (actionNeedsTarget(step.action) && step.target != null) {
        resolvedTarget = step.target!.fuzzyResolve(preTableau);
        if (resolvedTarget == null) {
          stepStopwatch.stop();
          return VerdictStep.failed(
            stepId: step.id,
            description: step.description,
            duration: stepStopwatch.elapsed,
            tableau: preTableau,
            failure: VerdictFailure(
              type: VerdictFailureType.targetNotFound,
              message:
                  'Could not find ${targetDescription(step.target!)} '
                  'on screen',
              suggestions: VerdictFailure.generateSuggestions(
                type: VerdictFailureType.targetNotFound,
                tableau: preTableau,
                target: step.target,
              ),
            ),
          );
        }

        // Check if target is interactive for interaction actions
        if (actionRequiresInteractive(step.action) &&
            !resolvedTarget.isInteractive) {
          stepStopwatch.stop();
          return VerdictStep.failed(
            stepId: step.id,
            description: step.description,
            duration: stepStopwatch.elapsed,
            tableau: preTableau,
            resolvedTarget: resolvedTarget,
            failure: VerdictFailure(
              type: VerdictFailureType.notInteractive,
              message:
                  '${targetDescription(step.target!)} found but '
                  'is not interactive',
              suggestions: VerdictFailure.generateSuggestions(
                type: VerdictFailureType.notInteractive,
                tableau: preTableau,
                target: step.target,
              ),
            ),
          );
        }
      }

      // 3. Execute the action
      await _dispatchAction(step, resolvedTarget, stratagem);

      // 4. Wait for settle
      final settleTime = step.waitAfter ?? defaultSettleTimeout;
      await _waitForSettle(settleTime);

      // Honor expectations.settleTimeout if specified
      if (step.expectations?.settleTimeout != null) {
        await _waitForSettle(step.expectations!.settleTimeout!);
      }

      // 5. Capture post-action screen
      final postTableau = await TableauCapture.capture(
        index: step.id,
        enableScreenCapture: captureScreenshots,
      );

      // 6. Validate expectations
      final failure = validateExpectations(
        step.expectations,
        postTableau,
        stratagem,
      );

      stepStopwatch.stop();

      if (failure != null) {
        return VerdictStep.failed(
          stepId: step.id,
          description: step.description,
          duration: stepStopwatch.elapsed,
          tableau: postTableau,
          resolvedTarget: resolvedTarget,
          failure: failure,
        );
      }

      return VerdictStep.passed(
        stepId: step.id,
        description: step.description,
        duration: stepStopwatch.elapsed,
        tableau: postTableau,
        resolvedTarget: resolvedTarget,
      );
    } on TimeoutException {
      stepStopwatch.stop();
      return VerdictStep.failed(
        stepId: step.id,
        description: step.description,
        duration: stepStopwatch.elapsed,
        failure: const VerdictFailure(
          type: VerdictFailureType.timeout,
          message: 'Step timed out',
          suggestions: [
            'Increase the step timeout or waitAfter duration',
            'Check if an async operation is hanging',
          ],
        ),
      );
    } catch (e) {
      stepStopwatch.stop();
      return VerdictStep.failed(
        stepId: step.id,
        description: step.description,
        duration: stepStopwatch.elapsed,
        failure: VerdictFailure(
          type: VerdictFailureType.exception,
          message: 'Exception: $e',
          suggestions: const ['Check the app logs for error details'],
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Action dispatch
  // -----------------------------------------------------------------------

  /// Dispatch the action for a step.
  Future<void> _dispatchAction(
    StratagemStep step,
    Glyph? target,
    Stratagem stratagem,
  ) async {
    switch (step.action) {
      case StratagemAction.tap:
        await _dispatchTap(target!.centerX, target.centerY);

      case StratagemAction.doubleTap:
        await _dispatchTap(target!.centerX, target.centerY);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _dispatchTap(target.centerX, target.centerY);

      case StratagemAction.longPress:
        await _dispatchLongPress(target!.centerX, target.centerY);

      case StratagemAction.enterText:
        // Tap to focus, then inject text
        await _dispatchTap(target!.centerX, target.centerY);
        final text = stratagem.interpolate(step.value ?? '');
        await _injectText(
          text,
          clearFirst: step.clearFirst ?? true,
          targetX: target.centerX,
          targetY: target.centerY,
        );

      case StratagemAction.clearText:
        await _dispatchTap(target!.centerX, target.centerY);
        await _injectText(
          '',
          clearFirst: true,
          targetX: target.centerX,
          targetY: target.centerY,
        );

      case StratagemAction.submitField:
        // Trigger text input action (done/next/go)
        ServicesBinding.instance.channelBuffers.push(
          'flutter/textinput',
          const JSONMethodCodec()
              .encodeMethodCall(
                const MethodCall('TextInputClient.performAction', [
                  0,
                  'TextInputAction.done',
                ]),
              )
              .buffer
              .asByteData(),
          (_) {},
        );

      case StratagemAction.scroll:
        // Default: scroll DOWN (positive dy in PointerScrollEvent =
        // increase scroll offset = content moves up = see below content).
        final delta = step.scrollDelta ?? const Offset(0, 300);
        // Scroll at center of screen if no target
        final center = screenCenter;
        final x = target?.centerX ?? center.dx;
        final y = target?.centerY ?? center.dy;
        await _dispatchScroll(x, y, delta.dx, delta.dy);

      case StratagemAction.scrollUntilVisible:
        await _scrollUntilVisible(
          step.target!,
          step.scrollDelta ?? const Offset(0, 300),
          maxAttempts: step.repeatCount ?? 10,
        );

      case StratagemAction.swipe:
        final direction = step.swipeDirection ?? 'left';
        final distance = step.swipeDistance ?? 300;
        await _dispatchSwipe(
          target!.centerX,
          target.centerY,
          direction,
          distance,
        );

      case StratagemAction.drag:
        // Two modes:
        // 1) Explicit coordinates: dragFrom + dragTo
        // 2) Target-based: resolve target center as dragFrom, use dragTo
        final from =
            step.dragFrom ??
            (target != null ? Offset(target.centerX, target.centerY) : null);
        final to = step.dragTo;
        if (from != null && to != null) {
          await _dispatchDrag(from, to);
        }

      case StratagemAction.toggleSwitch:
      case StratagemAction.toggleCheckbox:
      case StratagemAction.selectRadio:
      case StratagemAction.selectSegment:
        // All toggles are just taps on the element
        await _dispatchTap(target!.centerX, target.centerY);

      case StratagemAction.adjustSlider:
        if (target != null && step.value != null) {
          await _adjustSlider(target, step.value!, step.sliderRange);
        }

      case StratagemAction.selectDropdown:
        // 1) Tap dropdown to open
        await _dispatchTap(target!.centerX, target.centerY);
        await _waitForSettle(const Duration(milliseconds: 500));
        // 2) Capture overlay and find item
        final overlayTableau = await TableauCapture.capture(index: step.id);
        final itemValue = stratagem.interpolate(step.value ?? '');
        final itemTarget = StratagemTarget(label: itemValue);
        final item = itemTarget.fuzzyResolve(overlayTableau);
        if (item != null) {
          await _dispatchTap(item.centerX, item.centerY);
        }

      case StratagemAction.selectDate:
        // Tap the date field, then simulated date selection
        await _dispatchTap(target!.centerX, target.centerY);
        await _waitForSettle(const Duration(milliseconds: 500));
        // Date picker is complex — tap OK after the picker opens
        // A full implementation would navigate the picker calendar
        final pickerTableau = await TableauCapture.capture(index: step.id);
        final okButton = const StratagemTarget(
          label: 'OK',
        ).fuzzyResolve(pickerTableau);
        if (okButton != null) {
          await _dispatchTap(okButton.centerX, okButton.centerY);
        }

      case StratagemAction.navigate:
        // Programmatic navigation via the navigateToRoute callback
        // or Atlas.go as the default.
        final route = stratagem.interpolate(step.value ?? '');
        if (navigateToRoute != null && route.isNotEmpty) {
          await navigateToRoute!(route);
        } else if (route.isNotEmpty) {
          try {
            Atlas.go(route);
          } catch (_) {
            // Atlas not initialized — fall back to Navigator
            final navigator = _findNavigator();
            if (navigator != null) {
              navigator.pushNamed(route);
            }
          }
        }

      case StratagemAction.back:
        // Use Atlas.back when available, fall back to Navigator.pop
        try {
          if (Atlas.canBack) {
            Atlas.back();
          } else {
            final navigator = _findNavigator();
            if (navigator != null && navigator.canPop()) {
              navigator.pop();
            }
          }
        } catch (_) {
          final navigator = _findNavigator();
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          }
        }

      case StratagemAction.wait:
        await Future<void>.delayed(
          step.waitAfter ?? const Duration(seconds: 1),
        );

      case StratagemAction.waitForElement:
        await _waitForElement(step.target!, step.timeout ?? defaultStepTimeout);

      case StratagemAction.waitForElementGone:
        await _waitForElementGone(
          step.target!,
          step.timeout ?? defaultStepTimeout,
        );

      case StratagemAction.verify:
        // No action — just validate expectations (handled after dispatch)
        break;

      case StratagemAction.dismissKeyboard:
        FocusManager.instance.primaryFocus?.unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

      case StratagemAction.pressKey:
        // Dispatch a key event via the key event system
        if (step.keyId != null) {
          await _dispatchKeyEvent(step.keyId!);
        }
    }
  }

  // -----------------------------------------------------------------------
  // Pointer dispatch helpers
  // -----------------------------------------------------------------------

  /// Dispatch a tap (pointerDown + pointerUp) at the given position.
  Future<void> _dispatchTap(double x, double y) async {
    final pointer = _pointerCounter++;
    final position = Offset(x, y);
    final binding = GestureBinding.instance;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 16));

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  /// Dispatch a long press (~500ms hold).
  Future<void> _dispatchLongPress(double x, double y) async {
    final pointer = _pointerCounter++;
    final position = Offset(x, y);
    final binding = GestureBinding.instance;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 550));

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  /// Dispatch a scroll event at the given position.
  Future<void> _dispatchScroll(double x, double y, double dx, double dy) async {
    final binding = GestureBinding.instance;

    binding.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(x, y),
        scrollDelta: Offset(dx, dy),
        kind: PointerDeviceKind.mouse,
        device: _pointerCounter++,
      ),
    );
  }

  /// Dispatch a swipe gesture.
  Future<void> _dispatchSwipe(
    double x,
    double y,
    String direction,
    double distance,
  ) async {
    final pointer = _pointerCounter++;
    final binding = GestureBinding.instance;
    final start = Offset(x, y);

    final end = switch (direction) {
      'left' => Offset(x - distance, y),
      'right' => Offset(x + distance, y),
      'up' => Offset(x, y - distance),
      'down' => Offset(x, y + distance),
      _ => Offset(x - distance, y),
    };

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: start,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    // Animate the drag with intermediate points
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final pos = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: pos,
          delta: Offset(
            (end.dx - start.dx) / steps,
            (end.dy - start.dy) / steps,
          ),
          kind: PointerDeviceKind.touch,
          device: pointer,
          buttons: kPrimaryButton,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: end,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  /// Dispatch a drag from one point to another.
  Future<void> _dispatchDrag(Offset from, Offset to) async {
    final pointer = _pointerCounter++;
    final binding = GestureBinding.instance;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: from,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final pos = Offset(
        from.dx + (to.dx - from.dx) * t,
        from.dy + (to.dy - from.dy) * t,
      );
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: pos,
          delta: Offset((to.dx - from.dx) / steps, (to.dy - from.dy) / steps),
          kind: PointerDeviceKind.touch,
          device: pointer,
          buttons: kPrimaryButton,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: to,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  /// Adjust a slider to a target value.
  Future<void> _adjustSlider(
    Glyph slider,
    String value,
    Map<String, double>? range,
  ) async {
    final targetValue = double.tryParse(value);
    if (targetValue == null) return;

    final min = range?['min'] ?? 0;
    final max = range?['max'] ?? 100;
    if (max <= min) return;

    // Calculate target position within the slider track
    final ratio = (targetValue - min) / (max - min);
    final targetX = slider.left + slider.width * ratio;
    final centerY = slider.centerY;

    // Drag from current thumb position (center) to target
    await _dispatchDrag(
      Offset(slider.centerX, centerY),
      Offset(targetX, centerY),
    );
  }

  // -----------------------------------------------------------------------
  // Text injection
  // -----------------------------------------------------------------------

  /// Inject text into the focused (or position-matched) text field.
  ///
  /// Uses a three-strategy approach:
  /// 1. **FocusManager** — wait for focus to establish after the tap,
  ///    then traverse ancestors to find the [EditableText] controller.
  /// 2. **Position-based lookup** — walk the element tree to find an
  ///    [EditableText] whose render box contains ([targetX], [targetY]).
  ///    This works even when the tap doesn't establish focus (e.g. on
  ///    macOS desktop where touch events may not trigger text field focus).
  /// 3. **ShadeTextController registry** — single-controller shortcut
  ///    when exactly one controller is registered.
  ///
  /// Throws [StateError] if no controller is found.
  Future<void> _injectText(
    String text, {
    bool clearFirst = true,
    double? targetX,
    double? targetY,
  }) async {
    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    // Strategy 1: Poll for focus to be established after the tap.
    TextEditingController? controller;
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final focus = FocusManager.instance.primaryFocus;
      if (focus?.context != null) {
        focus!.context!.visitAncestorElements((element) {
          if (element.widget is EditableText) {
            controller = (element.widget as EditableText).controller;
            return false;
          }
          return true;
        });
        if (controller != null) break;
      }
    }

    // Strategy 2: Position-based lookup — find EditableText at tap position
    if (controller == null && targetX != null && targetY != null) {
      controller = _findControllerAtPosition(targetX, targetY);
    }

    // Strategy 3: ShadeTextController registry (single-controller shortcut)
    if (controller == null) {
      final controllers = shade.textControllers.values;
      if (controllers.length == 1) {
        controller = controllers.first;
      }
    }

    if (controller == null) {
      throw StateError(
        'Text injection failed: could not find a TextEditingController. '
        'primaryFocus: ${FocusManager.instance.primaryFocus}, '
        'shadeControllers: ${shade.textControllers.length}',
      );
    }

    _applyTextValue(controller!, value, clearFirst: clearFirst);
  }

  /// Find a [TextEditingController] from an [EditableText] widget whose
  /// render box contains the given screen coordinates.
  ///
  /// Walks the entire element tree looking for [EditableText] widgets,
  /// then checks if their rendered position contains the point. This is
  /// the most reliable approach as it doesn't depend on focus state or
  /// the ShadeTextController registry.
  TextEditingController? _findControllerAtPosition(double x, double y) {
    final point = Offset(x, y);
    TextEditingController? result;

    void visit(Element element) {
      if (result != null) return;
      if (element.widget is EditableText) {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox && renderObject.hasSize) {
          final position = renderObject.localToGlobal(Offset.zero);
          final bounds = position & renderObject.size;
          if (bounds.contains(point)) {
            result = (element.widget as EditableText).controller;
            return;
          }
        }
      }
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    root?.visitChildren(visit);
    return result;
  }

  /// Apply a [TextEditingValue] to a controller, using
  /// [ShadeTextController.setValueSilently] when available to avoid
  /// recording the injected text as a user interaction.
  void _applyTextValue(
    TextEditingController controller,
    TextEditingValue value, {
    bool clearFirst = true,
  }) {
    if (controller is ShadeTextController) {
      if (clearFirst) {
        controller.setValueSilently(
          const TextEditingValue(
            text: '',
            selection: TextSelection.collapsed(offset: 0),
          ),
        );
      }
      controller.setValueSilently(value);
    } else {
      if (clearFirst) {
        controller.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
      controller.value = value;
    }
  }

  /// Dispatch a key event based on a key identifier string.
  ///
  /// Supports common key names: `enter`, `tab`, `escape`, `backspace`,
  /// `delete`, `space`, and single characters.
  Future<void> _dispatchKeyEvent(String keyId) async {
    final keyCode = keyCodeFromId(keyId);

    ServicesBinding.instance.channelBuffers.push(
      'flutter/keyevent',
      const JSONMethodCodec()
          .encodeMethodCall(
            MethodCall('keydown', <String, dynamic>{
              'type': 'keydown',
              'keymap': 'android',
              'keyCode': keyCode,
              'plainCodePoint': keyCode < 128 ? keyCode : 0,
              'scanCode': keyCode,
              'metaState': 0,
              'source': 0,
              'deviceId': 0,
            }),
          )
          .buffer
          .asByteData(),
      (_) {},
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));

    ServicesBinding.instance.channelBuffers.push(
      'flutter/keyevent',
      const JSONMethodCodec()
          .encodeMethodCall(
            MethodCall('keyup', <String, dynamic>{
              'type': 'keyup',
              'keymap': 'android',
              'keyCode': keyCode,
              'plainCodePoint': keyCode < 128 ? keyCode : 0,
              'scanCode': keyCode,
              'metaState': 0,
              'source': 0,
              'deviceId': 0,
            }),
          )
          .buffer
          .asByteData(),
      (_) {},
    );
  }

  /// Map a key name to an Android key code.
  @visibleForTesting
  static int keyCodeFromId(String keyId) {
    return switch (keyId.toLowerCase()) {
      'enter' || 'return' => 66,
      'tab' => 61,
      'escape' || 'esc' => 111,
      'backspace' => 67,
      'delete' || 'del' => 112,
      'space' => 62,
      'up' || 'arrowup' => 19,
      'down' || 'arrowdown' => 20,
      'left' || 'arrowleft' => 21,
      'right' || 'arrowright' => 22,
      'home' => 122,
      'end' => 123,
      'pageup' => 92,
      'pagedown' => 93,
      _ when keyId.length == 1 => keyId.codeUnitAt(0),
      _ => 0,
    };
  }

  // -----------------------------------------------------------------------
  // Scroll until visible
  // -----------------------------------------------------------------------

  /// Scroll until the target element appears on screen.
  Future<void> _scrollUntilVisible(
    StratagemTarget target,
    Offset scrollDelta, {
    int maxAttempts = 10,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final tableau = await TableauCapture.capture(index: attempt);
      final glyph = target.fuzzyResolve(tableau);
      if (glyph != null) return; // Found!

      // Scroll from screen center
      final center = screenCenter;
      await _dispatchScroll(
        center.dx,
        center.dy,
        scrollDelta.dx,
        scrollDelta.dy,
      );
      await _waitForSettle(const Duration(milliseconds: 300));
    }

    // Not found after max attempts — step will fail when target is resolved
  }

  // -----------------------------------------------------------------------
  // Wait for element / element gone
  // -----------------------------------------------------------------------

  /// Wait until an element matching [target] appears on screen.
  Future<void> _waitForElement(StratagemTarget target, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final tableau = await TableauCapture.capture(index: 0);
      if (target.fuzzyResolve(tableau) != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException(
      'Element ${targetDescription(target)} did not appear',
      timeout,
    );
  }

  /// Wait until an element matching [target] disappears from screen.
  Future<void> _waitForElementGone(
    StratagemTarget target,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final tableau = await TableauCapture.capture(index: 0);
      if (target.fuzzyResolve(tableau) == null) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException(
      'Element ${targetDescription(target)} did not disappear',
      timeout,
    );
  }

  // -----------------------------------------------------------------------
  // Expectation validation
  // -----------------------------------------------------------------------

  /// Validate step expectations against the post-action screen state.
  @visibleForTesting
  VerdictFailure? validateExpectations(
    StratagemExpectations? expectations,
    Tableau tableau,
    Stratagem stratagem,
  ) {
    if (expectations == null) return null;

    // Check route
    if (expectations.route != null) {
      final expectedRoute = stratagem.interpolate(expectations.route!);
      if (tableau.route != expectedRoute) {
        return VerdictFailure(
          type: VerdictFailureType.wrongRoute,
          message:
              'Expected route "$expectedRoute" but found '
              '"${tableau.route}"',
          expected: expectedRoute,
          actual: tableau.route,
          suggestions: VerdictFailure.generateSuggestions(
            type: VerdictFailureType.wrongRoute,
            tableau: tableau,
            expectedRoute: expectedRoute,
          ),
        );
      }
    }

    // Check elements present
    if (expectations.elementsPresent != null) {
      for (final target in expectations.elementsPresent!) {
        if (target.fuzzyResolve(tableau) == null) {
          return VerdictFailure(
            type: VerdictFailureType.elementMissing,
            message:
                'Expected element ${targetDescription(target)} '
                'not found on screen',
            expected: targetDescription(target),
            actual: 'Not visible on route ${tableau.route}',
            suggestions: VerdictFailure.generateSuggestions(
              type: VerdictFailureType.elementMissing,
              tableau: tableau,
              target: target,
            ),
          );
        }
      }
    }

    // Check elements absent
    if (expectations.elementsAbsent != null) {
      for (final target in expectations.elementsAbsent!) {
        if (target.fuzzyResolve(tableau) != null) {
          return VerdictFailure(
            type: VerdictFailureType.elementUnexpected,
            message:
                'Element ${targetDescription(target)} should be '
                'absent but was found on screen',
            expected: '${targetDescription(target)} absent',
            actual: '${targetDescription(target)} present',
            suggestions: VerdictFailure.generateSuggestions(
              type: VerdictFailureType.elementUnexpected,
              tableau: tableau,
              target: target,
            ),
          );
        }
      }
    }

    // Check element states
    if (expectations.elementStates != null) {
      for (final expected in expectations.elementStates!) {
        final searchTarget = StratagemTarget(
          label: expected.label,
          type: expected.type,
        );
        final glyph = searchTarget.fuzzyResolve(tableau);
        if (glyph == null) {
          return VerdictFailure(
            type: VerdictFailureType.elementMissing,
            message:
                'Element "${expected.label}" not found for '
                'state check',
          );
        }

        if (expected.enabled != null && glyph.isEnabled != expected.enabled) {
          return VerdictFailure(
            type: VerdictFailureType.wrongState,
            message:
                '"${expected.label}" expected '
                '${expected.enabled! ? "enabled" : "disabled"} '
                'but was ${glyph.isEnabled ? "enabled" : "disabled"}',
            expected: expected.enabled! ? 'enabled' : 'disabled',
            actual: glyph.isEnabled ? 'enabled' : 'disabled',
          );
        }

        if (expected.value != null && glyph.currentValue != expected.value) {
          return VerdictFailure(
            type: VerdictFailureType.wrongState,
            message:
                '"${expected.label}" expected value '
                '"${expected.value}" but was "${glyph.currentValue}"',
            expected: expected.value,
            actual: glyph.currentValue,
          );
        }
      }
    }

    // Check for API errors captured during step
    if (_capturedErrors.isNotEmpty) {
      final error = _capturedErrors.first;
      _capturedErrors.clear();
      return VerdictFailure(
        type: VerdictFailureType.apiError,
        message: 'Error detected during step: $error',
        suggestions: const ['Check the app logs for error details'],
      );
    }

    return null;
  }

  // -----------------------------------------------------------------------
  // Auth detection & handling
  // -----------------------------------------------------------------------

  /// Detect whether the auth screen is currently showing.
  ///
  /// Captures a [Tableau] and checks if the [authStratagem]'s first
  /// step target resolves. If found, the app is on the auth screen
  /// (e.g., login page) and auth handling is needed.
  Future<bool> _detectAuthScreen() async {
    if (authStratagem == null || authStratagem!.steps.isEmpty) return false;

    final firstStep = authStratagem!.steps.first;
    if (firstStep.target == null) return false;

    final tableau = await TableauCapture.capture(
      index: -1,
      enableScreenCapture: false,
    );

    final resolved = firstStep.target!.fuzzyResolve(tableau);
    return resolved != null;
  }

  /// Execute the [authStratagem]'s steps inline, then re-navigate
  /// to the original Stratagem's `startRoute`.
  ///
  /// Auth steps run silently — their [VerdictStep] results are not
  /// included in the main Verdict. If a step fails, a captured
  /// error is recorded but execution continues.
  Future<void> _executeAuthSteps(Stratagem originalStratagem) async {
    final auth = authStratagem!;

    for (final step in auth.steps) {
      try {
        await _executeStep(step, auth);
      } catch (e) {
        _capturedErrors.add('auth step ${step.id} failed: $e');
      }
    }

    // Allow the auth transition to settle
    await _waitForSettle(defaultSettleTimeout);

    // Re-navigate to the original Stratagem's startRoute
    if (navigateToRoute != null && originalStratagem.startRoute.isNotEmpty) {
      try {
        await navigateToRoute!(originalStratagem.startRoute);
        await _waitForSettle(defaultSettleTimeout);
      } catch (e) {
        _capturedErrors.add('Post-auth startRoute navigation failed: $e');
      }
    }
  }

  // -----------------------------------------------------------------------
  // Error hooking
  // -----------------------------------------------------------------------

  /// Install a FlutterError hook to capture errors during execution.
  void _installErrorHook() {
    _originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _capturedErrors.add(details.exceptionAsString());
      // Also forward to original handler
      _originalErrorHandler?.call(details);
    };
  }

  /// Restore the original FlutterError handler.
  void _restoreErrorHook() {
    FlutterError.onError = _originalErrorHandler;
    _originalErrorHandler = null;
  }

  // -----------------------------------------------------------------------
  // Settle detection
  // -----------------------------------------------------------------------

  /// Wait for the UI to settle (no pending frames, animations done).
  Future<void> _waitForSettle(Duration maxWait) async {
    final deadline = DateTime.now().add(maxWait);
    int idleFrames = 0;
    const requiredIdleFrames = 3;

    while (DateTime.now().isBefore(deadline)) {
      final hasFrameScheduled = SchedulerBinding.instance.hasScheduledFrame;

      if (!hasFrameScheduled) {
        idleFrames++;
        if (idleFrames >= requiredIdleFrames) return;
      } else {
        idleFrames = 0;
      }

      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  // -----------------------------------------------------------------------
  // Navigation helpers
  // -----------------------------------------------------------------------

  /// Try to find the nearest [NavigatorState].
  NavigatorState? _findNavigator() {
    final context = WidgetsBinding.instance.rootElement;
    if (context == null) return null;

    NavigatorState? navigator;
    void visitor(Element element) {
      if (element is StatefulElement && element.state is NavigatorState) {
        navigator = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visitor);
    }

    visitor(context);
    return navigator;
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// The center of the screen, derived from the current render view size.
  @visibleForTesting
  Offset get screenCenter {
    final views = WidgetsBinding.instance.renderViews;
    if (views.isNotEmpty) {
      final size = views.first.size;
      return Offset(size.width / 2, size.height / 2);
    }
    // Fallback for headless / test environments
    return const Offset(200, 400);
  }

  /// Whether an action requires a target element.
  @visibleForTesting
  bool actionNeedsTarget(StratagemAction action) {
    return switch (action) {
      StratagemAction.tap => true,
      StratagemAction.doubleTap => true,
      StratagemAction.longPress => true,
      StratagemAction.enterText => true,
      StratagemAction.clearText => true,
      StratagemAction.toggleSwitch => true,
      StratagemAction.toggleCheckbox => true,
      StratagemAction.selectRadio => true,
      StratagemAction.adjustSlider => true,
      StratagemAction.selectDropdown => true,
      StratagemAction.selectDate => true,
      StratagemAction.selectSegment => true,
      StratagemAction.swipe => true,
      StratagemAction.drag => true,
      StratagemAction.scrollUntilVisible => false,
      _ => false,
    };
  }

  /// Whether an action requires the target to be interactive.
  @visibleForTesting
  bool actionRequiresInteractive(StratagemAction action) {
    return switch (action) {
      StratagemAction.tap => true,
      StratagemAction.doubleTap => true,
      StratagemAction.longPress => true,
      StratagemAction.enterText => true,
      StratagemAction.clearText => true,
      StratagemAction.toggleSwitch => true,
      StratagemAction.toggleCheckbox => true,
      StratagemAction.selectRadio => true,
      StratagemAction.adjustSlider => true,
      StratagemAction.selectDropdown => true,
      StratagemAction.selectDate => true,
      StratagemAction.selectSegment => true,
      StratagemAction.drag => true,
      _ => false,
    };
  }

  /// Build a human-readable description of a target.
  @visibleForTesting
  String targetDescription(StratagemTarget target) {
    final parts = <String>[];
    if (target.label != null) parts.add('"${target.label}"');
    if (target.type != null) parts.add('(${target.type})');
    if (target.key != null) parts.add('[key: ${target.key}]');
    return parts.isEmpty ? 'unknown target' : parts.join(' ');
  }
}
