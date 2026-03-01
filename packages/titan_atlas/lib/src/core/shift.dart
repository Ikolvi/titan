/// Shift — Page transition animations.
///
/// Controls how pages animate in and out during navigation.
///
/// ```dart
/// Passage('/home', (_) => HomeScreen(), shift: Shift.fade()),
/// Passage('/modal', (_) => Modal(), shift: Shift.slideUp()),
/// ```
library;

import 'package:flutter/material.dart';
import 'waypoint.dart';

/// A page transition animation.
///
/// Built-in shifts: [fade], [slide], [slideUp], [scale], [none].
/// Custom shifts via [Shift.custom].
class Shift {
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) _transitionBuilder;

  final Duration _duration;
  final Duration _reverseDuration;

  const Shift._({
    required Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) transitionBuilder,
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
  })  : _transitionBuilder = transitionBuilder,
        _duration = duration,
        _reverseDuration = reverseDuration ?? duration;

  /// Fade transition.
  ///
  /// ```dart
  /// Passage('/home', (_) => Home(), shift: Shift.fade())
  /// ```
  factory Shift.fade({Duration duration = const Duration(milliseconds: 300)}) {
    return Shift._(
      duration: duration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  /// Slide from right transition (platform default).
  ///
  /// ```dart
  /// Passage('/detail', (_) => Detail(), shift: Shift.slide())
  /// ```
  factory Shift.slide({Duration duration = const Duration(milliseconds: 300)}) {
    return Shift._(
      duration: duration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Slide from bottom transition (modal-style).
  ///
  /// ```dart
  /// Passage('/modal', (_) => Modal(), shift: Shift.slideUp())
  /// ```
  factory Shift.slideUp({
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Shift._(
      duration: duration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Scale transition (zoom in).
  ///
  /// ```dart
  /// Passage('/detail', (_) => Detail(), shift: Shift.scale())
  /// ```
  factory Shift.scale({
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Shift._(
      duration: duration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: animation.drive(
            Tween(begin: 0.8, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOut)),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// No transition animation.
  ///
  /// ```dart
  /// Passage('/tab', (_) => Tab(), shift: Shift.none())
  /// ```
  factory Shift.none() {
    return Shift._(
      duration: Duration.zero,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  /// Custom transition.
  ///
  /// ```dart
  /// Passage('/custom', (_) => Custom(), shift: Shift.custom(
  ///   duration: Duration(milliseconds: 500),
  ///   builder: (context, animation, secondaryAnimation, child) {
  ///     return RotationTransition(turns: animation, child: child);
  ///   },
  /// ))
  /// ```
  factory Shift.custom({
    required Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) builder,
    Duration duration = const Duration(milliseconds: 300),
    Duration? reverseDuration,
  }) {
    return Shift._(
      duration: duration,
      reverseDuration: reverseDuration,
      transitionBuilder: builder,
    );
  }

  /// Build a [Page] with this transition.
  Page<dynamic> buildPage(Widget child, Waypoint waypoint) {
    return _ShiftPage(
      key: ValueKey(waypoint.path),
      child: child,
      shift: this,
      waypoint: waypoint,
    );
  }
}

/// A [Page] that uses a [Shift] for its transition.
class _ShiftPage extends Page<dynamic> {
  final Widget child;
  final Shift shift;
  final Waypoint waypoint;

  const _ShiftPage({
    required this.child,
    required this.shift,
    required this.waypoint,
    super.key,
  });

  @override
  Route<dynamic> createRoute(BuildContext context) {
    return PageRouteBuilder(
      settings: this,
      transitionDuration: shift._duration,
      reverseTransitionDuration: shift._reverseDuration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: shift._transitionBuilder,
    );
  }
}
