import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:titan/titan.dart';

import 'beacon.dart';

/// **AnimatedVestige** — A Pillar consumer with implicit animation support.
///
/// Combines Pillar resolution (like [Vestige]) with an [AnimationController]
/// that runs a forward animation on every state change. Use the
/// [Animation] in the builder to create smooth transitions.
///
/// This is Titan's equivalent of implicit animation widgets, but driven
/// by reactive state changes rather than manual setState calls.
///
/// ## Usage
///
/// ```dart
/// AnimatedVestige<ThemePillar>(
///   duration: Duration(milliseconds: 500),
///   builder: (context, theme, animation) => FadeTransition(
///     opacity: animation,
///     child: Container(color: theme.primaryColor.value),
///   ),
/// )
/// ```
///
/// ## Selective Animation
///
/// Use [animateWhen] to only animate on specific changes:
///
/// ```dart
/// AnimatedVestige<CounterPillar>(
///   animateWhen: (counter) => counter.count.value > 10,
///   builder: (context, counter, animation) => Transform.scale(
///     scale: 1.0 + animation.value * 0.2,
///     child: Text('${counter.count.value}'),
///   ),
/// )
/// ```
class AnimatedVestige<P extends Pillar> extends StatefulWidget {
  /// Builds the widget with the Pillar and current animation value.
  final Widget Function(
    BuildContext context,
    P pillar,
    Animation<double> animation,
  )
  builder;

  /// Animation duration. Defaults to 300ms.
  final Duration duration;

  /// Animation curve. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Optional condition — animation only triggers when this returns `true`.
  ///
  /// Called on every state change. If null, every change triggers animation.
  final bool Function(P pillar)? animateWhen;

  /// Creates an AnimatedVestige.
  const AnimatedVestige({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.animateWhen,
  });

  @override
  State<AnimatedVestige<P>> createState() => _AnimatedVestigeState<P>();
}

class _AnimatedVestigeState<P extends Pillar> extends State<AnimatedVestige<P>>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late TitanEffect _effect;
  P? _pillar;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    // Set controller to completed state initially so first build
    // doesn't show a zero-opacity widget
    _controller.value = 1.0;

    _effect = TitanEffect(
      () {
        // Touch the Pillar's state to establish tracking
        if (_pillar != null) {
          widget.builder(context, _pillar as P, _animation);
        }
      },
      onNotify: _onDependencyChanged,
      fireImmediately: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvePillar();
  }

  void _resolvePillar() {
    final previousPillar = _pillar;

    final beaconPillar = BeaconScope.findPillar<P>(context);
    if (beaconPillar != null) {
      _pillar = beaconPillar;
    } else {
      final globalPillar = Titan.find<P>();
      if (globalPillar != null) {
        _pillar = globalPillar;
      } else {
        throw FlutterError(
          'AnimatedVestige<$P>: No $P found.\n\n'
          'Either:\n'
          '  • Wrap with Beacon: Beacon(pillars: [$P.new], child: ...)\n'
          '  • Register globally: Titan.put($P())\n',
        );
      }
    }

    if (_pillar != previousPillar) {
      previousPillar?.unref();
      _pillar?.ref();
    }
  }

  void _onDependencyChanged() {
    if (!mounted || _pillar == null) return;

    // Check animateWhen guard
    final shouldAnimate =
        widget.animateWhen == null || widget.animateWhen!(_pillar as P);

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (shouldAnimate) {
            _controller.forward(from: 0.0);
          }
          setState(() {});
        }
      });
    } else {
      if (shouldAnimate) {
        _controller.forward(from: 0.0);
      }
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(AnimatedVestige<P> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
  }

  @override
  void dispose() {
    _pillar?.unref();
    _effect.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _effect.run();
    return widget.builder(context, _pillar as P, _animation);
  }
}
