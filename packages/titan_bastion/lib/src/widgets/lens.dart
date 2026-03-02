import 'dart:async';

import 'package:flutter/material.dart';
import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Lens — Titan's Debug Overlay
// ---------------------------------------------------------------------------

/// A plugin that adds a custom tab to the [Lens] debug overlay.
///
/// External packages (like `titan_colossus`) implement this to inject
/// custom tabs without modifying Lens itself.
///
/// ## Usage
///
/// ```dart
/// class MyLensPlugin extends LensPlugin {
///   @override
///   String get title => 'MyTab';
///
///   @override
///   IconData get icon => Icons.speed;
///
///   @override
///   Widget build(BuildContext context) {
///     return const Center(child: Text('Hello from plugin'));
///   }
/// }
///
/// // Register the plugin
/// Lens.registerPlugin(MyLensPlugin());
/// ```
abstract class LensPlugin {
  /// Creates a [LensPlugin].
  const LensPlugin();

  /// Tab title displayed in the Lens header bar.
  String get title;

  /// Icon displayed next to the tab title.
  IconData get icon;

  /// Build the tab content widget.
  Widget build(BuildContext context);

  /// Called when the plugin is registered with Lens.
  void onAttach() {}

  /// Called when the plugin is unregistered from Lens.
  void onDetach() {}

  /// Called on each Lens refresh cycle (e.g. new Herald event, timer tick).
  ///
  /// Plugins can use this to update their internal state before rebuild.
  void onRefresh() {}
}

/// A [LogSink] that captures [LogEntry] records into a bounded buffer.
///
/// Used internally by [Lens] to display Chronicle log output.
class LensLogSink extends LogSink {
  final List<LogEntry> _entries = [];

  /// Maximum number of entries to retain.
  final int maxEntries;

  /// Callback invoked when a new entry is captured.
  void Function()? onEntry;

  /// Creates a log sink that buffers entries.
  LensLogSink({this.maxEntries = 200});

  @override
  void write(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    onEntry?.call();
  }

  /// All captured log entries (newest last).
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Clear all captured entries.
  void clear() => _entries.clear();
}

/// **Lens** — Titan's in-app debug overlay.
///
/// Wraps your app with a toggleable floating panel that displays real-time
/// information about:
///
/// - **Pillars** — All registered Pillars and their types
/// - **Herald** — Recent cross-domain events
/// - **Vigil** — Captured errors with severity and context
/// - **Chronicle** — Structured log output
///
/// ## Why "Lens"?
///
/// A lens focuses light to reveal detail. Lens focuses on your app's
/// internals to reveal what's happening under the hood.
///
/// ## Usage
///
/// ```dart
/// Lens(
///   enabled: kDebugMode,
///   child: MaterialApp(
///     home: MyHomePage(),
///   ),
/// )
/// ```
///
/// ## Programmatic Control
///
/// ```dart
/// Lens.show(); // Open the overlay
/// Lens.hide(); // Close the overlay
/// Lens.toggle(); // Toggle visibility
/// ```
class Lens extends StatefulWidget {
  /// The app widget to wrap.
  final Widget child;

  /// Whether the debug overlay is enabled.
  ///
  /// When `false`, [Lens] renders only the [child] with zero overhead.
  /// Typically set to `kDebugMode`.
  final bool enabled;

  /// Creates a debug overlay wrapping [child].
  const Lens({super.key, required this.child, this.enabled = true});

  // -------------------------------------------------------------------------
  // Static control — allows programmatic toggle from anywhere
  // -------------------------------------------------------------------------

  static _LensState? _activeInstance;

  /// Whether the debug overlay is currently visible.
  static bool get isVisible => _activeInstance?._visible ?? false;

  /// Show the debug overlay.
  static void show() => _activeInstance?._setVisible(true);

  /// Hide the debug overlay.
  static void hide() => _activeInstance?._setVisible(false);

  /// Toggle the debug overlay.
  static void toggle() => _activeInstance?._toggle();

  // -------------------------------------------------------------------------
  // Recording overlay — allows plugins to take over the FAB
  // -------------------------------------------------------------------------

  /// Notifier that external plugins (e.g. Shade) can set to `true`
  /// to turn the Lens FAB into a "stop recording" button.
  ///
  /// When `true`, the FAB shows a red pulsing record icon.
  /// Tapping it calls [onStopRecording] instead of toggling Lens.
  static final ValueNotifier<bool> activeRecording = ValueNotifier(false);

  /// Callback invoked when the FAB is tapped while [activeRecording]
  /// is `true`. Typically stops recording and saves the session.
  static VoidCallback? onStopRecording;

  // -------------------------------------------------------------------------
  // Plugin API — allows external packages to add custom tabs
  // -------------------------------------------------------------------------

  static final List<LensPlugin> _plugins = [];

  /// All registered plugins.
  static List<LensPlugin> get plugins => List.unmodifiable(_plugins);

  /// Register a custom [LensPlugin] tab.
  ///
  /// The plugin's tab appears after the built-in tabs (Pillars, Herald,
  /// Vigil, Chronicle). Call [unregisterPlugin] to remove it.
  static void registerPlugin(LensPlugin plugin) {
    if (!_plugins.contains(plugin)) {
      _plugins.add(plugin);
      plugin.onAttach();
      _activeInstance?._refresh();
    }
  }

  /// Remove a previously registered [LensPlugin].
  static void unregisterPlugin(LensPlugin plugin) {
    if (_plugins.remove(plugin)) {
      plugin.onDetach();
      _activeInstance?._refresh();
    }
  }

  @override
  State<Lens> createState() => _LensState();
}

class _LensState extends State<Lens> {
  bool _visible = false;
  int _selectedTab = 0;

  // Data sources
  final LensLogSink _logSink = LensLogSink();
  final List<HeraldEvent> _heraldEvents = [];
  StreamSubscription<HeraldEvent>? _heraldSub;
  StreamSubscription<TitanError>? _vigilSub;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;

    Lens._activeInstance = this;

    // Install Chronicle log sink
    Chronicle.addSink(_logSink);
    _logSink.onEntry = _refresh;

    // Subscribe to Herald global events
    _heraldSub = Herald.allEvents.listen((event) {
      _heraldEvents.add(event);
      if (_heraldEvents.length > 200) {
        _heraldEvents.removeAt(0);
      }
      _refresh();
    });

    // Subscribe to Vigil errors
    _vigilSub = Vigil.errors.listen((_) => _refresh());
  }

  void _refresh() {
    // Notify all plugins of a refresh cycle
    for (final plugin in Lens._plugins) {
      plugin.onRefresh();
    }
    if (mounted && _visible) {
      setState(() {});
    }
  }

  void _setVisible(bool visible) {
    if (_visible != visible) {
      setState(() => _visible = visible);
    }
  }

  void _toggle() => _setVisible(!_visible);

  @override
  void dispose() {
    if (widget.enabled) {
      Chronicle.removeSink(_logSink);
      _heraldSub?.cancel();
      _vigilSub?.cancel();
      if (Lens._activeInstance == this) {
        Lens._activeInstance = null;
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          // Floating action button — toggles Lens or stops recording
          Positioned(
            right: 16,
            bottom: 80,
            child: _LensFab(
              onPressed: () {
                // If recording, stop recording instead of toggling
                if (Lens.activeRecording.value) {
                  Lens.onStopRecording?.call();
                } else {
                  _toggle();
                }
              },
              isOpen: _visible,
            ),
          ),
          // Debug panel
          if (_visible)
            Positioned(
              left: 8,
              right: 8,
              bottom: 140,
              child: _LensPanel(
                selectedTab: _selectedTab,
                onTabChanged: (i) => setState(() => _selectedTab = i),
                instances: Titan.instances,
                heraldEvents: _heraldEvents,
                vigilErrors: Vigil.history,
                logEntries: _logSink.entries,
                plugins: Lens._plugins,
                onClearHerald: () {
                  setState(() => _heraldEvents.clear());
                },
                onClearLogs: () {
                  setState(() => _logSink.clear());
                },
                onClearErrors: () {
                  setState(() => Vigil.clearHistory());
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating Action Button
// ---------------------------------------------------------------------------

class _LensFab extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isOpen;

  const _LensFab({required this.onPressed, required this.isOpen});

  @override
  State<_LensFab> createState() => _LensFabState();
}

class _LensFabState extends State<_LensFab> {
  @override
  void initState() {
    super.initState();
    Lens.activeRecording.addListener(_onRecordingChanged);
  }

  void _onRecordingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Lens.activeRecording.removeListener(_onRecordingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = Lens.activeRecording.value;

    // Three states: recording (red pulse), open (close icon), idle (bug icon)
    final Color fabColor;
    final IconData fabIcon;
    if (isRecording) {
      fabColor = Colors.redAccent;
      fabIcon = Icons.stop_circle;
    } else if (widget.isOpen) {
      fabColor = Colors.redAccent;
      fabIcon = Icons.close;
    } else {
      fabColor = Colors.deepPurple;
      fabIcon = Icons.bug_report;
    }

    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: fabColor,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onPressed,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: isRecording
              ? const _PulsingIcon(
                  icon: Icons.stop_circle,
                  color: Colors.white,
                  size: 24,
                )
              : Icon(fabIcon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Animated pulsing icon for the recording state.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: 0.5 + 0.5 * _controller.value, child: child),
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}

// ---------------------------------------------------------------------------
// Debug Panel
// ---------------------------------------------------------------------------

class _LensPanel extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final Map<Type, dynamic> instances;
  final List<HeraldEvent> heraldEvents;
  final List<TitanError> vigilErrors;
  final List<LogEntry> logEntries;
  final List<LensPlugin> plugins;
  final VoidCallback onClearHerald;
  final VoidCallback onClearLogs;
  final VoidCallback onClearErrors;

  const _LensPanel({
    required this.selectedTab,
    required this.onTabChanged,
    required this.instances,
    required this.heraldEvents,
    required this.vigilErrors,
    required this.logEntries,
    required this.plugins,
    required this.onClearHerald,
    required this.onClearLogs,
    required this.onClearErrors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF1E1E2E),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final builtInTabs = ['Pillars', 'Herald', 'Vigil', 'Chronicle'];
    final allTabs = [...builtInTabs, ...plugins.map((p) => p.title)];
    return Container(
      height: 40,
      color: const Color(0xFF2D2D3F),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < allTabs.length; i++)
              GestureDetector(
                onTap: () => onTabChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedTab == i
                            ? (i >= builtInTabs.length
                                  ? Colors.tealAccent
                                  : Colors.deepPurpleAccent)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i >= builtInTabs.length) ...[
                        Icon(
                          plugins[i - builtInTabs.length].icon,
                          color: selectedTab == i
                              ? Colors.tealAccent
                              : Colors.white54,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        allTabs[i],
                        style: TextStyle(
                          color: selectedTab == i
                              ? (i >= builtInTabs.length
                                    ? Colors.tealAccent
                                    : Colors.deepPurpleAccent)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    const builtInCount = 4;
    if (selectedTab < builtInCount) {
      return switch (selectedTab) {
        0 => _PillarsView(instances: instances),
        1 => _HeraldView(events: heraldEvents, onClear: onClearHerald),
        2 => _VigilView(errors: vigilErrors, onClear: onClearErrors),
        3 => _ChronicleView(entries: logEntries, onClear: onClearLogs),
        _ => const SizedBox.shrink(),
      };
    }
    // Plugin tab
    final pluginIndex = selectedTab - builtInCount;
    if (pluginIndex < plugins.length) {
      return plugins[pluginIndex].build(context);
    }
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tab Views
// ---------------------------------------------------------------------------

class _PillarsView extends StatelessWidget {
  final Map<Type, dynamic> instances;

  const _PillarsView({required this.instances});

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty) {
      return const Center(
        child: Text(
          'No registered instances',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    final entries = instances.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isPillar = entry.value is Pillar;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                isPillar ? Icons.account_balance : Icons.inventory_2,
                color: isPillar ? Colors.deepPurpleAccent : Colors.tealAccent,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key.toString(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                isPillar ? 'Pillar' : entry.value.runtimeType.toString(),
                style: TextStyle(
                  color: isPillar ? Colors.deepPurpleAccent : Colors.tealAccent,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeraldView extends StatelessWidget {
  final List<HeraldEvent> events;
  final VoidCallback onClear;

  const _HeraldView({required this.events, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (events.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(right: 8, top: 4),
                child: Text(
                  'Clear',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
              ),
            ),
          ),
        Expanded(
          child: events.isEmpty
              ? const Center(
                  child: Text(
                    'No Herald events',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[events.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(event.timestamp),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${event.type}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _VigilView extends StatelessWidget {
  final List<TitanError> errors;
  final VoidCallback onClear;

  const _VigilView({required this.errors, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (errors.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(right: 8, top: 4),
                child: Text(
                  'Clear',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
              ),
            ),
          ),
        Expanded(
          child: errors.isEmpty
              ? const Center(
                  child: Text(
                    'No Vigil errors',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    final error = errors[errors.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _severityIcon(error.severity),
                            color: _severityColor(error.severity),
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  error.error.toString(),
                                  style: TextStyle(
                                    color: _severityColor(error.severity),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (error.context?.source != null)
                                  Text(
                                    'from ${error.context!.source}',
                                    style: const TextStyle(
                                      color: Colors.white24,
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(error.timestamp),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _severityIcon(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.debug => Icons.bug_report,
      ErrorSeverity.info => Icons.info_outline,
      ErrorSeverity.warning => Icons.warning_amber,
      ErrorSeverity.error => Icons.error_outline,
      ErrorSeverity.fatal => Icons.dangerous,
    };
  }

  Color _severityColor(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.debug => Colors.grey,
      ErrorSeverity.info => Colors.lightBlueAccent,
      ErrorSeverity.warning => Colors.orangeAccent,
      ErrorSeverity.error => Colors.redAccent,
      ErrorSeverity.fatal => Colors.red,
    };
  }
}

class _ChronicleView extends StatelessWidget {
  final List<LogEntry> entries;
  final VoidCallback onClear;

  const _ChronicleView({required this.entries, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (entries.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(right: 8, top: 4),
                child: Text(
                  'Clear',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10),
                ),
              ),
            ),
          ),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'No Chronicle entries',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _levelTag(entry.level),
                            style: TextStyle(
                              color: _levelColor(entry.level),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${entry.loggerName}: ${entry.message}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(entry.timestamp),
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _levelTag(LogLevel level) {
    return switch (level) {
      LogLevel.trace => 'TRC',
      LogLevel.debug => 'DBG',
      LogLevel.info => 'INF',
      LogLevel.warning => 'WRN',
      LogLevel.error => 'ERR',
      LogLevel.fatal => 'FTL',
      LogLevel.off => 'OFF',
    };
  }

  Color _levelColor(LogLevel level) {
    return switch (level) {
      LogLevel.trace => Colors.grey,
      LogLevel.debug => Colors.white38,
      LogLevel.info => Colors.lightBlueAccent,
      LogLevel.warning => Colors.orangeAccent,
      LogLevel.error => Colors.redAccent,
      LogLevel.fatal => Colors.red,
      LogLevel.off => Colors.grey,
    };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
