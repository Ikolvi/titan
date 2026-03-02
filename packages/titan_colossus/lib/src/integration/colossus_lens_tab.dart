import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../colossus.dart';
import 'lens.dart';
import '../export/inscribe.dart';
import '../export/inscribe_io.dart';
import '../metrics/mark.dart';

// ---------------------------------------------------------------------------
// ColossusLensTab — Lens Plugin for Performance Metrics
// ---------------------------------------------------------------------------

/// A [LensPlugin] that adds a "Perf" tab to the Lens debug overlay.
///
/// Displays real-time performance metrics from Colossus:
/// - FPS and jank rate
/// - Frame build/raster times
/// - Page load history
/// - Memory status and leak suspects
/// - Widget rebuild counts
///
/// This plugin is automatically registered when `Colossus.init()`
/// is called with `enableLensTab: true` (the default).
class ColossusLensTab extends LensPlugin {
  final Colossus _colossus;

  /// Creates a [ColossusLensTab] for the given [Colossus] instance.
  ColossusLensTab(this._colossus);

  @override
  String get title => 'Perf';

  @override
  IconData get icon => Icons.speed;

  @override
  Widget build(BuildContext context) {
    return _ColossusTabContent(colossus: _colossus);
  }
}

// ---------------------------------------------------------------------------
// Tab Content
// ---------------------------------------------------------------------------

/// Internal Pillar managing standalone performance recording state.
///
/// Uses [Core] fields for reactive state instead of `setState`, ensuring
/// the Colossus package "eats its own dog food" by using Titan's
/// architecture within its own widgets.
///
/// ## Architecture
///
/// ```
/// Beacon(pillars: [_PerfRecordingPillar])
///   └─ Vestige<_PerfRecordingPillar>
///        └─ _buildPerfRecordingBar(p)  ← Core reads tracked here
/// ```
///
/// The [Beacon] manages the Pillar lifecycle (create → initialize →
/// dispose). The [Vestige] auto-rebuilds when any tracked [Core]
/// changes value.
class _PerfRecordingPillar extends Pillar {
  final Colossus colossus;

  _PerfRecordingPillar(this.colossus);

  /// Reactive state mirroring [Colossus.isPerfRecording].
  ///
  /// Lives on the Pillar for reactive UI updates but delegates
  /// actual state to the Colossus instance so recording survives
  /// Lens close/reopen.
  late final isPerfRecording = core(colossus.isPerfRecording);

  /// Status message shown after recording stops.
  late final perfStatus = core(colossus.perfRecordingStatus);

  @override
  void onInit() {
    // Sync from Colossus state (in case Lens was reopened mid-recording)
    isPerfRecording.value = colossus.isPerfRecording;
    perfStatus.value = colossus.perfRecordingStatus;
  }

  /// Start a standalone performance recording session.
  void startPerfRecording() {
    colossus.startPerfRecording();
    isPerfRecording.value = true;
    perfStatus.value = '';
  }

  /// Stop the current performance recording session.
  void stopPerfRecording() {
    colossus.stopPerfRecording();
    isPerfRecording.value = false;
    perfStatus.value = colossus.perfRecordingStatus;
  }
}

/// Stateless host for the Colossus Lens tab content.
///
/// Wraps the widget tree in a [Beacon] to provide [_PerfRecordingPillar]
/// to descendant [Vestige] builders. The Beacon creates, initializes,
/// and disposes the Pillar automatically with the widget lifecycle.
///
/// Builder functions (e.g. [_buildPerfRecordingBar]) are called from
/// within the [Vestige] builder scope so that [Core] value reads are
/// auto-tracked by the reactive engine.
class _ColossusTabContent extends StatelessWidget {
  final Colossus colossus;

  const _ColossusTabContent({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Beacon(
      pillars: [() => _PerfRecordingPillar(colossus)],
      // Localizations is required because TabBar/TabBarView need
      // MaterialLocalizations, but the Lens overlay only provides
      // Directionality — not a full MaterialApp.
      child: Localizations(
        locale: const Locale('en'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: DefaultTabController(
          length: 5,
          child: Column(
            children: [
              const _SubTabBar(),
              // Perf recording bar uses Vestige for reactive rebuilds
              Vestige<_PerfRecordingPillar>(
                builder: (context, p) => _buildPerfRecordingBar(p),
              ),
              Expanded(child: _ColossusTabBody(colossus: colossus)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds the perf recording bar within the [Vestige] scope.
///
/// **Important**: This function runs inside `Vestige.builder`, so all
/// [Core.value] reads are auto-tracked. When [isPerfRecording] or
/// [perfStatus] change, only this section rebuilds.
Widget _buildPerfRecordingBar(_PerfRecordingPillar p) {
  final isRecording = p.isPerfRecording.value;
  final status = p.perfStatus.value;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isRecording
          ? Colors.redAccent.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.03),
      border: Border(
        bottom: BorderSide(
          color: isRecording
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: isRecording ? p.stopPerfRecording : p.startPerfRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isRecording
                  ? Colors.orangeAccent.withValues(alpha: 0.2)
                  : Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isRecording
                    ? Colors.orangeAccent.withValues(alpha: 0.4)
                    : Colors.redAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRecording ? Icons.stop : Icons.fiber_manual_record,
                  size: 10,
                  color: isRecording ? Colors.orangeAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  isRecording ? 'Stop & Report' : 'Record Perf',
                  style: TextStyle(
                    color: isRecording ? Colors.orangeAccent : Colors.redAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isRecording) ...[
          Icon(
            Icons.fiber_manual_record,
            size: 8,
            color: Colors.redAccent.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            'Recording...',
            style: TextStyle(
              color: Colors.redAccent.withValues(alpha: 0.8),
              fontSize: 9,
            ),
          ),
        ] else if (status.isNotEmpty)
          Expanded(
            child: Text(
              status,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
}

class _SubTabBar extends StatelessWidget {
  const _SubTabBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: TabBar(
        isScrollable: true,
        labelColor: Colors.tealAccent,
        unselectedLabelColor: Colors.white38,
        indicatorColor: Colors.tealAccent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(text: 'Pulse'),
          Tab(text: 'Stride'),
          Tab(text: 'Vessel'),
          Tab(text: 'Echo'),
          Tab(text: 'Export'),
        ],
      ),
    );
  }
}

class _ColossusTabBody extends StatelessWidget {
  final Colossus colossus;
  const _ColossusTabBody({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _PulseView(colossus: colossus),
        _StrideView(colossus: colossus),
        _VesselView(colossus: colossus),
        _EchoView(colossus: colossus),
        _ExportView(colossus: colossus),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pulse sub-tab — Frame metrics
// ---------------------------------------------------------------------------

class _PulseView extends StatelessWidget {
  final Colossus colossus;

  const _PulseView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    final pulse = colossus.pulse;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _MetricRow(
          label: 'FPS',
          value: pulse.fps.toStringAsFixed(1),
          color: _fpsColor(pulse.fps),
        ),
        _MetricRow(
          label: 'Jank rate',
          value: '${pulse.jankRate.toStringAsFixed(1)}%',
          color: pulse.jankRate > 5 ? Colors.redAccent : Colors.greenAccent,
        ),
        _MetricRow(label: 'Total frames', value: '${pulse.totalFrames}'),
        _MetricRow(
          label: 'Jank frames',
          value: '${pulse.jankFrames}',
          color: pulse.jankFrames > 0 ? Colors.orangeAccent : Colors.white54,
        ),
        _MetricRow(
          label: 'Avg build',
          value: '${pulse.avgBuildTime.inMicroseconds}µs',
        ),
        _MetricRow(
          label: 'Avg raster',
          value: '${pulse.avgRasterTime.inMicroseconds}µs',
        ),
        const SizedBox(height: 8),
        if (pulse.history.isNotEmpty) ...[
          const Text(
            'Recent frames',
            style: TextStyle(color: Colors.white38, fontSize: 9),
          ),
          const SizedBox(height: 4),
          SizedBox(height: 40, child: _FrameBarChart(frames: pulse.history)),
        ],
      ],
    );
  }

  Color _fpsColor(double fps) {
    if (fps >= 55) return Colors.greenAccent;
    if (fps >= 40) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

// ---------------------------------------------------------------------------
// Stride sub-tab — Page load timing
// ---------------------------------------------------------------------------

class _StrideView extends StatelessWidget {
  final Colossus colossus;

  const _StrideView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    final stride = colossus.stride;
    final loads = stride.history;

    if (loads.isEmpty) {
      return const Center(
        child: Text(
          'No page loads recorded',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _MetricRow(
          label: 'Avg page load',
          value: '${stride.avgPageLoad.inMilliseconds}ms',
          color: stride.avgPageLoad.inMilliseconds > 500
              ? Colors.orangeAccent
              : Colors.greenAccent,
        ),
        _MetricRow(label: 'Total loads', value: '${loads.length}'),
        const SizedBox(height: 8),
        const Text(
          'Recent page loads',
          style: TextStyle(color: Colors.white38, fontSize: 9),
        ),
        const SizedBox(height: 4),
        for (final load in loads.reversed.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.route,
                  size: 12,
                  color: load.duration.inMilliseconds > 500
                      ? Colors.orangeAccent
                      : Colors.tealAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    load.path,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${load.duration.inMilliseconds}ms',
                  style: TextStyle(
                    color: load.duration.inMilliseconds > 500
                        ? Colors.orangeAccent
                        : Colors.tealAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vessel sub-tab — Memory monitoring
// ---------------------------------------------------------------------------

class _VesselView extends StatelessWidget {
  final Colossus colossus;

  const _VesselView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    final vessel = colossus.vessel;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _MetricRow(
          label: 'Pillars',
          value: '${vessel.pillarCount}',
          color: vessel.pillarCount > 30
              ? Colors.orangeAccent
              : Colors.greenAccent,
        ),
        _MetricRow(label: 'Total instances', value: '${vessel.totalInstances}'),
        _MetricRow(
          label: 'Leak suspects',
          value: '${vessel.leakSuspects.length}',
          color: vessel.leakSuspects.isNotEmpty
              ? Colors.redAccent
              : Colors.greenAccent,
        ),
        if (vessel.leakSuspects.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Suspected leaks',
            style: TextStyle(color: Colors.redAccent, fontSize: 9),
          ),
          const SizedBox(height: 4),
          for (final suspect in vessel.leakSuspects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 12,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      suspect.typeName,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Text(
                    '${suspect.age.inSeconds}s',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Echo sub-tab — Rebuild tracking
// ---------------------------------------------------------------------------

class _EchoView extends StatelessWidget {
  final Colossus colossus;

  const _EchoView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    final rebuilds = colossus.rebuildsPerWidget;

    if (rebuilds.isEmpty) {
      return const Center(
        child: Text(
          'No rebuild data (wrap widgets with Echo)',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    final sorted = rebuilds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = rebuilds.values.fold<int>(0, (sum, c) => sum + c);

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _MetricRow(label: 'Total rebuilds', value: '$total'),
        _MetricRow(label: 'Tracked widgets', value: '${rebuilds.length}'),
        const SizedBox(height: 8),
        const Text(
          'Rebuilds by widget',
          style: TextStyle(color: Colors.white38, fontSize: 9),
        ),
        const SizedBox(height: 4),
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.replay,
                  size: 12,
                  color: entry.value > 50
                      ? Colors.orangeAccent
                      : Colors.tealAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    color: entry.value > 50
                        ? Colors.orangeAccent
                        : Colors.tealAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Export sub-tab — Save & share reports
// ---------------------------------------------------------------------------

class _ExportView extends StatefulWidget {
  final Colossus colossus;

  const _ExportView({required this.colossus});

  @override
  State<_ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends State<_ExportView> {
  String? _lastSavedPath;
  String? _statusMessage;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Text(
          'Export Performance Report',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Save or copy the current Colossus decree.',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 12),

        // Copy buttons
        const Text(
          'Copy to clipboard',
          style: TextStyle(color: Colors.white38, fontSize: 9),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _ExportButton(
              icon: Icons.description,
              label: 'Markdown',
              onTap: _copyMarkdown,
            ),
            const SizedBox(width: 6),
            _ExportButton(
              icon: Icons.data_object,
              label: 'JSON',
              onTap: _copyJson,
            ),
            const SizedBox(width: 6),
            _ExportButton(
              icon: Icons.code,
              label: 'Summary',
              onTap: _copySummary,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Save buttons
        const Text(
          'Save to disk',
          style: TextStyle(color: Colors.white38, fontSize: 9),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _ExportButton(
              icon: Icons.save,
              label: 'Save HTML',
              onTap: _isSaving ? null : _saveHtml,
            ),
            const SizedBox(width: 6),
            _ExportButton(
              icon: Icons.save_alt,
              label: 'Save All',
              onTap: _isSaving ? null : _saveAll,
            ),
          ],
        ),

        // Status
        if (_statusMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _statusMessage!,
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],

        if (_lastSavedPath != null) ...[
          const SizedBox(height: 6),
          Text(
            _lastSavedPath!,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }

  void _copyMarkdown() {
    final decree = widget.colossus.decree();
    final md = Inscribe.markdown(decree);
    Clipboard.setData(ClipboardData(text: md));
    setState(() => _statusMessage = 'Markdown copied to clipboard');
  }

  void _copyJson() {
    final decree = widget.colossus.decree();
    final json = Inscribe.json(decree);
    Clipboard.setData(ClipboardData(text: json));
    setState(() => _statusMessage = 'JSON copied to clipboard');
  }

  void _copySummary() {
    final decree = widget.colossus.decree();
    Clipboard.setData(ClipboardData(text: decree.summary));
    setState(() => _statusMessage = 'Summary copied to clipboard');
  }

  Future<void> _saveHtml() async {
    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving...';
    });
    try {
      final decree = widget.colossus.decree();
      final path = await InscribeIO.saveHtml(
        decree,
        directory: widget.colossus.exportDirectory,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'HTML report saved';
          _lastSavedPath = path;
        });
        widget.colossus.onExport?.call([path]);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Save failed';
          _lastSavedPath = null;
        });
      }
    }
  }

  Future<void> _saveAll() async {
    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving all formats...';
    });
    try {
      final decree = widget.colossus.decree();
      final result = await InscribeIO.saveAll(
        decree,
        directory: widget.colossus.exportDirectory,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = '3 files saved';
          _lastSavedPath = result.all.join('\n');
        });
        widget.colossus.onExport?.call(result.all);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Save failed';
          _lastSavedPath = null;
        });
      }
    }
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: onTap != null
                ? Colors.tealAccent.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: onTap != null
                  ? Colors.tealAccent.withValues(alpha: 0.3)
                  : Colors.white12,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: onTap != null ? Colors.tealAccent : Colors.white24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: onTap != null ? Colors.white70 : Colors.white24,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    this.color = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameBarChart extends StatelessWidget {
  final List<FrameMark> frames;

  const _FrameBarChart({required this.frames});

  @override
  Widget build(BuildContext context) {
    // Show the last 60 frames as tiny bars
    final recent = frames.length > 60
        ? frames.sublist(frames.length - 60)
        : frames;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final frame in recent)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: _barHeight(frame),
              decoration: BoxDecoration(
                color: frame.isJank
                    ? (frame.isSevereJank
                          ? Colors.redAccent
                          : Colors.orangeAccent)
                    : Colors.tealAccent.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(1),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _barHeight(FrameMark frame) {
    // Scale: 0ms = 0px, 33ms+ = 40px
    final ms = frame.totalDuration.inMilliseconds.toDouble();
    return (ms / 33.0 * 40.0).clamp(2.0, 40.0);
  }
}
