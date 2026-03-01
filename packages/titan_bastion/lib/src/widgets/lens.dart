import 'dart:async';

import 'package:flutter/material.dart';
import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Lens — Titan's Debug Overlay
// ---------------------------------------------------------------------------

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

  /// Show the debug overlay.
  static void show() => _activeInstance?._setVisible(true);

  /// Hide the debug overlay.
  static void hide() => _activeInstance?._setVisible(false);

  /// Toggle the debug overlay.
  static void toggle() => _activeInstance?._toggle();

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
          // Floating action button to toggle
          Positioned(
            right: 16,
            bottom: 80,
            child: _LensFab(onPressed: _toggle, isOpen: _visible),
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

class _LensFab extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isOpen;

  const _LensFab({required this.onPressed, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: isOpen ? Colors.redAccent : Colors.deepPurple,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            isOpen ? Icons.close : Icons.bug_report,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
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
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['Pillars', 'Herald', 'Vigil', 'Chronicle'];
    return Container(
      height: 40,
      color: const Color(0xFF2D2D3F),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTabChanged(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selectedTab == i
                            ? Colors.deepPurpleAccent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color: selectedTab == i
                          ? Colors.deepPurpleAccent
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (selectedTab) {
      0 => _PillarsView(instances: instances),
      1 => _HeraldView(events: heraldEvents, onClear: onClearHerald),
      2 => _VigilView(errors: vigilErrors, onClear: onClearErrors),
      3 => _ChronicleView(entries: logEntries, onClear: onClearLogs),
      _ => const SizedBox.shrink(),
    };
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
