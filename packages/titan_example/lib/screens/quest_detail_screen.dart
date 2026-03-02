import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/quest_detail_pillar.dart';

/// Quest Detail Screen — single quest view using Spark hooks.
///
/// Demonstrates: Quarry (data fetching with SWR), Vestige (auto-tracking),
/// Spark (useEffect + useIsMounted for safe loading trigger), Atlas
/// (waypoint runes for URL params).
class QuestDetailScreen extends Spark {
  final String questId;

  const QuestDetailScreen({super.key, required this.questId});

  @override
  Widget ignite(BuildContext context) {
    final isMounted = useIsMounted();

    // Trigger quest loading on mount — replaces StatefulWidget.initState
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isMounted()) {
          context.pillar<QuestDetailPillar>().loadQuest(questId);
        }
      });
      return null;
    }, [questId]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
        actions: [
          Vestige<QuestDetailPillar>(
            builder: (context, p) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: p.quest.isFetching.value ? null : p.refresh,
            ),
          ),
        ],
      ),
      body: Vestige<QuestDetailPillar>(
        builder: (context, p) {
          final quest = p.quest;
          final data = quest.data.value;
          final isLoading = quest.isLoading.value;
          final error = quest.error.value;

          if (isLoading && data == null) {
            return const Center(child: CircularProgressIndicator());
          }

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
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: p.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (data == null) {
            return const Center(child: Text('No quest data'));
          }

          final theme = Theme.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stale indicator (SWR background refresh)
                if (quest.isFetching.value) const LinearProgressIndicator(),

                // Title
                Text(
                  data.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Status chips
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.shield, size: 16),
                      label: Text(data.difficulty.label),
                    ),
                    Chip(
                      avatar: const Icon(Icons.star, size: 16),
                      label: Text('${data.gloryReward} Glory'),
                    ),
                    if (data.isCompleted)
                      const Chip(
                        avatar: Icon(Icons.check_circle, size: 16),
                        label: Text('Completed'),
                        backgroundColor: Colors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                Text('Description', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(data.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),

                // Quest ID
                Text(
                  'Quest ID: ${data.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
