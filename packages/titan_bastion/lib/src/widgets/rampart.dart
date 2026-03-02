/// Rampart — Responsive layout builder for adaptive UIs.
///
/// Rampart provides a declarative way to build responsive layouts
/// based on screen width breakpoints. It supports Material 3
/// breakpoint conventions by default, with custom breakpoint support.
///
/// ## Why "Rampart"?
///
/// A rampart is a defensive wall with different tiers. Titan's Rampart
/// provides tiered layout adaptation based on display size.
///
/// ## Usage
///
/// ```dart
/// Rampart(
///   compact: (context) => const MobileLayout(),
///   medium: (context) => const TabletLayout(),
///   expanded: (context) => const DesktopLayout(),
/// )
/// ```
///
/// ## With custom breakpoints
///
/// ```dart
/// Rampart(
///   breakpoints: const RampartBreakpoints(
///     compact: 0,
///     medium: 600,
///     expanded: 1200,
///   ),
///   compact: (context) => const MobileLayout(),
///   expanded: (context) => const DesktopLayout(),
/// )
/// ```
library;

import 'package:flutter/widgets.dart';

/// Breakpoint thresholds for responsive layout tiers.
///
/// Based on Material 3 canonical breakpoints by default:
/// - compact: 0–599
/// - medium: 600–839
/// - expanded: 840+
///
/// ```dart
/// const custom = RampartBreakpoints(
///   compact: 0,
///   medium: 768,
///   expanded: 1280,
/// );
/// ```
class RampartBreakpoints {
  /// The minimum width for compact layout (usually 0).
  final double compact;

  /// The minimum width for medium layout.
  final double medium;

  /// The minimum width for expanded layout.
  final double expanded;

  /// Creates custom breakpoints.
  const RampartBreakpoints({
    this.compact = 0,
    this.medium = 600,
    this.expanded = 840,
  });

  /// Material 3 canonical breakpoints (default).
  static const material3 = RampartBreakpoints();
}

/// The current responsive layout tier.
enum RampartLayout {
  /// Small screens (phones) — width < medium breakpoint.
  compact,

  /// Medium screens (tablets) — width >= medium and < expanded.
  medium,

  /// Large screens (desktop) — width >= expanded breakpoint.
  expanded,
}

/// A responsive adaptive value that varies by layout tier.
///
/// Use this to provide different values (padding, sizes, etc.)
/// based on the current responsive tier.
///
/// ```dart
/// final padding = RampartValue<double>(
///   compact: 8,
///   medium: 16,
///   expanded: 24,
/// );
///
/// // In a widget:
/// Padding(
///   padding: EdgeInsets.all(padding.resolve(layout)),
///   child: content,
/// )
/// ```
class RampartValue<T> {
  /// Value for compact layout.
  final T compact;

  /// Value for medium layout. Falls back to [compact] if null.
  final T? medium;

  /// Value for expanded layout. Falls back to [medium] or [compact] if null.
  final T? expanded;

  /// Creates a responsive value with per-tier overrides.
  const RampartValue({required this.compact, this.medium, this.expanded});

  /// Creates a value that's the same across all tiers.
  const RampartValue.all(T value)
    : compact = value,
      medium = value,
      expanded = value;

  /// Resolve the value for the given layout tier.
  T resolve(RampartLayout layout) {
    return switch (layout) {
      RampartLayout.compact => compact,
      RampartLayout.medium => medium ?? compact,
      RampartLayout.expanded => expanded ?? medium ?? compact,
    };
  }
}

/// Selectively show or hide a child based on the layout tier.
///
/// ```dart
/// RampartVisibility(
///   visibleOn: {RampartLayout.medium, RampartLayout.expanded},
///   child: const SidePanel(),
/// )
/// ```
class RampartVisibility extends StatelessWidget {
  /// The layout tiers on which the child should be visible.
  final Set<RampartLayout> visibleOn;

  /// The child widget to conditionally show.
  final Widget child;

  /// Replacement widget when hidden (defaults to empty SizedBox).
  final Widget replacement;

  /// Whether to maintain state when hidden.
  final bool maintainState;

  /// Creates a visibility widget tied to layout tiers.
  const RampartVisibility({
    super.key,
    required this.visibleOn,
    required this.child,
    this.replacement = const SizedBox.shrink(),
    this.maintainState = false,
  });

  @override
  Widget build(BuildContext context) {
    final layout = Rampart.layoutOf(context);

    if (visibleOn.contains(layout)) {
      return child;
    }

    if (maintainState) {
      return Visibility(
        visible: false,
        maintainState: true,
        maintainSize: false,
        maintainAnimation: false,
        child: child,
      );
    }

    return replacement;
  }
}

/// A responsive layout builder that adapts to screen width.
///
/// Provides [compact], [medium], and [expanded] builders that are
/// selected based on the current screen width and breakpoints.
///
/// Falls back gracefully: if [medium] is not provided, uses [compact].
/// If [expanded] is not provided, uses [medium] or [compact].
///
/// ```dart
/// Rampart(
///   compact: (context) => const MobileLayout(),
///   medium: (context) => const TabletLayout(),
///   expanded: (context) => const DesktopLayout(),
/// )
/// ```
class Rampart extends StatelessWidget {
  /// Builder for compact (small screen) layout.
  final WidgetBuilder compact;

  /// Builder for medium (tablet) layout.
  /// Falls back to [compact] if null.
  final WidgetBuilder? medium;

  /// Builder for expanded (desktop) layout.
  /// Falls back to [medium] or [compact] if null.
  final WidgetBuilder? expanded;

  /// Breakpoint thresholds. Defaults to Material 3 breakpoints.
  final RampartBreakpoints breakpoints;

  /// Creates a responsive layout builder.
  const Rampart({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
    this.breakpoints = const RampartBreakpoints(),
  });

  /// Determine the layout tier from screen width and breakpoints.
  static RampartLayout layoutFor(
    double width, [
    RampartBreakpoints breakpoints = const RampartBreakpoints(),
  ]) {
    if (width >= breakpoints.expanded) return RampartLayout.expanded;
    if (width >= breakpoints.medium) return RampartLayout.medium;
    return RampartLayout.compact;
  }

  /// Get the current layout tier from the nearest [MediaQuery].
  ///
  /// ```dart
  /// final layout = Rampart.layoutOf(context);
  /// if (layout == RampartLayout.expanded) {
  ///   // show side panel
  /// }
  /// ```
  static RampartLayout layoutOf(
    BuildContext context, [
    RampartBreakpoints breakpoints = const RampartBreakpoints(),
  ]) {
    final width = MediaQuery.sizeOf(context).width;
    return layoutFor(width, breakpoints);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layout = layoutFor(width, breakpoints);

    final builder = switch (layout) {
      RampartLayout.compact => compact,
      RampartLayout.medium => medium ?? compact,
      RampartLayout.expanded => expanded ?? medium ?? compact,
    };

    return builder(context);
  }
}

/// Extension on [BuildContext] for responsive helpers.
extension RampartContext on BuildContext {
  /// Get the current responsive layout tier.
  ///
  /// ```dart
  /// final layout = context.rampartLayout;
  /// ```
  RampartLayout get rampartLayout => Rampart.layoutOf(this);

  /// Whether the current layout is compact (phone).
  bool get isCompact => rampartLayout == RampartLayout.compact;

  /// Whether the current layout is medium (tablet).
  bool get isMedium => rampartLayout == RampartLayout.medium;

  /// Whether the current layout is expanded (desktop).
  bool get isExpanded => rampartLayout == RampartLayout.expanded;
}
