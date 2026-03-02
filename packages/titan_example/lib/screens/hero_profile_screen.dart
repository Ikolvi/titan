import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../models/hero.dart';
import '../pillars/questboard_pillar.dart';

/// Hero Profile Screen — hero stats with undo/redo.
///
/// Demonstrates: Epoch (undo/redo for hero name), Vestige (auto-tracking),
/// Core (reactive state), Derived (computed rank/progress).
class HeroProfileScreen extends StatelessWidget {
  const HeroProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Vestige<QuestboardPillar>(
      builder: (context, board) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Hero avatar
              CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  board.heroName.value.isNotEmpty
                      ? board.heroName.value[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 16),

              // Hero name with undo/redo
              Text(
                board.heroName.value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                board.heroClass.value.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),

              // Undo / Redo buttons for name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: board.heroName.canUndo ? board.undoName : null,
                    tooltip: 'Undo name change',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: board.heroName.canRedo ? board.redoName : null,
                    tooltip: 'Redo name change',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRenameDialog(context, board),
                    tooltip: 'Rename hero',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.star,
                      label: 'Glory',
                      value: '${board.glory.value}',
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Quests',
                      value: '${board.questsCompleted.value}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.shield,
                      label: 'Rank',
                      value: board.rank.value,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Rank progress
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rank Progress', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: board.rankProgress.value,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(board.rankProgress.value * 100).toStringAsFixed(0)}% to next rank',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hero class selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hero Class', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SegmentedButton<HeroClass>(
                        segments: HeroClass.values
                            .map(
                              (c) =>
                                  ButtonSegment(value: c, label: Text(c.label)),
                            )
                            .toList(),
                        selected: {board.heroClass.value},
                        onSelectionChanged: (s) => board.changeClass(s.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name history (from Epoch)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name History', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (board.heroName.history.isEmpty)
                        const Text('No name changes yet')
                      else
                        ...board.heroName.history.reversed
                            .take(5)
                            .map(
                              (name) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '• $name',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Registration button
              FilledButton.icon(
                onPressed: () => context.atlas.to('/register'),
                icon: const Icon(Icons.person_add),
                label: const Text('Register New Hero'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, QuestboardPillar board) {
    final controller = TextEditingController(text: board.heroName.value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Hero'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              board.renameHero(controller.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
