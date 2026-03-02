import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../pillars/enterprise_demo_pillar.dart';

/// Enterprise Demo Screen — showcases enterprise features.
///
/// Demonstrates: Loom, Bulwark, Saga, Volley, Sigil, Aegis, Annals,
/// Tether, Core extensions, onInitAsync, VestigeWhen, VestigeSelector.
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
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Loom'),
              Tab(text: 'Bulwark'),
              Tab(text: 'Saga'),
              Tab(text: 'Volley'),
              Tab(text: 'Toolkit'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _LoomTab(),
                _BulwarkTab(),
                _SagaTab(),
                _VolleyTab(),
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
// Bulwark Tab — Circuit Breaker
// ---------------------------------------------------------------------------

class _BulwarkTab extends StatelessWidget {
  const _BulwarkTab();

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
                    breakerState == BulwarkState.closed
                        ? Icons.check_circle
                        : breakerState == BulwarkState.halfOpen
                        ? Icons.warning
                        : Icons.block,
                    color: breakerState == BulwarkState.closed
                        ? Colors.green
                        : breakerState == BulwarkState.halfOpen
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
                          '${batch.completedCount - batch.successCount} failed',
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
// Toolkit Tab — Core Extensions, Sigil, Annals, Tether
// ---------------------------------------------------------------------------

class _ToolkitTab extends StatelessWidget {
  const _ToolkitTab();

  @override
  Widget build(BuildContext context) {
    return Vestige<EnterpriseDemoPillar>(
      builder: (context, p) {
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
                            onPressed: p.counter.decrement,
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '${p.counter.value}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          IconButton(
                            onPressed: p.counter.increment,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Toggle
                      SwitchListTile(
                        title: const Text('Special Mode'),
                        value: p.isSpecialMode.value,
                        onChanged: (_) => p.isSpecialMode.toggle(),
                      ),
                      // Tags
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: p.tags.value
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                onDeleted: () =>
                                    p.tags.removeWhere((tag) => tag == t),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => p.tags.add('tag-${p.counter.value}'),
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
                  final title = await p.getQuestTitle('quest-0');
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
// Shared Widgets
// ---------------------------------------------------------------------------

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
