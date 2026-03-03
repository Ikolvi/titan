import 'package:flutter/material.dart';
import 'package:titan_basalt/titan_basalt.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/enterprise_demo_pillar.dart';

/// Enterprise Demo Screen — showcases enterprise features.
///
/// Demonstrates: Loom, Portcullis, Saga, Volley, Sigil, Aegis, Annals, Banner, Sieve,
/// Lattice, Embargo, Census, Warden, Arbiter, Lode, Tether, Core extensions, onInitAsync, VestigeWhen, VestigeSelector.
class EnterpriseDemoScreen extends StatelessWidget {
  const EnterpriseDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Beacon(
      pillars: [EnterpriseDemoPillar.new],
      child: Scaffold(
        appBar: AppBar(title: const Text('Enterprise Features')),
        body: Vestige<EnterpriseDemoPillar>(
          builder: (context, p) {
            if (!p.isReady.value) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing enterprise features...'),
                  ],
                ),
              );
            }
            return const _EnterpriseTabs();
          },
        ),
      ),
    );
  }
}

class _EnterpriseTabs extends StatelessWidget {
  const _EnterpriseTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 16,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Loom'),
              Tab(text: 'Portcullis'),
              Tab(text: 'Saga'),
              Tab(text: 'Volley'),
              Tab(text: 'Conduit'),
              Tab(text: 'Prism'),
              Tab(text: 'Nexus'),
              Tab(text: 'Trove'),
              Tab(text: 'Moat'),
              Tab(text: 'Omen'),
              Tab(text: 'Pyre'),
              Tab(text: 'Mandate'),
              Tab(text: 'Ledger'),
              Tab(text: 'Portcullis+'),
              Tab(text: 'Anvil'),
              Tab(text: 'Toolkit'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _LoomTab(),
                _PortcullisTab(),
                _SagaTab(),
                _VolleyTab(),
                _ConduitTab(),
                _PrismTab(),
                _NexusTab(),
                _TroveTab(),
                _MoatTab(),
                _OmenTab(),
                _PyreTab(),
                _MandateTab(),
                _LedgerTab(),
                _PortcullisDetailTab(),
                _AnvilTab(),
                _ToolkitTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loom Tab — Finite State Machine
// ---------------------------------------------------------------------------

class _LoomTab extends StatelessWidget {
  const _LoomTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        final status = p.questStatus.current;
        final allowed = p.questStatus.allowedEvents;
        final history = p.questStatus.history;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Quest Status Machine'),
              const SizedBox(height: 8),
              // Current state chip
              Center(
                child: Chip(
                  avatar: Icon(_statusIcon(status)),
                  label: Text(status.name.toUpperCase()),
                  backgroundColor: _statusColor(status),
                ),
              ),
              const SizedBox(height: 16),

              // Available actions
              Text(
                'Available Actions:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: QuestAction.values.map((action) {
                  final canSend = allowed.contains(action);
                  return FilledButton.tonal(
                    onPressed: canSend
                        ? () => p.questStatus.send(action)
                        : null,
                    child: Text(action.name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Transition history
              Text(
                'Transition History:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                const Text('No transitions yet')
              else
                ...history.reversed
                    .take(10)
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${t.from.name} → ${t.to.name} (${t.event.name})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  IconData _statusIcon(QuestStatus s) => switch (s) {
    QuestStatus.available => Icons.flag_outlined,
    QuestStatus.claiming => Icons.hourglass_top,
    QuestStatus.active => Icons.play_arrow,
    QuestStatus.completed => Icons.check_circle,
    QuestStatus.failed => Icons.error,
  };

  Color _statusColor(QuestStatus s) => switch (s) {
    QuestStatus.available => Colors.blue.shade100,
    QuestStatus.claiming => Colors.orange.shade100,
    QuestStatus.active => Colors.green.shade100,
    QuestStatus.completed => Colors.teal.shade100,
    QuestStatus.failed => Colors.red.shade100,
  };
}

// ---------------------------------------------------------------------------
// Portcullis Tab — Circuit Breaker
// ---------------------------------------------------------------------------

class _PortcullisTab extends StatelessWidget {
  const _PortcullisTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        final breakerState = p.apiBreaker.state;
        final failures = p.apiBreaker.failureCount;
        final quest = p.protectedQuest.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Circuit Breaker'),
              const SizedBox(height: 8),

              // Circuit status
              Card(
                child: ListTile(
                  leading: Icon(
                    breakerState == PortcullisState.closed
                        ? Icons.check_circle
                        : breakerState == PortcullisState.halfOpen
                        ? Icons.warning
                        : Icons.block,
                    color: breakerState == PortcullisState.closed
                        ? Colors.green
                        : breakerState == PortcullisState.halfOpen
                        ? Colors.orange
                        : Colors.red,
                  ),
                  title: Text('State: ${breakerState.name}'),
                  subtitle: Text('Failures: $failures / 3'),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => p.fetchProtected('quest-0'),
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Fetch'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: p.apiBreaker.trip,
                    child: const Text('Trip'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: p.apiBreaker.reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Result
              if (quest != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield),
                    title: Text(quest.title),
                    subtitle: Text(
                      '${quest.difficulty.label} • ${quest.gloryReward} glory',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Saga Tab — Multi-Step Workflow
// ---------------------------------------------------------------------------

class _SagaTab extends StatelessWidget {
  const _SagaTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        final saga = p.publishSaga;
        final status = saga.status;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Quest Publish Saga'),
              const SizedBox(height: 8),

              // Status
              Card(
                child: ListTile(
                  leading: Icon(_sagaIcon(status)),
                  title: Text('Status: ${status.name}'),
                  subtitle: status == SagaStatus.running
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: saga.progress),
                            const SizedBox(height: 4),
                            Text('Step: ${saga.currentStepName ?? "—"}'),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Simulate failure toggle
              SwitchListTile(
                title: const Text('Simulate failure'),
                subtitle: const Text('Saga will fail at publish step'),
                value: p.shouldFailSaga.value,
                onChanged: (v) => p.shouldFailSaga.value = v,
              ),
              const SizedBox(height: 8),

              // Run button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saga.isRunning ? null : p.runPublishSaga,
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text('Run Publish Saga'),
                ),
              ),
              const SizedBox(height: 8),

              // Error
              if (saga.error != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${saga.error}')),
                      ],
                    ),
                  ),
                ),

              // Compensation errors (if any)
              if (saga.compensationErrors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Compensation errors '
                              '(${saga.compensationErrors.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final e in saga.compensationErrors)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $e',
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _sagaIcon(SagaStatus s) => switch (s) {
    SagaStatus.idle => Icons.pause_circle,
    SagaStatus.running => Icons.play_circle,
    SagaStatus.completed => Icons.check_circle,
    SagaStatus.compensating => Icons.undo,
    SagaStatus.failed => Icons.error,
  };
}

// ---------------------------------------------------------------------------
// Volley Tab — Batch Async Operations
// ---------------------------------------------------------------------------

class _VolleyTab extends StatelessWidget {
  const _VolleyTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        final batch = p.batchRunner;
        final status = batch.status;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader('Batch Operations (Volley)'),
              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: Icon(
                    status == VolleyStatus.running
                        ? Icons.sync
                        : status == VolleyStatus.done
                        ? Icons.done_all
                        : Icons.hourglass_empty,
                  ),
                  title: Text('Status: ${status.name}'),
                  subtitle: status == VolleyStatus.running
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: batch.progress),
                            const SizedBox(height: 4),
                            Text(
                              '${batch.completedCount} / ${batch.totalCount}',
                            ),
                          ],
                        )
                      : status == VolleyStatus.done
                      ? Text(
                          '${batch.successCount} succeeded, '
                          '${batch.failedCount} failed',
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: batch.isRunning ? null : p.runBatch,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Run 5 Tasks'),
                    ),
                  ),
                  if (batch.isRunning) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: batch.cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Conduit Tab — Core-Level Middleware
// ---------------------------------------------------------------------------

class _ConduitTab extends StatelessWidget {
  const _ConduitTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Clamp Conduit ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ClampConduit — Quest Reward',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reward is clamped to 0–10,000. Try setting values '
                      'outside the range.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current reward: ${p.questReward.value}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => p.questReward.value = 500,
                          child: const Text('Set 500'),
                        ),
                        FilledButton(
                          onPressed: () => p.questReward.value = 15000,
                          child: const Text('Set 15,000 (clamped)'),
                        ),
                        FilledButton(
                          onPressed: () => p.questReward.value = -100,
                          child: const Text('Set -100 (clamped)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Transform Conduit ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TransformConduit — Hero Name',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Trims whitespace and converts to lowercase '
                      'automatically.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Stored: "${p.heroNameInput.value}"',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () =>
                              p.heroNameInput.value = '  SIR LANCELOT  ',
                          child: const Text('Set "  SIR LANCELOT  "'),
                        ),
                        FilledButton(
                          onPressed: () => p.heroNameInput.value = '   KAEL   ',
                          child: const Text('Set "   KAEL   "'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Validate Conduit ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ValidateConduit — Difficulty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Only accepts values 1-5. Invalid values are '
                      'rejected.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Difficulty: ${p.difficulty.value}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => p.difficulty.value = 3,
                          child: const Text('Set 3 (valid)'),
                        ),
                        FilledButton(
                          onPressed: () {
                            try {
                              p.difficulty.value = 10;
                            } on ConduitRejectedException catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Rejected: ${e.message}'),
                                ),
                              );
                            }
                          },
                          child: const Text('Set 10 (rejected)'),
                        ),
                        FilledButton(
                          onPressed: () {
                            try {
                              p.difficulty.value = 0;
                            } on ConduitRejectedException catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Rejected: ${e.message}'),
                                ),
                              );
                            }
                          },
                          child: const Text('Set 0 (rejected)'),
                        ),
                      ],
                    ),
                  ],
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
// Prism Tab — Fine-Grained State Projections
// ---------------------------------------------------------------------------

class _PrismTab extends StatelessWidget {
  const _PrismTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        final counts = p.prismNotifyCount.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero Profile (source Core)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Source: Hero Profile (single Core)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'One Core holds the entire hero. Each Prism watches '
                      'a single field. Only the changed field triggers a '
                      'notification.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p.heroProfile.value.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Prism Projections
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prism Projections',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PrismRow(
                      label: 'Name',
                      value: p.prismName.value,
                      notifyCount: counts['name'] ?? 0,
                    ),
                    _PrismRow(
                      label: 'Level',
                      value: '${p.prismLevel.value}',
                      notifyCount: counts['level'] ?? 0,
                    ),
                    _PrismRow(
                      label: 'Health',
                      value: '${p.prismHealth.value}',
                      notifyCount: counts['health'] ?? 0,
                    ),
                    const Divider(),
                    _PrismRow(
                      label: 'Title (combine2)',
                      value: p.prismTitle.value,
                      notifyCount: counts['title'] ?? 0,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Fields',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Watch the notify counts above — only the '
                      'relevant Prism fires.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => p.updateHeroField('name', 'Aria'),
                          child: const Text('Name → Aria'),
                        ),
                        FilledButton(
                          onPressed: () => p.updateHeroField('name', 'Kael'),
                          child: const Text('Name → Kael'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => p.updateHeroField(
                            'level',
                            (p.prismLevel.value) + 1,
                          ),
                          child: const Text('Level +1'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => p.updateHeroField(
                            'health',
                            (p.prismHealth.value) - 10,
                          ),
                          child: const Text('Health -10'),
                        ),
                        OutlinedButton(
                          onPressed: () => p.updateHeroField(
                            'mana',
                            (p.heroProfile.value['mana'] as int) + 5,
                          ),
                          child: const Text('Mana +5 (no Prism)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrismRow extends StatelessWidget {
  final String label;
  final String value;
  final int notifyCount;

  const _PrismRow({
    required this.label,
    required this.value,
    required this.notifyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: notifyCount > 0
                  ? Colors.orange.shade100
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$notifyCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: notifyCount > 0 ? Colors.orange.shade800 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nexus Tab — Reactive Collections (NexusList, NexusMap, NexusSet)
// ---------------------------------------------------------------------------

class _NexusTab extends StatelessWidget {
  const _NexusTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- NexusList: Inventory ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NexusList — Inventory (${p.inventoryCount.value} items)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(p.inventory.length, (i) {
                      return ListTile(
                        dense: true,
                        title: Text(p.inventory[i]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => p.removeInventoryItem(i),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => p.addInventoryItem('Mana Potion'),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Mana Potion'),
                        ),
                        FilledButton.icon(
                          onPressed: () => p.addInventoryItem('Fire Scroll'),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Fire Scroll'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => p.inventory.sort(),
                          icon: const Icon(Icons.sort, size: 16),
                          label: const Text('Sort'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => p.inventory.clear(),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- NexusMap: Ability Scores ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NexusMap — Ability Scores (total: ${p.totalAbilityScore.value})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...p.abilityScores.entries.map((e) {
                      return ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: () =>
                                  p.setAbilityScore(e.key, e.value - 1),
                            ),
                            Text(
                              '${e.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: () =>
                                  p.setAbilityScore(e.key, e.value + 1),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- NexusSet: Quest Tags ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NexusSet — Quest Tags (${p.tagCount.value} active)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tag in [
                          'active',
                          'main-story',
                          'side-quest',
                          'daily',
                          'legendary',
                          'pvp',
                        ])
                          FilterChip(
                            label: Text(tag),
                            selected: p.questTags.contains(tag),
                            onSelected: (_) => p.toggleQuestTag(tag),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Active: {${p.questTags.elements.join(', ')}}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
// Toolkit Tab — Core Extensions, Sigil, Annals, Tether
// ---------------------------------------------------------------------------

class _ToolkitTab extends StatelessWidget {
  const _ToolkitTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Core Extensions
              _SectionHeader('Core Extensions'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: pillar.counter.decrement,
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '${pillar.counter.value}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          IconButton(
                            onPressed: pillar.counter.increment,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Toggle
                      SwitchListTile(
                        title: const Text('Special Mode'),
                        value: pillar.isSpecialMode.value,
                        onChanged: (_) => pillar.isSpecialMode.toggle(),
                      ),
                      // Tags
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: pillar.tags.value
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                onDeleted: () =>
                                    pillar.tags.removeWhere((tag) => tag == t),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            pillar.tags.add('tag-${pillar.counter.value}'),
                        child: const Text('Add Tag'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sigil Feature Flags
              _SectionHeader('Sigil (Feature Flags)'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.flag),
                      title: const Text('experimental_publish'),
                      trailing: Text(
                        Sigil.isEnabled('experimental_publish') ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: Sigil.isEnabled('experimental_publish')
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('batch_enabled'),
                      trailing: Text(
                        Sigil.isEnabled('batch_enabled') ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: Sigil.isEnabled('batch_enabled')
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Banner (Reactive Feature Flags)
              _SectionHeader('Banner (Reactive Feature Flags)'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final name in pillar.flags.names)
                      ListTile(
                        leading: Icon(
                          pillar.flags[name].value
                              ? Icons.flag
                              : Icons.flag_outlined,
                          color: pillar.flags[name].value
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          pillar.flags.config(name)?.description ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Switch(
                          value: pillar.flags[name].value,
                          onChanged: (_) => pillar.toggleBannerFlag(name),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Enabled: ${pillar.flags.enabledCount.value}'
                        ' / ${pillar.flags.count}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sieve (Reactive Search/Filter/Sort)
              _SectionHeader('Sieve (Search/Filter/Sort)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search quests...',
                          isDense: true,
                        ),
                        onChanged: (v) => pillar.questSearch.query.value = v,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final d in [1, 2, 3, 4, 5])
                            ChoiceChip(
                              label: Text('$d+'),
                              selected:
                                  pillar.questSearch.hasFilter('difficulty') &&
                                  d > 1,
                              onSelected: (_) => pillar.filterByDifficulty(d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${pillar.questSearch.resultCount.value} '
                        'of ${pillar.questSearch.totalCount.value} quests'
                        '${pillar.questSearch.isFiltered.value ? " (filtered)" : ""}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      for (final q in pillar.questSearch.results.value)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${q['title']} — '
                            'Difficulty ${q['difficulty']} '
                            '(${q['region']})',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lattice (Reactive DAG Task Executor)
              _SectionHeader('Lattice (DAG Executor)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${pillar.startupGraph.status.value.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pillar.startupGraph.progress.value,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pillar.startupGraph.completedCount.value}'
                        ' / ${pillar.startupGraph.nodeCount} nodes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed:
                            pillar.startupGraph.status.value ==
                                LatticeStatus.idle
                            ? () => pillar.runStartupGraph()
                            : pillar.startupGraph.status.value !=
                                  LatticeStatus.running
                            ? () {
                                pillar.startupGraph.reset();
                              }
                            : null,
                        child: Text(
                          pillar.startupGraph.status.value == LatticeStatus.idle
                              ? 'Run Startup Graph'
                              : pillar.startupGraph.status.value ==
                                    LatticeStatus.running
                              ? 'Running...'
                              : 'Reset',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Embargo (Reactive Async Mutex/Semaphore)
              _SectionHeader('Embargo (Async Mutex)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${pillar.purchaseLock.status.value.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active: ${pillar.purchaseLock.activeCount.value} '
                        '| Queue: ${pillar.purchaseLock.queueLength.value} '
                        '| Total: ${pillar.purchaseLock.totalAcquires.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: pillar.purchaseLock.isLocked.value
                            ? null
                            : () async {
                                final msg = await pillar.guardedPurchase();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          pillar.purchaseLock.isLocked.value
                              ? 'Purchasing...'
                              : 'Buy Potion (Guarded)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Census (Sliding-Window Data Aggregation)
              _SectionHeader('Census (Data Aggregation)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Count: ${pillar.questTimes.count.value} '
                        '| Sum: ${pillar.questTimes.sum.value.toStringAsFixed(0)} ms',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avg: ${pillar.questTimes.average.value.toStringAsFixed(1)} ms '
                        '| Min: ${pillar.questTimes.min.value == double.infinity ? "—" : pillar.questTimes.min.value.toStringAsFixed(0)} '
                        '| Max: ${pillar.questTimes.max.value == double.negativeInfinity ? "—" : pillar.questTimes.max.value.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          final ms = 100 + (DateTime.now().millisecond % 400);
                          pillar.recordQuestTime(ms);
                        },
                        child: const Text('Record Quest Time'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Warden (Service Health Monitoring)
              _SectionHeader('Warden (Service Health)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall: ${pillar.serviceHealth.overallHealth.value.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Healthy: ${pillar.serviceHealth.healthyCount.value} '
                        '| Degraded: ${pillar.serviceHealth.degradedCount.value} '
                        '| Checks: ${pillar.serviceHealth.totalChecks.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      ...pillar.serviceHealth.serviceNames.map(
                        (name) => Text(
                          '$name: ${pillar.serviceHealth.status(name).value.name} '
                          '(${pillar.serviceHealth.latency(name).value}ms, '
                          '${pillar.serviceHealth.failures(name).value} failures)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => pillar.checkHealth(),
                        child: const Text('Check All Services'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Arbiter (Conflict Resolution)
              _SectionHeader('Arbiter (Conflict Resolution)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conflicts: ${pillar.questSync.conflictCount.value} '
                        '| Resolved: ${pillar.questSync.totalResolved.value}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Has conflicts: ${pillar.questSync.hasConflicts.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (pillar.questSync.lastResolution.value != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Last: "${pillar.questSync.lastResolution.value!.resolved}"',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.tonal(
                            onPressed: () => pillar.simulateConflict(),
                            child: const Text('Simulate Conflict'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: pillar.questSync.hasConflicts.value
                                ? () => pillar.resolveConflict()
                                : null,
                            child: const Text('Resolve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lode (Resource Pool)
              _SectionHeader('Lode (Resource Pool)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pool: ${pillar.dbPool.inUse.value}/${pillar.dbPool.maxSize} in use '
                        '| Available: ${pillar.dbPool.available.value}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Utilization: ${(pillar.dbPool.utilization.value * 100).toStringAsFixed(0)}% '
                        '| Waiters: ${pillar.dbPool.waiters.value} '
                        '| Status: ${pillar.dbPool.status.name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => pillar.warmupPool(),
                            child: const Text('Warmup'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => pillar.simulateQuery('SELECT 1'),
                            child: const Text('Query'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => pillar.drainPool(),
                            child: const Text('Drain'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tithe (Quota & Budget)
              _SectionHeader('Tithe (Quota & Budget)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consumed: ${pillar.apiQuota.consumed.value} / ${pillar.apiQuota.budget}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pillar.apiQuota.ratio.value.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade300,
                        color: pillar.apiQuota.exceeded.value
                            ? Colors.red
                            : pillar.apiQuota.ratio.value > 0.8
                            ? Colors.orange
                            : Colors.green,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Remaining: ${pillar.apiQuota.remaining.value} '
                        '| Exceeded: ${pillar.apiQuota.exceeded.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (pillar.apiQuota.breakdown.value.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'By key: ${pillar.apiQuota.breakdown.value.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                pillar.consumeApiCall(endpoint: '/quests'),
                            child: const Text('API Call'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => pillar.consumeBulk(10),
                            child: const Text('Bulk (10)'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => pillar.resetQuota(),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sluice (Data Pipeline)
              _SectionHeader('Sluice (Data Pipeline)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fed: ${pillar.questPipeline.fed.value} '
                        '| Completed: ${pillar.questPipeline.completed.value} '
                        '| Failed: ${pillar.questPipeline.failed.value}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'In-flight: ${pillar.questPipeline.inFlight.value} '
                        '| Status: ${pillar.questPipeline.status.value.name} '
                        '| Error rate: ${(pillar.questPipeline.errorRate.value * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                pillar.submitQuest('Defeat the Dragon'),
                            child: const Text('Submit Quest'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => pillar.submitQuest(''),
                            child: const Text('Invalid Quest'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => pillar.flushPipeline(),
                            child: const Text('Flush'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Clarion (Job Scheduler)
              _SectionHeader('Clarion (Job Scheduler)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${pillar.scheduler.status.value.name} '
                        '| Jobs: ${pillar.scheduler.jobCount.value} '
                        '| Active: ${pillar.scheduler.activeCount.value}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total runs: ${pillar.scheduler.totalRuns.value} '
                        '| Errors: ${pillar.scheduler.totalErrors.value} '
                        '| Success: ${(pillar.scheduler.successRate.value * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => pillar.startScheduler(),
                            child: const Text('Start Jobs'),
                          ),
                          FilledButton.tonal(
                            onPressed: pillar.scheduler.jobCount.value > 0
                                ? () => pillar.triggerJob('refresh-quests')
                                : null,
                            child: const Text('Trigger Refresh'),
                          ),
                          FilledButton.tonal(
                            onPressed: pillar.scheduler.jobCount.value > 0
                                ? () => pillar.triggerJob('flush-analytics')
                                : null,
                            child: const Text('Trigger Analytics'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tapestry (Event Store)
              _SectionHeader('Tapestry (Event Store)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Events: ${pillar.questEvents.eventCount.value} '
                        '| Weaves: ${pillar.questEvents.weaveCount.value} '
                        '| Seq: ${pillar.questEvents.lastSequence.value}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${pillar.questsCreated.state.value} '
                        '| Completed: ${pillar.questsCompleted.state.value}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilledButton.tonal(
                            onPressed: () =>
                                pillar.recordQuestCreated('Dragon Slayer'),
                            child: const Text('Quest Created'),
                          ),
                          FilledButton.tonal(
                            onPressed: () =>
                                pillar.recordQuestCompleted('Dragon Slayer'),
                            child: const Text('Quest Completed'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Annals Audit Trail
              _SectionHeader('Annals (Audit Trail)'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${Annals.length} entries recorded'),
                      const SizedBox(height: 8),
                      ...Annals.entries.reversed
                          .take(5)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${e.coreName}: ${e.oldValue} → ${e.newValue} '
                                '[${e.action ?? "—"}]',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tether
              _SectionHeader('Tether (Request-Response)'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () async {
                  final title = await pillar.getQuestTitle('quest-0');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tether response: ${title ?? "null"}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Call Tether: getQuestTitle'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Trove Tab — Reactive Cache
// ---------------------------------------------------------------------------

class _TroveTab extends StatelessWidget {
  const _TroveTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('Trove — Reactive Cache'),
              const SizedBox(height: 8),
              const Text(
                'Trove is a TTL + LRU in-memory cache with reactive '
                'statistics. All stats are live Cores that drive UI rebuilds.',
              ),
              const SizedBox(height: 16),

              // Cache stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Cache Stats'),
                      const SizedBox(height: 8),
                      Text('Status: ${p.cacheStatus.value}'),
                      Text('Entries: ${p.questCache.size.value}'),
                      Text('Hits: ${p.questCache.hits.value}'),
                      Text('Misses: ${p.questCache.misses.value}'),
                      Text('Evictions: ${p.questCache.evictions.value}'),
                      Text(
                        'Hit rate: '
                        '${p.questCache.hitRate.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final quest = await p.fetchCached('quest-1');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fetched: ${quest.title}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Fetch quest-1 (cached)'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final quest = await p.fetchCached('quest-2');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fetched: ${quest.title}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Fetch quest-2 (cached)'),
                  ),
                  OutlinedButton(
                    onPressed: () => p.evictQuest('quest-1'),
                    child: const Text('Evict quest-1'),
                  ),
                  OutlinedButton(
                    onPressed: p.clearCache,
                    child: const Text('Clear Cache'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Moat Tab — Rate Limiter
// ---------------------------------------------------------------------------

class _MoatTab extends StatelessWidget {
  const _MoatTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
        final remaining = p.apiLimiter.remainingTokens.value;
        final max = p.apiLimiter.maxTokens;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('Moat — Rate Limiter'),
              const SizedBox(height: 8),
              const Text(
                'Moat is a token-bucket rate limiter. Tokens are consumed '
                'per request and refilled at a steady rate. All state is '
                'reactive.',
              ),
              const SizedBox(height: 16),

              // Token status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Token Status'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: max > 0 ? remaining / max : 0,
                      ),
                      const SizedBox(height: 8),
                      Text('Quota: ${p.quotaStatus.value}'),
                      Text('Consumed: ${p.apiLimiter.consumed.value}'),
                      Text(
                        'Fill: '
                        '${p.apiLimiter.fillPercentage.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final quest = await p.fetchRateLimited('quest-1');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              quest != null
                                  ? 'Fetched: ${quest.title}'
                                  : 'Rate limited!',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Fetch (rate limited)'),
                  ),
                  OutlinedButton(
                    onPressed: p.exhaustLimiter,
                    child: const Text('Exhaust Tokens'),
                  ),
                  OutlinedButton(
                    onPressed: () => p.apiLimiter.reset(),
                    child: const Text('Reset Limiter'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _PyreTab extends StatelessWidget {
  const _PyreTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Pyre — Priority Task Queue'),
            const SizedBox(height: 8),
            const Text(
              'Pyre processes async tasks in priority order with '
              'configurable concurrency, backpressure, and retry.',
            ),
            const SizedBox(height: 16),

            // Status & progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(pillar.taskQueue.status.name),
                        const Spacer(),
                        Text(pillar.pyreProgressText.value),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: pillar.taskQueue.progress),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PyreStatChip('Queue', pillar.taskQueue.queueLength),
                        _PyreStatChip('Running', pillar.taskQueue.runningCount),
                        _PyreStatChip('Done', pillar.taskQueue.completedCount),
                        _PyreStatChip('Failed', pillar.taskQueue.failedCount),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Enqueue controls
            const _SectionHeader('Enqueue Tasks'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: pillar.enqueueSampleTasks,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Add 5 Sample Tasks'),
                ),
                OutlinedButton.icon(
                  onPressed: () => pillar.enqueueQuestTask(
                    'Urgent Dispatch',
                    priority: PyrePriority.critical,
                  ),
                  icon: const Icon(Icons.priority_high),
                  label: const Text('Critical Task'),
                ),
                OutlinedButton.icon(
                  onPressed: () => pillar.enqueueQuestTask('Routine Patrol'),
                  icon: const Icon(Icons.task),
                  label: const Text('Normal Task'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Queue controls
            const _SectionHeader('Queue Controls'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: pillar.taskQueue.pause,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                ElevatedButton.icon(
                  onPressed: pillar.taskQueue.resume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
                OutlinedButton.icon(
                  onPressed: pillar.taskQueue.cancelAll,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel All'),
                ),
                OutlinedButton.icon(
                  onPressed: () => pillar.taskQueue.drain(),
                  icon: const Icon(Icons.water_drop),
                  label: const Text('Drain'),
                ),
                OutlinedButton.icon(
                  onPressed: pillar.taskQueue.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PyreStatChip extends StatelessWidget {
  final String label;
  final int value;

  const _PyreStatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _OmenTab extends StatelessWidget {
  const _OmenTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Omen — Reactive Async Derived'),
            const SizedBox(height: 8),
            const Text(
              'Omen auto-tracks Core reads inside an async function '
              'and re-executes when dependencies change.',
            ),
            const SizedBox(height: 16),

            // Search input
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search quests',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: pillar.updateOmenQuery,
            ),
            const SizedBox(height: 8),

            // Sort toggle
            Row(
              children: [
                const Text('Sort: '),
                ActionChip(
                  label: Text(pillar.omenSort.value),
                  onPressed: pillar.toggleOmenSort,
                ),
                const Spacer(),
                Text(pillar.omenExecStatus.value),
              ],
            ),
            const SizedBox(height: 8),

            // Omen results
            Builder(
              builder: (context) {
                return switch (pillar.omenResults.value) {
                  AsyncData(:final data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in data)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.task_alt),
                          title: Text(item),
                        ),
                      if (data.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No quests match your search'),
                          ),
                        ),
                    ],
                  ),
                  AsyncRefreshing(:final data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LinearProgressIndicator(),
                      for (final item in data)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.task_alt),
                          title: Text(
                            item,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  AsyncLoading() => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  AsyncError(:final error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: $error'),
                    ),
                  ),
                };
              },
            ),
            const SizedBox(height: 16),

            // Controls
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: pillar.omenResults.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                OutlinedButton.icon(
                  onPressed: pillar.omenResults.cancel,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: pillar.omenResults.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Mandate Tab — Reactive Policy Engine
// ---------------------------------------------------------------------------

class _MandateTab extends StatelessWidget {
  const _MandateTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('Edit Access (allOf)'),
              const SizedBox(height: 8),

              // Verdict card
              Card(
                color: pillar.editAccess.isGranted.value
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            pillar.editAccess.isGranted.value
                                ? Icons.check_circle
                                : Icons.block,
                            color: pillar.editAccess.isGranted.value
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pillar.editVerdictText.value,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Individual writ status
                      ...pillar.editAccess.writNames.map((name) {
                        final passes = pillar.editAccess.can(name).value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                passes ? Icons.check : Icons.close,
                                size: 16,
                                color: passes ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(name),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Controls
              const _SectionHeader('Controls'),
              const SizedBox(height: 8),

              // Role selector
              Row(
                children: [
                  const Text('Role: '),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'viewer', label: Text('Viewer')),
                      ButtonSegment(value: 'editor', label: Text('Editor')),
                      ButtonSegment(value: 'admin', label: Text('Admin')),
                    ],
                    selected: {pillar.userRole.value},
                    onSelectionChanged: (s) => pillar.setUserRole(s.first),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Toggle switches
              SwitchListTile(
                title: const Text('Email Verified'),
                value: pillar.isVerified.value,
                onChanged: (_) => pillar.toggleVerification(),
              ),
              SwitchListTile(
                title: const Text('Editing Enabled'),
                value: pillar.editingEnabled.value,
                onChanged: (_) => pillar.toggleEditing(),
              ),
              const SizedBox(height: 16),

              // View access (anyOf)
              const _SectionHeader('View Access (anyOf)'),
              const SizedBox(height: 8),
              Card(
                color: pillar.viewAccess.isGranted.value
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: ListTile(
                  leading: Icon(
                    pillar.viewAccess.isGranted.value
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: pillar.viewAccess.isGranted.value
                        ? Colors.green
                        : Colors.red,
                  ),
                  title: Text(
                    pillar.viewAccess.isGranted.value
                        ? 'View: GRANTED'
                        : 'View: DENIED',
                  ),
                  subtitle: Text(
                    'Strategy: anyOf — ${pillar.viewAccess.writCount} writs',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Inspection
              const _SectionHeader('Inspection'),
              const SizedBox(height: 8),
              Text('Writ names: ${pillar.editAccess.writNames.join(", ")}'),
              Text('Writ count: ${pillar.editAccess.writCount}'),
              Text('Strategy: ${pillar.editAccess.strategy.name}'),
              Text(
                'Has "is-verified": ${pillar.editAccess.hasWrit("is-verified")}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ---------------------------------------------------------------------------
// Ledger Tab — State Transactions
// ---------------------------------------------------------------------------

class _LedgerTab extends StatelessWidget {
  const _LedgerTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('State Balances'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${pillar.goldBalance.value}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Text('Gold'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inventory,
                              color: Colors.blue,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${pillar.itemCount.value}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Text('Items'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Transaction actions
              const _SectionHeader('Transactions'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => pillar.purchaseItems(5, 20),
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Buy 5 items (100g)'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => pillar.purchaseItems(10, 50),
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Buy 10 items (500g)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: pillar.failedPurchase,
                    icon: const Icon(Icons.error_outline),
                    label: const Text('Failed Purchase'),
                  ),
                  TextButton.icon(
                    onPressed: pillar.resetLedgerDemo,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Result message
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(pillar.txResultMessage.value)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reactive counters
              const _SectionHeader('Reactive Counters'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CounterChip(
                    label: 'Commits',
                    value: pillar.txManager.commitCount,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Rollbacks',
                    value: pillar.txManager.rollbackCount,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Failed',
                    value: pillar.txManager.failCount,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Active',
                    value: pillar.txManager.activeCount,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total started: ${pillar.txManager.totalStarted}  •  '
                'Has active: ${pillar.txManager.hasActive}',
              ),
              const SizedBox(height: 16),

              // History
              const _SectionHeader('Transaction History'),
              const SizedBox(height: 8),
              if (pillar.txManager.history.isEmpty)
                const Text('No transactions yet')
              else
                ...pillar.txManager.history.reversed.map(
                  (r) => Card(
                    child: ListTile(
                      leading: Icon(
                        r.status == LedgerStatus.committed
                            ? Icons.check_circle
                            : r.status == LedgerStatus.failed
                            ? Icons.error
                            : Icons.undo,
                        color: r.status == LedgerStatus.committed
                            ? Colors.green
                            : r.status == LedgerStatus.failed
                            ? Colors.red
                            : Colors.orange,
                      ),
                      title: Text(
                        '#${r.id} ${r.name ?? "unnamed"} — ${r.status.name}',
                      ),
                      subtitle: Text('Cores: ${r.coreCount}'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CounterChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _CounterChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text(label),
    );
  }
}

// ---------------------------------------------------------------------------
// Portcullis Detail Tab — Circuit Breaker (extended demo)
// ---------------------------------------------------------------------------

class _PortcullisDetailTab extends StatelessWidget {
  const _PortcullisDetailTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        final stateColor = switch (pillar.circuitBreaker.state) {
          PortcullisState.closed => Colors.green,
          PortcullisState.open => Colors.red,
          PortcullisState.halfOpen => Colors.orange,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('Circuit State'),
              const SizedBox(height: 8),

              // State indicator
              Card(
                color: stateColor.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        switch (pillar.circuitBreaker.state) {
                          PortcullisState.closed => Icons.check_circle,
                          PortcullisState.open => Icons.block,
                          PortcullisState.halfOpen => Icons.warning,
                        },
                        color: stateColor,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pillar.circuitBreaker.state.name.toUpperCase(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: stateColor,
                                ),
                          ),
                          Text(
                            'Threshold: ${pillar.circuitBreaker.failureThreshold} '
                            '• Reset: ${pillar.circuitBreaker.resetTimeout.inSeconds}s',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              const _SectionHeader('Simulate'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: pillar.simulateSuccess,
                    icon: const Icon(Icons.check),
                    label: const Text('Success Call'),
                  ),
                  ElevatedButton.icon(
                    onPressed: pillar.simulateFailure,
                    icon: const Icon(Icons.error_outline),
                    label: const Text('Failure Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: pillar.tripBreaker,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Manual Trip'),
                  ),
                  OutlinedButton.icon(
                    onPressed: pillar.resetBreaker,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Manual Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Result
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(pillar.callResult.value)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Counters
              const _SectionHeader('Counters'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CounterChip(
                    label: 'Failures',
                    value: pillar.circuitBreaker.failureCount,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Successes',
                    value: pillar.circuitBreaker.successCount,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Trips',
                    value: pillar.circuitBreaker.tripCount,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Healthy: ${pillar.circuitBreaker.isClosed}'),
              const SizedBox(height: 16),

              // Trip history
              const _SectionHeader('Trip History'),
              const SizedBox(height: 8),
              if (pillar.circuitBreaker.tripHistory.isEmpty)
                const Text('No trips recorded')
              else
                ...pillar.circuitBreaker.tripHistory.reversed.map(
                  (r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.flash_on, color: Colors.orange),
                      title: Text(
                        'Trip at ${r.timestamp.hour}:${r.timestamp.minute.toString().padLeft(2, '0')}:${r.timestamp.second.toString().padLeft(2, '0')}',
                      ),
                      subtitle: Text(
                        'After ${r.failureCount} failures'
                        '${r.lastError != null ? ' • ${r.lastError}' : ''}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnvilTab extends StatelessWidget {
  const _AnvilTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, pillar) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader('Anvil — Dead Letter & Retry Queue'),
              const SizedBox(height: 8),
              const Text(
                'Anvil queues failed operations and retries them with '
                'configurable backoff. Exhausted entries become dead letters.',
              ),
              const SizedBox(height: 16),

              // Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: pillar.enqueueSuccess,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Enqueue Success'),
                  ),
                  ElevatedButton.icon(
                    onPressed: pillar.enqueueFailure,
                    icon: const Icon(Icons.error_outline),
                    label: const Text('Enqueue Failure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: pillar.retryDead,
                    icon: const Icon(Icons.replay),
                    label: const Text('Retry Dead'),
                  ),
                  OutlinedButton.icon(
                    onPressed: pillar.purgeDead,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Purge Dead'),
                  ),
                  OutlinedButton.icon(
                    onPressed: pillar.clearQueue,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Result
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(pillar.anvilResult.value)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Counters
              const _SectionHeader('Queue Counters'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CounterChip(
                    label: 'Pending',
                    value: pillar.retryQueue.pendingCount,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Succeeded',
                    value: pillar.retryQueue.succeededCount,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _CounterChip(
                    label: 'Dead Letters',
                    value: pillar.retryQueue.deadLetterCount,
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total Enqueued: ${pillar.retryQueue.totalEnqueued}'),
              Text('Processing: ${pillar.retryQueue.isProcessing}'),
              const SizedBox(height: 16),

              // Dead letter list
              const _SectionHeader('Dead Letter Entries'),
              const SizedBox(height: 8),
              if (pillar.retryQueue.deadLetters.isEmpty)
                const Text('No dead letters')
              else
                ...pillar.retryQueue.deadLetters.reversed.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: Colors.red,
                      ),
                      title: Text(entry.id ?? 'unnamed'),
                      subtitle: Text(
                        'Attempts: ${entry.attempts}/${entry.maxRetries}'
                        '${entry.lastError != null ? '\n${entry.lastError}' : ''}',
                      ),
                      isThreeLine: entry.lastError != null,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
