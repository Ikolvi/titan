import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_colossus/titan_colossus.dart';

/// Shade Demo Screen — gesture recording & macro replay.
///
/// Demonstrates: Shade, Imprint, ShadeSession, Phantom, PhantomResult.
///
/// Kael discovers the Shade — a silent recorder that captures every
/// gesture, tap, and scroll. With the Phantom, he can replay those
/// interactions to stress-test the Questboard under real-world usage.
class ShadeDemoScreen extends StatefulWidget {
  const ShadeDemoScreen({super.key});

  @override
  State<ShadeDemoScreen> createState() => _ShadeDemoScreenState();
}

class _ShadeDemoScreenState extends State<ShadeDemoScreen> {
  late final Shade _shade;
  ShadeSession? _lastSession;
  PhantomResult? _lastResult;
  _ShadeStatus _status = _ShadeStatus.idle;
  int _replayProgress = 0;
  int _replayTotal = 0;
  String _sessionName = '';

  // ShadeTextControllers for text input tracking
  late final ShadeTextController _heroNameController;
  late final ShadeTextController _questNoteController;

  @override
  void initState() {
    super.initState();

    // Use Colossus's shared Shade if available, otherwise create one
    _shade = Colossus.isActive ? Colossus.instance.shade : Shade();

    // Initialize ShadeTextControllers for automatic text capture
    _heroNameController = ShadeTextController(
      shade: _shade,
      fieldId: 'hero_name',
    );
    _questNoteController = ShadeTextController(
      shade: _shade,
      fieldId: 'quest_note',
    );

    _shade.onRecordingStarted = () {
      if (mounted) setState(() => _status = _ShadeStatus.recording);
    };

    _shade.onRecordingStopped = (session) {
      if (mounted) {
        setState(() {
          _lastSession = session;
          _status = _ShadeStatus.idle;
        });
      }
    };
  }

  @override
  void dispose() {
    _heroNameController.dispose();
    _questNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Shade & Phantom')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            _buildHeader(theme, colors),
            const SizedBox(height: 24),

            // --- Recording Controls ---
            _buildRecordingCard(theme, colors),
            const SizedBox(height: 16),

            // --- Session Info ---
            if (_lastSession != null) ...[
              _buildSessionCard(theme, colors),
              const SizedBox(height: 16),
            ],

            // --- Save Session ---
            if (_lastSession != null && Colossus.isActive) ...[
              _buildSaveCard(theme, colors),
              const SizedBox(height: 16),
            ],

            // --- Replay Controls ---
            if (_lastSession != null) ...[
              _buildReplayCard(theme, colors),
              const SizedBox(height: 16),
            ],

            // --- Replay Results ---
            if (_lastResult != null) ...[
              _buildResultsCard(theme, colors),
              const SizedBox(height: 16),
            ],

            // --- Interaction Playground ---
            _buildPlayground(theme, colors),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Header
  // -----------------------------------------------------------------------

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.fiber_smart_record,
              size: 40,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Shade Follows',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record your gestures, then let the Phantom '
                    'replay them to test performance.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Recording Controls
  // -----------------------------------------------------------------------

  Widget _buildRecordingCard(ThemeData theme, ColorScheme colors) {
    final isRecording = _status == _ShadeStatus.recording;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRecording ? Icons.stop_circle : Icons.radio_button_checked,
                  color: isRecording ? colors.error : colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recording',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isRecording) _RecordingIndicator(colors: colors),
              ],
            ),
            const SizedBox(height: 12),
            if (!isRecording) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Session Name',
                  hintText: 'e.g. quest_browse_flow',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onChanged: (v) => _sessionName = v,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (!isRecording)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.fiber_manual_record),
                      label: const Text('Start Recording'),
                      onPressed: _startRecording,
                    ),
                  )
                else ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.onError,
                      ),
                      onPressed: _stopRecording,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                    onPressed: _cancelRecording,
                  ),
                ],
              ],
            ),
            if (isRecording) ...[
              const SizedBox(height: 8),
              Text(
                'Navigate around the app — every tap, scroll, and '
                'swipe is being captured.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Session Info
  // -----------------------------------------------------------------------

  Widget _buildSessionCard(ThemeData theme, ColorScheme colors) {
    final session = _lastSession!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Last Session: ${session.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Events',
              value: '${session.eventCount}',
              icon: Icons.touch_app,
            ),
            _InfoRow(
              label: 'Duration',
              value: '${session.duration.inMilliseconds}ms',
              icon: Icons.timer,
            ),
            _InfoRow(
              label: 'Screen',
              value:
                  '${session.screenWidth.toInt()}×${session.screenHeight.toInt()}',
              icon: Icons.screenshot_monitor,
            ),
            _InfoRow(
              label: 'DPR',
              value: session.devicePixelRatio.toStringAsFixed(1),
              icon: Icons.aspect_ratio,
            ),
            if (session.startRoute != null)
              _InfoRow(
                label: 'Route',
                value: session.startRoute!,
                icon: Icons.route,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy JSON'),
                  onPressed: () => _copySessionJson(session),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text('Event Log'),
                  onPressed: () => _showEventLog(session),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Replay Controls
  // -----------------------------------------------------------------------

  Widget _buildReplayCard(ThemeData theme, ColorScheme colors) {
    final isReplaying = _status == _ShadeStatus.replaying;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.replay, color: colors.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Phantom Replay',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isReplaying && _replayTotal > 0) ...[
              LinearProgressIndicator(value: _replayProgress / _replayTotal),
              const SizedBox(height: 8),
              Text(
                'Replaying event $_replayProgress / $_replayTotal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.outline,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Replay 1×'),
                      onPressed: _status == _ShadeStatus.idle
                          ? () => _replaySession(1.0)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.fast_forward),
                      label: const Text('Replay 2×'),
                      onPressed: _status == _ShadeStatus.idle
                          ? () => _replaySession(2.0)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.speed),
                      label: const Text('Replay 5×'),
                      onPressed: _status == _ShadeStatus.idle
                          ? () => _replaySession(5.0)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Replay Results
  // -----------------------------------------------------------------------

  Widget _buildResultsCard(ThemeData theme, ColorScheme colors) {
    final result = _lastResult!;

    return Card(
      color: result.wasCancelled
          ? colors.errorContainer
          : colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.wasCancelled ? Icons.cancel : Icons.check_circle,
                  color: result.wasCancelled
                      ? colors.onErrorContainer
                      : colors.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  result.wasCancelled ? 'Replay Cancelled' : 'Replay Complete',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: result.wasCancelled
                        ? colors.onErrorContainer
                        : colors.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Events Dispatched',
              value: '${result.eventsDispatched} / ${result.totalEvents}',
              icon: Icons.send,
            ),
            _InfoRow(
              label: 'Actual Duration',
              value: '${result.actualDuration.inMilliseconds}ms',
              icon: Icons.timer,
            ),
            _InfoRow(
              label: 'Expected Duration',
              value: '${result.expectedDuration.inMilliseconds}ms',
              icon: Icons.schedule,
            ),
            _InfoRow(
              label: 'Speed Ratio',
              value: '${result.speedRatio.toStringAsFixed(2)}×',
              icon: Icons.speed,
            ),
            if (result.eventsSkipped > 0)
              _InfoRow(
                label: 'Skipped',
                value: '${result.eventsSkipped}',
                icon: Icons.skip_next,
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Interaction Playground — test area for recording gestures
  // -----------------------------------------------------------------------

  Widget _buildSaveCard(ThemeData theme, ColorScheme colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.save, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Session Vault',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save Session'),
                    onPressed: _saveSession,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay_circle_filled),
                    label: Text(
                      'Auto-replay: ${_autoReplayEnabled ? "ON" : "OFF"}',
                    ),
                    onPressed: _toggleAutoReplay,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _autoReplayEnabled = false;

  Future<void> _saveSession() async {
    if (_lastSession == null || !Colossus.isActive) return;

    final path = await Colossus.instance.saveSession(_lastSession!);
    if (path != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session saved to vault')));
    }
  }

  Future<void> _toggleAutoReplay() async {
    if (_lastSession == null || !Colossus.isActive) return;

    _autoReplayEnabled = !_autoReplayEnabled;

    if (_autoReplayEnabled) {
      await Colossus.instance.saveSession(_lastSession!);
      await Colossus.instance.setAutoReplay(
        enabled: true,
        sessionId: _lastSession!.id,
        speed: 1.0,
      );
    } else {
      await Colossus.instance.setAutoReplay(enabled: false);
    }

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _autoReplayEnabled
                ? 'Auto-replay enabled — session will replay on restart'
                : 'Auto-replay disabled',
          ),
        ),
      );
    }
  }

  Widget _buildPlayground(ThemeData theme, ColorScheme colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports, color: colors.secondary),
                const SizedBox(width: 8),
                Text(
                  'Interaction Playground',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use these controls while recording to capture '
              'different gesture types.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.outline),
            ),
            const SizedBox(height: 16),

            // Text input fields (tracked via ShadeTextController)
            TextField(
              controller: _heroNameController,
              decoration: const InputDecoration(
                labelText: 'Hero Name',
                hintText: 'Type to capture text input...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _questNoteController,
              decoration: const InputDecoration(
                labelText: 'Quest Note',
                hintText: 'Another tracked text field...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Tap targets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlaygroundButton(
                  label: 'Claim Quest',
                  icon: Icons.add_task,
                  color: colors.primary,
                  onColor: colors.onPrimary,
                ),
                _PlaygroundButton(
                  label: 'View Hero',
                  icon: Icons.person,
                  color: colors.secondary,
                  onColor: colors.onSecondary,
                ),
                _PlaygroundButton(
                  label: 'Open Map',
                  icon: Icons.map,
                  color: colors.tertiary,
                  onColor: colors.onTertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Slider
            _PlaygroundSlider(colors: colors),
            const SizedBox(height: 12),

            // Scrollable list
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 20,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, color: colors.primary),
                        const SizedBox(height: 4),
                        Text(
                          'Quest ${index + 1}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  void _startRecording() {
    _shade.startRecording(name: _sessionName.isNotEmpty ? _sessionName : null);
    setState(() => _status = _ShadeStatus.recording);
  }

  void _stopRecording() {
    final session = _shade.stopRecording();
    setState(() {
      _lastSession = session;
      _status = _ShadeStatus.idle;
    });
  }

  void _cancelRecording() {
    _shade.cancelRecording();
    setState(() => _status = _ShadeStatus.idle);
  }

  Future<void> _replaySession(double speed) async {
    final session = _lastSession;
    if (session == null) return;

    setState(() {
      _status = _ShadeStatus.replaying;
      _replayProgress = 0;
      _replayTotal = session.eventCount;
      _lastResult = null;
    });

    PhantomResult result;

    if (Colossus.isActive) {
      // Use Colossus convenience method (resets metrics automatically)
      result = await Colossus.instance.replaySession(
        session,
        speedMultiplier: speed,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _replayProgress = current;
              _replayTotal = total;
            });
          }
        },
      );
    } else {
      // Standalone Phantom replay
      final phantom = Phantom(
        speedMultiplier: speed,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _replayProgress = current;
              _replayTotal = total;
            });
          }
        },
      );
      result = await phantom.replay(session);
    }

    if (mounted) {
      setState(() {
        _lastResult = result;
        _status = _ShadeStatus.idle;
      });
    }
  }

  void _copySessionJson(ShadeSession session) {
    final json = const JsonEncoder.withIndent('  ').convert(session.toJson());
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session JSON copied to clipboard')),
    );
  }

  void _showEventLog(ShadeSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Event Log — ${session.eventCount} Imprints',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: session.imprints.length,
                    itemBuilder: (context, index) {
                      final imprint = session.imprints[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        title: Text(imprint.type.name),
                        subtitle: Text(
                          '(${imprint.positionX.toInt()}, '
                          '${imprint.positionY.toInt()}) '
                          'at ${imprint.timestamp.inMilliseconds}ms',
                        ),
                        trailing: Text(
                          'ptr ${imprint.pointer}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

enum _ShadeStatus { idle, recording, replaying }

// ---------------------------------------------------------------------------
// Recording indicator — pulsing red dot with event count
// ---------------------------------------------------------------------------

/// Pulsing red dot with "REC" label — converted from StatefulWidget to Spark.
///
/// Uses [useAnimationController] + [useAnimation] to eliminate manual
/// controller lifecycle (initState, dispose) and [AnimatedBuilder].
class _RecordingIndicator extends Spark {
  final ColorScheme colors;

  const _RecordingIndicator({required this.colors});

  @override
  Widget ignite(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    final pulse = useAnimation(controller);

    useEffect(() {
      controller.repeat(reverse: true);
      return null;
    }, const []);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.5 + pulse * 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'REC',
          style: TextStyle(
            color: colors.error,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info row helper
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playground button
// ---------------------------------------------------------------------------

class _PlaygroundButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;

  const _PlaygroundButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: onColor,
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label tapped!'),
            duration: const Duration(milliseconds: 500),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Playground slider
// ---------------------------------------------------------------------------

/// Playground slider — converted from StatefulWidget to Spark.
///
/// Uses [useCore] for the slider value instead of manual [setState].
class _PlaygroundSlider extends Spark {
  final ColorScheme colors;

  const _PlaygroundSlider({required this.colors});

  @override
  Widget ignite(BuildContext context) {
    final value = useCore(0.5);

    return Row(
      children: [
        const Icon(Icons.exposure_minus_1, size: 16),
        Expanded(
          child: Slider(
            value: value.value,
            onChanged: (v) => value.value = v,
            activeColor: colors.primary,
          ),
        ),
        const Icon(Icons.exposure_plus_1, size: 16),
        const SizedBox(width: 8),
        Text('${(value.value * 100).toInt()}%'),
      ],
    );
  }
}
