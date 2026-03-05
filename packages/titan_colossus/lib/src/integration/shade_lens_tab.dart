import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../colossus.dart';
import 'lens.dart';
import '../export/inscribe.dart';
import '../export/inscribe_io.dart';
import '../recording/imprint.dart';
import '../recording/phantom.dart';
import '../recording/shade_vault.dart';

// ---------------------------------------------------------------------------
// ShadeLensTab — Enhanced Lens Plugin for Shade v2
// ---------------------------------------------------------------------------

/// A [LensPlugin] providing full Shade control inside the Lens overlay.
///
/// Features:
/// - Record/stop/cancel with live event counters
/// - Speed control for replay (0.5×–5×)
/// - Session library (saved sessions list)
/// - Save, load, replay, and delete sessions
/// - Auto-replay toggle for automated restart flows
///
/// Automatically registered when `Colossus.init(enableLensTab: true)`.
class ShadeLensTab extends LensPlugin {
  final Colossus _colossus;

  /// Creates a [ShadeLensTab] for the given [Colossus] instance.
  ShadeLensTab(this._colossus);

  @override
  String get title => 'Shade';

  @override
  IconData get icon => Icons.fiber_smart_record;

  @override
  Widget build(BuildContext context) {
    return _ShadeTabContent(colossus: _colossus);
  }
}

// ---------------------------------------------------------------------------
// Pillar — Shade Tab State & Business Logic
// ---------------------------------------------------------------------------

/// Internal Pillar managing all Shade tab state and business logic.
///
/// Uses [Core] fields for reactive state instead of `setState`, ensuring
/// the Colossus package "eats its own dog food" by using Titan's
/// architecture within its own widgets.
///
/// ## Architecture
///
/// ```
/// Beacon(pillars: [_ShadeLensPillar])
///   └─ Vestige<_ShadeLensPillar>
///        └─ _buildRecordingSection(p)
///        └─ _buildSpeedControl(p)
///        └─ _buildSessionInfo(p)
///        └─ ... (all UI builder helpers)
/// ```
///
/// The [Beacon] manages the Pillar lifecycle. The [Vestige] builder
/// calls helper functions which read [Core.value] — those reads are
/// auto-tracked, so the entire ListView rebuilds when any Core changes.
///
/// ## Lifecycle
///
/// On [onInit], the Pillar loads auto-replay configuration and saved
/// sessions from the [ShadeVault] (fire-and-forget async).
class _ShadeLensPillar extends Pillar {
  /// The [Colossus] instance this Pillar controls.
  final Colossus colossus;

  _ShadeLensPillar(this.colossus);

  // -- Reactive state -------------------------------------------------------

  /// The last recorded session.
  late final lastSession = core<ShadeSession?>(null);

  /// The result of the last replay operation.
  late final lastResult = core<PhantomResult?>(null);

  /// Status message displayed at the bottom of the tab.
  late final status = core('');

  /// Current replay progress (events dispatched so far).
  late final replayProgress = core(0);

  /// Total number of events being replayed.
  late final replayTotal = core(0);

  /// Whether a replay is currently in progress.
  late final isReplaying = core(false);

  /// Whether auto-replay is enabled.
  late final autoReplayEnabled = core(false);

  /// The session ID currently targeted for auto-replay.
  late final autoReplaySessionId = core<String?>(null);

  /// Whether intelligent wait (waitForSettled) is enabled.
  late final waitForSettledEnabled = core(false);

  /// Current replay speed multiplier.
  late final replaySpeed = core(1.0);

  /// List of saved session summaries from the vault.
  late final savedSessions = core<List<ShadeSessionSummary>>([]);

  /// Whether the session library is expanded.
  late final showLibrary = core(false);

  // -- Lifecycle ------------------------------------------------------------

  @override
  void onInit() {
    _loadAutoReplayConfig();
    _loadSavedSessions();

    // Restore the last recorded session from Colossus so it
    // survives Lens hide/show cycles (which dispose this Pillar).
    if (colossus.lastRecordedSession != null) {
      lastSession.value = colossus.lastRecordedSession;
    }

    // If Shade was recording when Lens opens, sync the FAB state
    if (colossus.shade.isRecording) {
      _activateFabRecording();
    }
  }

  // -- Actions --------------------------------------------------------------

  /// Start recording gestures, hiding the Lens overlay first.
  ///
  /// Activates the Lens FAB recording mode so the user can stop
  /// recording by tapping the FAB without reopening the Shade tab.
  void startRecording() {
    Lens.hide();
    lastResult.value = null;
    status.value = 'Recording started...';
    colossus.shade.startRecording(
      name: 'shade_${DateTime.now().millisecondsSinceEpoch}',
    );
    _activateFabRecording();
  }

  /// Stop recording and capture the session.
  void stopRecording() {
    final session = colossus.shade.stopRecording();
    lastSession.value = session;
    colossus.lastRecordedSession = session;
    _deactivateFabRecording();
    status.value =
        'Recorded ${session.eventCount} events in '
        '${session.duration.inMilliseconds}ms';
  }

  /// Cancel the current recording.
  void cancelRecording() {
    colossus.shade.cancelRecording();
    _deactivateFabRecording();
    status.value = 'Recording cancelled';
  }

  /// Save the current session to the vault.
  Future<void> saveCurrentSession() async {
    if (lastSession.value == null) {
      status.value = 'No session to save';
      return;
    }
    try {
      final path = await colossus.saveSession(lastSession.value!);
      if (path != null) {
        status.value = 'Session saved';
        await _loadSavedSessions();
      } else {
        status.value = 'Save failed — no storage path configured';
      }
    } on Exception catch (e) {
      status.value = 'Save failed: $e';
    }
  }

  /// Replay the current in-memory session.
  Future<void> replayCurrentSession() async {
    if (lastSession.value == null) return;
    await _doReplay(lastSession.value!);
  }

  /// Load and replay a saved session from the vault.
  Future<void> replaySavedSession(String sessionId) async {
    final session = await colossus.loadSession(sessionId);
    if (session == null) {
      status.value = 'Session not found';
      return;
    }
    await _doReplay(session);
  }

  /// Copy the current performance report to clipboard.
  Future<void> copyReport() async {
    final decree = colossus.decree();
    final markdown = Inscribe.markdown(decree);
    await Clipboard.setData(ClipboardData(text: markdown));
    status.value = 'Report copied to clipboard';
  }

  /// Save the current performance report to disk.
  Future<void> saveReport() async {
    final decree = colossus.decree();
    try {
      final result = await InscribeIO.saveAll(
        decree,
        directory: colossus.exportDirectory,
      );
      status.value = 'Report saved: ${result.all.length} files';
      colossus.onExport?.call(result.all);
    } on Exception catch (e) {
      status.value = 'Save failed: $e';
    }
  }

  /// Toggle auto-replay on/off.
  Future<void> toggleAutoReplay(bool enabled) async {
    autoReplayEnabled.value = enabled;
    if (enabled && lastSession.value != null) {
      await colossus.saveSession(lastSession.value!);
      await colossus.setAutoReplay(
        enabled: true,
        sessionId: lastSession.value!.id,
        speed: replaySpeed.value,
      );
      autoReplaySessionId.value = lastSession.value!.id;
      status.value = 'Auto-replay enabled for ${lastSession.value!.name}';
      await _loadSavedSessions();
    } else {
      await colossus.setAutoReplay(enabled: false);
      autoReplaySessionId.value = null;
      status.value = 'Auto-replay disabled';
    }
  }

  /// Set a specific saved session as the auto-replay target.
  Future<void> setAutoReplaySession(String sessionId) async {
    await colossus.setAutoReplay(
      enabled: true,
      sessionId: sessionId,
      speed: replaySpeed.value,
    );
    autoReplayEnabled.value = true;
    autoReplaySessionId.value = sessionId;
    status.value = 'Auto-replay set for session';
  }

  /// Toggle auto-replay for a specific session.
  ///
  /// If the session is already the auto-replay target, disables
  /// auto-replay. Otherwise, sets it as the target.
  Future<void> toggleAutoReplayForSession(String sessionId) async {
    if (autoReplayEnabled.value && autoReplaySessionId.value == sessionId) {
      // Already set — disable
      await colossus.setAutoReplay(enabled: false);
      autoReplayEnabled.value = false;
      autoReplaySessionId.value = null;
      status.value = 'Auto-replay disabled';
    } else {
      // Enable for this session
      await setAutoReplaySession(sessionId);
    }
  }

  /// Delete a saved session from the vault.
  Future<void> deleteSavedSession(String sessionId) async {
    final vault = colossus.vault;
    if (vault == null) return;
    await vault.delete(sessionId);
    await _loadSavedSessions();
    status.value = 'Session deleted';
  }

  /// Delete all saved sessions from the vault.
  Future<void> deleteAllSessions() async {
    final vault = colossus.vault;
    if (vault == null) return;
    final count = await vault.deleteAll();
    await _loadSavedSessions();
    status.value = 'Deleted $count sessions';
  }

  /// Returns a mismatch message if the session's start route differs
  /// from the current route, or `null` if they match.
  String? checkRouteMismatch(ShadeSession session) {
    if (session.startRoute == null) return null;
    final getCurrentRoute = colossus.shade.getCurrentRoute;
    if (getCurrentRoute == null) return null;
    final currentRoute = getCurrentRoute();
    if (currentRoute == null) return null;
    if (currentRoute == session.startRoute) return null;
    return 'Recorded on "${session.startRoute}" '
        'but on "$currentRoute"';
  }

  // -- Private helpers -------------------------------------------------------

  /// Turn the Lens FAB into a "stop recording" button.
  void _activateFabRecording() {
    Lens.activeRecording.value = true;
    Lens.onStopRecording = _stopAndSaveFromFab;
  }

  /// Reset the Lens FAB to its normal state.
  void _deactivateFabRecording() {
    Lens.activeRecording.value = false;
    Lens.onStopRecording = null;
  }

  /// Called when the user taps the FAB while recording.
  void _stopAndSaveFromFab() {
    if (!colossus.shade.isRecording) return;
    final session = colossus.shade.stopRecording();
    lastSession.value = session;
    colossus.lastRecordedSession = session;
    _deactivateFabRecording();
    status.value =
        'Recorded ${session.eventCount} events in '
        '${session.duration.inMilliseconds}ms';
    // Auto-save to vault if available
    if (colossus.vault != null) {
      _autoSave(session);
    }

    // Re-open Lens so the user immediately sees the recorded session.
    // Use addPostFrameCallback to ensure the FAB state settles first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Lens.show();
    });
  }

  Future<void> _autoSave(ShadeSession session) async {
    try {
      final path = await colossus.saveSession(session);
      if (path != null) {
        status.value =
            'Auto-saved — ${session.eventCount} events in '
            '${session.duration.inMilliseconds}ms';
        await _loadSavedSessions();
      }
    } on Exception catch (e) {
      status.value = 'Auto-save failed: $e';
    }
  }

  Future<void> _loadAutoReplayConfig() async {
    final vault = colossus.vault;
    if (vault == null) return;
    final config = await vault.getAutoReplayConfig();
    if (config != null) {
      autoReplayEnabled.value = config.enabled;
      autoReplaySessionId.value = config.sessionId;
      replaySpeed.value = config.speed;
    }
  }

  Future<void> _loadSavedSessions() async {
    final vault = colossus.vault;
    if (vault == null) return;
    final sessions = await vault.list();
    savedSessions.value = sessions;
  }

  Future<void> _doReplay(ShadeSession session) async {
    final mismatch = checkRouteMismatch(session);
    final statusPrefix = mismatch != null ? '⚠ Route mismatch — ' : '';
    isReplaying.value = true;
    replayProgress.value = 0;
    replayTotal.value = session.eventCount;
    lastResult.value = null;
    status.value = '${statusPrefix}Replaying at ${replaySpeed.value}x...';
    final result = await colossus.replaySession(
      session,
      speedMultiplier: replaySpeed.value,
      waitForSettled: waitForSettledEnabled.value,
      onProgress: (current, total) {
        replayProgress.value = current;
        replayTotal.value = total;
      },
    );
    isReplaying.value = false;
    lastResult.value = result;
    if (result.routeChanged) {
      status.value = 'Replay stopped — invalid route: ${result.invalidRoute}';
    } else {
      status.value = result.wasCancelled
          ? 'Replay cancelled'
          : 'Replay complete — check Perf tab for metrics';
    }
  }
}

// ---------------------------------------------------------------------------
// Tab Content
// ---------------------------------------------------------------------------

/// Stateless host for the Shade Lens tab content.
///
/// Wraps the widget tree in a [Beacon] to provide [_ShadeLensPillar]
/// to the descendant [Vestige]. The Beacon creates, initializes
/// (triggering [_ShadeLensPillar.onInit]), and disposes the Pillar
/// automatically with the widget lifecycle.
///
/// All [Core.value] reads happen inside the [Vestige.builder] scope
/// via the helper functions (e.g. [_buildRecordingSection]), ensuring
/// the reactive engine can auto-track dependencies and trigger
/// rebuilds when state changes.
class _ShadeTabContent extends StatelessWidget {
  final Colossus colossus;

  const _ShadeTabContent({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Beacon(
      pillars: [() => _ShadeLensPillar(colossus)],
      child: Vestige<_ShadeLensPillar>(
        builder: (context, p) => ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _buildRecordingSection(p),
            const SizedBox(height: 8),
            _buildSpeedControl(p),
            const SizedBox(height: 4),
            _buildIntelligentWaitToggle(p),
            const SizedBox(height: 8),
            if (p.lastSession.value != null) _buildSessionInfo(p),
            if (p.isReplaying.value) _buildReplayProgress(p),
            if (p.lastResult.value != null && !p.isReplaying.value)
              _buildReplayResult(p),
            if (p.colossus.vault != null) ...[
              const SizedBox(height: 8),
              _buildLibrarySection(p),
            ],
            if (p.status.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                p.status.value,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UI Builder Helpers (run within Vestige scope for Core tracking)
// ---------------------------------------------------------------------------
//
// These functions are called from the Vestige<_ShadeLensPillar> builder,
// so all Core.value reads are auto-tracked by the TitanEffect. When any
// tracked Core changes, the Vestige triggers a rebuild. The functions
// themselves are stateless — they return Widgets based on the Pillar's
// current Core values.
//
// IMPORTANT: Do NOT move these into child StatelessWidgets, as their
// build() methods would run outside the TitanEffect scope and Core
// reads would not be tracked.
// ---------------------------------------------------------------------------

// -----------------------------------------------------------------------
// Recording controls
// -----------------------------------------------------------------------

Widget _buildRecordingSection(_ShadeLensPillar p) {
  final shade = p.colossus.shade;
  // Read via Core.value (not peek()) so the Vestige tracks this dependency
  // and rebuilds when recording state changes.
  final isRecording = shade.isRecordingCore.value;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            isRecording ? Icons.fiber_manual_record : Icons.circle_outlined,
            color: isRecording ? Colors.redAccent : Colors.white38,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isRecording ? 'Recording...' : 'Ready to record',
            style: TextStyle(
              color: isRecording ? Colors.redAccent : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isRecording) ...[
            const Spacer(),
            Text(
              '${shade.currentEventCount} events',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          if (!isRecording)
            _ActionButton(
              label: 'Record',
              icon: Icons.fiber_manual_record,
              color: Colors.redAccent,
              onTap: p.startRecording,
            ),
          if (isRecording) ...[
            _ActionButton(
              label: 'Stop',
              icon: Icons.stop,
              color: Colors.orangeAccent,
              onTap: p.stopRecording,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Cancel',
              icon: Icons.close,
              color: Colors.white38,
              onTap: p.cancelRecording,
            ),
          ],
          if (!isRecording && p.lastSession.value != null) ...[
            const SizedBox(width: 8),
            _ActionButton(
              label: 'Replay',
              icon: Icons.play_arrow,
              color: Colors.tealAccent,
              onTap: p.isReplaying.value ? null : p.replayCurrentSession,
            ),
            if (p.colossus.vault != null) ...[
              const SizedBox(width: 8),
              _ActionButton(
                label: 'Save',
                icon: Icons.save,
                color: Colors.blueAccent,
                onTap: p.saveCurrentSession,
              ),
            ],
          ],
        ],
      ),
    ],
  );
}

// -----------------------------------------------------------------------
// Speed control
// -----------------------------------------------------------------------

Widget _buildSpeedControl(_ShadeLensPillar p) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        const Text(
          'Speed:',
          style: TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(width: 8),
        for (final speed in [0.5, 1.0, 2.0, 5.0])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => p.replaySpeed.value = speed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: p.replaySpeed.value == speed
                      ? Colors.tealAccent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: p.replaySpeed.value == speed
                        ? Colors.tealAccent.withValues(alpha: 0.5)
                        : Colors.white12,
                  ),
                ),
                child: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: p.replaySpeed.value == speed
                        ? Colors.tealAccent
                        : Colors.white38,
                    fontSize: 9,
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

Widget _buildIntelligentWaitToggle(_ShadeLensPillar p) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: p.waitForSettledEnabled.value
          ? Colors.cyanAccent.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: p.waitForSettledEnabled.value
            ? Colors.cyanAccent.withValues(alpha: 0.3)
            : Colors.white10,
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.psychology,
          size: 12,
          color: p.waitForSettledEnabled.value
              ? Colors.cyanAccent
              : Colors.white38,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Wait for API / dialog',
            style: TextStyle(
              color: p.waitForSettledEnabled.value
                  ? Colors.cyanAccent
                  : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 20,
          child: Switch(
            value: p.waitForSettledEnabled.value,
            onChanged: (v) => p.waitForSettledEnabled.value = v,
            activeThumbColor: Colors.cyanAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------
// Session info
// -----------------------------------------------------------------------

Widget _buildSessionInfo(_ShadeLensPillar p) {
  final session = p.lastSession.value!;
  final routeMismatch = p.checkRouteMismatch(session);

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last Session',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        _LensInfoRow(label: 'Name', value: session.name),
        _LensInfoRow(label: 'Events', value: '${session.eventCount}'),
        _buildEventBreakdown(session),
        _LensInfoRow(
          label: 'Duration',
          value: '${session.duration.inMilliseconds}ms',
        ),
        _LensInfoRow(
          label: 'Screen',
          value:
              '${session.screenWidth.toInt()}×${session.screenHeight.toInt()}',
        ),
        if (session.startRoute != null)
          _LensInfoRow(label: 'Route', value: session.startRoute!),
        if (routeMismatch != null) ...[
          const SizedBox(height: 6),
          _buildRouteMismatchWarning(routeMismatch),
        ],
      ],
    ),
  );
}

Widget _buildEventBreakdown(ShadeSession session) {
  final textCount = session.imprints
      .where((i) => i.type == ImprintType.textInput)
      .length;
  final pointerCount = session.imprints
      .where(
        (i) =>
            i.type == ImprintType.pointerDown ||
            i.type == ImprintType.pointerUp ||
            i.type == ImprintType.pointerMove,
      )
      .length;
  final parts = <String>[];
  if (pointerCount > 0) parts.add('$pointerCount gesture');
  if (textCount > 0) parts.add('$textCount text');
  if (parts.isEmpty) return const SizedBox.shrink();
  return _LensInfoRow(label: 'Breakdown', value: parts.join(' · '));
}

Widget _buildRouteMismatchWarning(String message) {
  return Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 12,
          color: Colors.orangeAccent,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------
// Replay progress
// -----------------------------------------------------------------------

Widget _buildReplayProgress(_ShadeLensPillar p) {
  final progress = p.replayTotal.value > 0
      ? p.replayProgress.value / p.replayTotal.value
      : 0.0;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.tealAccent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.tealAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Replaying... ${p.replayProgress.value}/${p.replayTotal.value}',
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white12,
          color: Colors.tealAccent,
          minHeight: 3,
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------
// Replay result
// -----------------------------------------------------------------------

Widget _buildReplayResult(_ShadeLensPillar p) {
  final result = p.lastResult.value!;
  final colossus = p.colossus;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: (result.wasCancelled ? Colors.orangeAccent : Colors.greenAccent)
          .withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: (result.wasCancelled ? Colors.orangeAccent : Colors.greenAccent)
            .withValues(alpha: 0.3),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.routeChanged
              ? 'Invalid Route Detected'
              : result.wasCancelled
              ? 'Replay Cancelled'
              : 'Replay Complete',
          style: TextStyle(
            color: result.routeChanged
                ? Colors.redAccent
                : result.wasCancelled
                ? Colors.orangeAccent
                : Colors.greenAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (result.routeChanged) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wrong_location_outlined,
                  color: Colors.redAccent,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Route changed to: ${result.invalidRoute}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        _LensInfoRow(
          label: 'Dispatched',
          value: '${result.eventsDispatched}/${result.totalEvents}',
        ),
        _LensInfoRow(
          label: 'Duration',
          value: '${result.actualDuration.inMilliseconds}ms',
        ),
        _LensInfoRow(
          label: 'Expected',
          value: '${result.expectedDuration.inMilliseconds}ms',
        ),
        if (result.wasNormalized)
          const _LensInfoRow(label: 'Normalized', value: 'Yes'),
        const SizedBox(height: 6),
        // Metric checkmarks — what was monitored during replay
        _buildMetricChecks(colossus),
        const SizedBox(height: 6),
        // Report download buttons
        _buildReportActions(p),
      ],
    ),
  );
}

Widget _buildMetricChecks(Colossus colossus) {
  return Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Metrics Collected',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        _MetricCheckRow(
          label: 'Frame timing (Pulse)',
          value: '${colossus.pulse.totalFrames} frames',
          checked: colossus.pulse.totalFrames > 0,
        ),
        _MetricCheckRow(
          label: 'Jank detection',
          value: '${colossus.pulse.jankFrames} jank',
          checked: true,
        ),
        _MetricCheckRow(
          label: 'Memory (Vessel)',
          value: '${colossus.vessel.pillarCount} pillars',
          checked: true,
        ),
        _MetricCheckRow(
          label: 'Page loads (Stride)',
          value: '${colossus.stride.history.length} loads',
          checked: colossus.stride.history.isNotEmpty,
        ),
        _MetricCheckRow(
          label: 'Rebuilds (Echo)',
          value: '${colossus.rebuildsPerWidget.length} widgets',
          checked: colossus.rebuildsPerWidget.isNotEmpty,
        ),
        if (colossus.vessel.leakSuspects.isNotEmpty)
          _MetricCheckRow(
            label: 'Leak suspects',
            value: '${colossus.vessel.leakSuspects.length} found',
            checked: true,
            isWarning: true,
          ),
      ],
    ),
  );
}

Widget _buildReportActions(_ShadeLensPillar p) {
  return Row(
    children: [
      _ActionButton(
        label: 'Copy Report',
        icon: Icons.copy,
        color: Colors.blueAccent,
        onTap: p.copyReport,
      ),
      const SizedBox(width: 8),
      _ActionButton(
        label: 'Save Report',
        icon: Icons.download,
        color: Colors.greenAccent,
        onTap: p.saveReport,
      ),
    ],
  );
}

// -----------------------------------------------------------------------
// Session library
// -----------------------------------------------------------------------

Widget _buildLibrarySection(_ShadeLensPillar p) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onTap: () => p.showLibrary.value = !p.showLibrary.value,
        child: Row(
          children: [
            Icon(
              p.showLibrary.value ? Icons.expand_less : Icons.expand_more,
              color: Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Session Library (${p.savedSessions.value.length})',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (p.savedSessions.value.isNotEmpty)
              GestureDetector(
                onTap: p.deleteAllSessions,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.redAccent, fontSize: 9),
                ),
              ),
          ],
        ),
      ),
      if (p.showLibrary.value) ...[
        const SizedBox(height: 6),
        if (p.savedSessions.value.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'No saved sessions. Record and save a session to see it here.',
              style: TextStyle(color: Colors.white24, fontSize: 9),
            ),
          ),
        for (final summary in p.savedSessions.value)
          _SessionTile(
            summary: summary,
            isAutoReplayTarget:
                p.autoReplayEnabled.value &&
                p.autoReplaySessionId.value == summary.id,
            onReplay: () => p.replaySavedSession(summary.id),
            onDelete: () => p.deleteSavedSession(summary.id),
            onToggleAutoReplay: () => p.toggleAutoReplayForSession(summary.id),
          ),
      ],
    ],
  );
}

// ---------------------------------------------------------------------------
// Session tile
// ---------------------------------------------------------------------------

class _SessionTile extends StatelessWidget {
  final ShadeSessionSummary summary;
  final bool isAutoReplayTarget;
  final VoidCallback onReplay;
  final VoidCallback onDelete;
  final VoidCallback onToggleAutoReplay;

  const _SessionTile({
    required this.summary,
    this.isAutoReplayTarget = false,
    required this.onReplay,
    required this.onDelete,
    required this.onToggleAutoReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isAutoReplayTarget
            ? Colors.amber.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAutoReplayTarget
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  style: TextStyle(
                    color: isAutoReplayTarget ? Colors.amber : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isAutoReplayTarget
                      ? '${summary.eventCount} events · auto-replay'
                      : '${summary.eventCount} events · ${summary.durationMs}ms',
                  style: TextStyle(
                    color: isAutoReplayTarget
                        ? Colors.amber.withValues(alpha: 0.6)
                        : Colors.white30,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggleAutoReplay,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                isAutoReplayTarget ? Icons.replay_circle_filled : Icons.replay,
                size: 14,
                color: isAutoReplayTarget ? Colors.amber : Colors.white38,
              ),
            ),
          ),
          GestureDetector(
            onTap: onReplay,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.play_arrow, size: 14, color: Colors.tealAccent),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.delete_outline,
                size: 14,
                color: Colors.redAccent.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper Widgets
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: onTap != null
                ? color.withValues(alpha: 0.4)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: onTap != null ? color : Colors.white24),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? color : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LensInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _LensInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MetricCheckRow extends StatelessWidget {
  final String label;
  final String value;
  final bool checked;
  final bool isWarning;

  const _MetricCheckRow({
    required this.label,
    required this.value,
    required this.checked,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? Colors.orangeAccent
        : checked
        ? Colors.greenAccent
        : Colors.white24;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontSize: 9)),
          ),
          Text(
            value,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
