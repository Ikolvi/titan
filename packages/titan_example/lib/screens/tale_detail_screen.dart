import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/tavern_pillar.dart';

// ---------------------------------------------------------------------------
// TaleDetailScreen — Tale detail + comments via Quarry + Envoy
// ---------------------------------------------------------------------------
//
// Demonstrates:
//   Spark (hooks)           — useEffect for loading trigger
//   Quarry + Envoy          — SWR data fetching with retry
//   Stale-while-revalidate  — Background refresh indicator
//   Concurrent requests     — detail + comments loaded in parallel
//   Atlas                   — Back navigation with context.atlas.back()
// ---------------------------------------------------------------------------

/// Displays a single tale with its comments, fetched via Envoy HTTP.
///
/// Uses the Spark widget (hooks-based) to trigger loading on mount
/// and Vestige for reactive state rendering.
class TaleDetailScreen extends Spark {
  /// The tale ID parsed from the route (e.g. `/tale/42`).
  final String taleId;

  const TaleDetailScreen({super.key, required this.taleId});

  @override
  Widget ignite(BuildContext context) {
    final isMounted = useIsMounted();

    // Load tale detail + comments on mount
    useEffect(() {
      final id = int.tryParse(taleId);
      if (id != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isMounted()) {
            context.pillar<TavernPillar>().loadTaleDetail(id);
          }
        });
      }
      return null;
    }, [taleId]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tale Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
        actions: [
          Vestige<TavernPillar>(
            builder: (context, p) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: p.taleDetail.isFetching.value ? null : p.refreshDetail,
            ),
          ),
        ],
      ),
      body: Vestige<TavernPillar>(
        builder: (context, pillar) {
          final detail = pillar.taleDetail;
          final data = detail.data.value;
          final isLoading = detail.isLoading.value;
          final error = detail.error.value;

          // Loading state
          if (isLoading && data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (error != null && data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to load tale: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: pillar.refreshDetail,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // No data
          if (data == null) {
            return const Center(child: Text('No tale data'));
          }

          return _TaleDetailBody(pillar: pillar);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tale Detail Body
// ---------------------------------------------------------------------------

class _TaleDetailBody extends StatelessWidget {
  final TavernPillar pillar;

  const _TaleDetailBody({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tale = pillar.taleDetail.data.value!;
    final commentData = pillar.comments.data.value;
    final commentsLoading = pillar.comments.isLoading.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SWR background refresh indicator
          if (pillar.taleDetail.isFetching.value)
            const LinearProgressIndicator(),

          // Title
          Text(
            _capitalize(tale.title),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Author & metadata chips
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(tale.authorName ?? 'Unknown Hero'),
              ),
              Chip(
                avatar: const Icon(Icons.tag, size: 16),
                label: Text('Tale #${tale.id}'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tale body
          Text('The Tale', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(tale.body, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 32),

          // Comments section
          Row(
            children: [
              Text(
                'Comments',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (commentData != null)
                Chip(
                  label: Text('${commentData.length}'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (commentsLoading && commentData == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (commentData != null)
            ...commentData.map((comment) => _CommentCard(comment: comment))
          else
            const Text('No comments yet'),

          const SizedBox(height: 24),

          // Network info
          _NetworkInfoCard(pillar: pillar),
        ],
      ),
    );
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ---------------------------------------------------------------------------
// Comment Card
// ---------------------------------------------------------------------------

class _CommentCard extends StatelessWidget {
  final dynamic comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    comment.fullName.isNotEmpty
                        ? comment.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.fullName.isNotEmpty
                            ? comment.fullName
                            : comment.username,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '@${comment.username}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          if (comment.likes > 0) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.thumb_up,
                              size: 12,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${comment.likes}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment.body, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Network Info Card — shows request metrics for this detail load
// ---------------------------------------------------------------------------

class _NetworkInfoCard extends StatelessWidget {
  final TavernPillar pillar;

  const _NetworkInfoCard({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = pillar.metrics.value;
    // Show last 3 requests (detail + comments + maybe user)
    final recent = metrics.length > 3
        ? metrics.sublist(metrics.length - 3)
        : metrics;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.network_check,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Envoy Network Activity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recent.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    _StatusDot(statusCode: m.statusCode ?? 0),
                    const SizedBox(width: 8),
                    Text(
                      '${m.method} ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        m.url,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${m.duration.inMilliseconds}ms',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (m.cached) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.cached,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${pillar.totalRequests.value} requests • '
              'Avg: ${pillar.avgLatency.value.inMilliseconds}ms • '
              'Cache hits: ${pillar.cacheHits.value}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final int statusCode;

  const _StatusDot({required this.statusCode});

  @override
  Widget build(BuildContext context) {
    final color = statusCode >= 200 && statusCode < 300
        ? Colors.green
        : statusCode >= 400
        ? Colors.red
        : Colors.orange;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
