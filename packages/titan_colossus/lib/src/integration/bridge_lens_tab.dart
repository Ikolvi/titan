import 'package:flutter/material.dart';

import '../colossus.dart';
import 'colossus_argus.dart';
import 'colossus_basalt.dart';
import 'colossus_bastion.dart';
import 'lens.dart';

// ---------------------------------------------------------------------------
// BridgeLensTab — Lens Plugin for Cross-Package Integration Events
// ---------------------------------------------------------------------------

/// A [LensPlugin] that adds a "Bridge" tab to the Lens debug overlay.
///
/// Displays real-time cross-package integration events from the
/// Colossus bridge system:
///
/// - **Atlas** — navigation, guard redirects, drift redirects, 404s
/// - **Basalt** — circuit trips/recovery, rate limiting, mutex contention
/// - **Argus** — login/logout events
/// - **Bastion** — Pillar lifecycle, state mutation heat maps
///
/// Also shows aggregate metrics and bridge connection status.
///
/// This plugin is automatically registered when `Colossus.init()`
/// is called with `enableLensTab: true` (the default).
///
/// ```dart
/// // Events appear automatically when bridges are connected:
/// ColossusBasalt.monitorPortcullis('api', breaker);
/// ColossusArgus.connect();
/// ColossusBastion.connect();
/// ```
class BridgeLensTab extends LensPlugin {
  final Colossus _colossus;

  /// Creates a [BridgeLensTab] for the given [Colossus] instance.
  BridgeLensTab(this._colossus);

  @override
  String get title => 'Bridge';

  @override
  IconData get icon => Icons.sync_alt;

  @override
  Widget build(BuildContext context) {
    return _BridgeTabContent(colossus: _colossus);
  }
}

// ---------------------------------------------------------------------------
// Tab Content
// ---------------------------------------------------------------------------

class _BridgeTabContent extends StatelessWidget {
  final Colossus colossus;

  const _BridgeTabContent({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Localizations(
      locale: const Locale('en'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const _SubTabBar(),
            Expanded(
              child: TabBarView(
                physics: const ClampingScrollPhysics(),
                children: [
                  _EventsView(colossus: colossus),
                  _StatusView(colossus: colossus),
                  _HeatMapView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-Tab Bar
// ---------------------------------------------------------------------------

class _SubTabBar extends StatelessWidget {
  const _SubTabBar();

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: Colors.tealAccent,
      unselectedLabelColor: Colors.white38,
      indicatorColor: Colors.tealAccent,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      tabs: [
        Tab(text: 'Events'),
        Tab(text: 'Status'),
        Tab(text: 'Heat Map'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Events View — Live event feed
// ---------------------------------------------------------------------------

class _EventsView extends StatelessWidget {
  final Colossus colossus;

  const _EventsView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    final events = colossus.events;

    if (events.isEmpty) {
      return const Center(
        child: Text(
          'No bridge events yet.\n'
          'Connect bridges to start tracking.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    // Show newest first
    final reversed = events.reversed.toList();

    return ListView.builder(
      key: const PageStorageKey('bridge_events'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final event = reversed[index];
        return _EventCard(event: event);
      },
    );
  }
}

/// Card displaying a single integration event.
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final source = event['source'] as String? ?? 'unknown';
    final type = event['type'] as String? ?? 'unknown';
    final timestamp = event['timestamp'] as String? ?? '';

    // Format timestamp to show just time portion
    final timePart = timestamp.length >= 19
        ? timestamp.substring(11, 19)
        : timestamp;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF262636),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _sourceColor(source).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Source badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _sourceColor(source).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              source.toUpperCase(),
              style: TextStyle(
                color: _sourceColor(source),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Event type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_eventDetail(event) != null)
                  Text(
                    _eventDetail(event)!,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Timestamp
          Text(
            timePart,
            style: TextStyle(
              color: Colors.white24,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'atlas':
        return Colors.blueAccent;
      case 'basalt':
        return Colors.orangeAccent;
      case 'argus':
        return Colors.purpleAccent;
      case 'bastion':
        return Colors.tealAccent;
      default:
        return Colors.white54;
    }
  }

  String? _eventDetail(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    switch (type) {
      case 'navigate':
        return '${event['from']} → ${event['to']}';
      case 'pop':
        return '${event['from']} ← ${event['to']}';
      case 'guard_redirect':
        return '${event['originalPath']} → ${event['redirectPath']}';
      case 'drift_redirect':
        return '${event['originalPath']} → ${event['redirectPath']}';
      case 'not_found':
        return event['path'] as String?;
      case 'circuit_trip':
        return '${event['name']} (failures: ${event['failureCount']})';
      case 'circuit_recover':
        return '${event['name']}';
      case 'rate_limit_hit':
        return '${event['name']} (${event['totalRejections']} rejected)';
      case 'mutex_contention':
        return '${event['name']} (queue: ${event['queueLength']})';
      case 'health_degraded':
      case 'health_down':
      case 'health_recovered':
        return event['name'] as String?;
      case 'login':
      case 'logout':
        return null;
      case 'pillar_init':
      case 'pillar_dispose':
        return event['pillar'] as String?;
      case 'effect_error':
        return event['error'] as String?;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Status View — Bridge connection overview
// ---------------------------------------------------------------------------

class _StatusView extends StatelessWidget {
  final Colossus colossus;

  const _StatusView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    final events = colossus.events;

    // Count events by source
    final sourceCounts = <String, int>{};
    for (final e in events) {
      final source = e['source'] as String? ?? 'unknown';
      sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
    }

    return ListView(
      key: const PageStorageKey('bridge_status'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      children: [
        // Bridge connections
        _SectionHeader(title: 'CONNECTIONS'),
        _ConnectionRow(
          name: 'Argus (Auth)',
          isConnected: ColossusArgus.isConnected,
          color: Colors.purpleAccent,
        ),
        _ConnectionRow(
          name: 'Bastion (Reactive)',
          isConnected: ColossusBastion.isConnected,
          color: Colors.tealAccent,
        ),
        _ConnectionRow(
          name: 'Basalt (Resilience)',
          isConnected: ColossusBasalt.isActive,
          detail: ColossusBasalt.isActive
              ? '${ColossusBasalt.monitoredComponents.length} monitors'
              : null,
          color: Colors.orangeAccent,
        ),
        _ConnectionRow(
          name: 'Atlas (Routing)',
          isConnected: true, // Always connected via observer
          detail: 'via ColossusAtlasObserver',
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 12),

        // Aggregate metrics
        _SectionHeader(title: 'TOTALS'),
        _MetricRow(label: 'Total events', value: '${events.length}'),
        for (final entry in sourceCounts.entries)
          _MetricRow(
            label: '  ${entry.key}',
            value: '${entry.value}',
            color: _sourceColor(entry.key),
          ),
        const SizedBox(height: 12),

        // Bastion specifics
        if (ColossusBastion.isConnected) ...[
          _SectionHeader(title: 'BASTION METRICS'),
          _MetricRow(
            label: 'Pillar inits',
            value: '${ColossusBastion.pillarInitCount}',
          ),
          _MetricRow(
            label: 'Pillar disposes',
            value: '${ColossusBastion.pillarDisposeCount}',
          ),
          _MetricRow(
            label: 'Total mutations',
            value: '${ColossusBastion.totalStateMutations}',
          ),
          _MetricRow(
            label: 'Effect errors',
            value: '${ColossusBastion.effectErrorCount}',
            color: ColossusBastion.effectErrorCount > 0
                ? Colors.redAccent
                : Colors.white54,
          ),
          const SizedBox(height: 12),
        ],

        // Basalt monitors
        if (ColossusBasalt.isActive) ...[
          _SectionHeader(title: 'BASALT MONITORS'),
          for (final name in ColossusBasalt.monitoredComponents)
            _MetricRow(label: name, value: '●', color: Colors.orangeAccent),
        ],
      ],
    );
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'atlas':
        return Colors.blueAccent;
      case 'basalt':
        return Colors.orangeAccent;
      case 'argus':
        return Colors.purpleAccent;
      case 'bastion':
        return Colors.tealAccent;
      default:
        return Colors.white54;
    }
  }
}

// ---------------------------------------------------------------------------
// Heat Map View — State mutation frequency
// ---------------------------------------------------------------------------

class _HeatMapView extends StatelessWidget {
  const _HeatMapView();

  @override
  Widget build(BuildContext context) {
    if (!ColossusBastion.isConnected) {
      return const Center(
        child: Text(
          'Bastion bridge not connected.\n'
          'Enable autoBastionMetrics in ColossusPlugin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    final heatMap = ColossusBastion.stateHeatMap;
    if (heatMap.isEmpty) {
      return const Center(
        child: Text(
          'No state mutations recorded yet.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    // Sort by mutation count (highest first)
    final sorted = heatMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sorted.first.value;

    return ListView.builder(
      key: const PageStorageKey('bridge_heatmap'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: sorted.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MetricRow(
              label: 'Total mutations',
              value: '${ColossusBastion.totalStateMutations}',
              color: Colors.tealAccent,
            ),
          );
        }

        final entry = sorted[index - 1];
        final ratio = maxCount > 0 ? entry.value / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      color: _heatColor(ratio),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Heat bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF333346),
                  valueColor: AlwaysStoppedAnimation(_heatColor(ratio)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _heatColor(double ratio) {
    if (ratio > 0.8) return Colors.redAccent;
    if (ratio > 0.5) return Colors.orangeAccent;
    if (ratio > 0.2) return Colors.amber;
    return Colors.tealAccent;
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

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

class _ConnectionRow extends StatelessWidget {
  final String name;
  final bool isConnected;
  final String? detail;
  final Color color;

  const _ConnectionRow({
    required this.name,
    required this.isConnected,
    this.detail,
    this.color = Colors.tealAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: isConnected ? color : Colors.white24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isConnected ? Colors.white70 : Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
          if (detail != null)
            Text(
              detail!,
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
