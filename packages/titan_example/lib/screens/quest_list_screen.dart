import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../models/quest.dart';
import '../pillars/quest_list_pillar.dart';
import '../pillars/questboard_pillar.dart';

/// Quest List Screen — paginated quest listing.
///
/// Demonstrates: Confluence (multi-Pillar consumer), Codex (pagination),
/// Vestige (single-Pillar consumer), Atlas (navigation).
class QuestListScreen extends StatelessWidget {
  const QuestListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Confluence2<QuestboardPillar, QuestListPillar>(
      builder: (context, board, list) {
        final quests = list.quests;
        final items = quests.items.value;
        final isLoading = quests.isLoading.value;
        final hasMore = quests.hasMore.value;
        final error = quests.error.value;

        return Column(
          children: [
            // Hero glory banner
            _GloryBanner(
              heroName: board.heroName.value,
              glory: board.glory.value,
              rank: board.rank.value,
              progress: board.rankProgress.value,
            ),

            // Error banner
            if (error != null)
              MaterialBanner(
                content: Text('Error: $error'),
                backgroundColor: Colors.red.shade100,
                actions: [
                  TextButton(
                    onPressed: list.refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),

            // Quest list
            Expanded(
              child: isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: list.refresh,
                      child: ListView.builder(
                        itemCount: items.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= items.length) {
                            // Load more trigger
                            list.loadMore();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _QuestTile(
                            quest: items[index],
                            onTap: () =>
                                context.atlas.to('/quest/${items[index].id}'),
                            onComplete: items[index].isCompleted
                                ? null
                                : () => list.completeQuest(items[index]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _GloryBanner extends StatelessWidget {
  final String heroName;
  final int glory;
  final String rank;
  final double progress;

  const _GloryBanner({
    required this.heroName,
    required this.glory,
    required this.rank,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heroName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text('$glory Glory • $rank'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final Quest quest;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const _QuestTile({required this.quest, this.onTap, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: quest.isCompleted
            ? Colors.green.shade100
            : _difficultyColor(quest.difficulty),
        child: quest.isCompleted
            ? const Icon(Icons.check, color: Colors.green)
            : Text(
                quest.difficulty.label[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
      title: Text(
        quest.title,
        style: quest.isCompleted
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )
            : null,
      ),
      subtitle: Text('${quest.difficulty.label} • ${quest.gloryReward} glory'),
      trailing: onComplete != null
          ? IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: onComplete,
              tooltip: 'Complete Quest',
            )
          : null,
    );
  }

  Color _difficultyColor(QuestDifficulty d) => switch (d) {
    QuestDifficulty.novice => Colors.green.shade100,
    QuestDifficulty.warrior => Colors.orange.shade100,
    QuestDifficulty.champion => Colors.purple.shade100,
    QuestDifficulty.titan => Colors.red.shade100,
  };
}
