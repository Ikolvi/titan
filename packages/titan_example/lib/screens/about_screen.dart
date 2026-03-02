import 'package:flutter/material.dart';

/// About Screen — simple information page.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Questboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.shield, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Questboard',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Built with Titan',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 32),
              const _FeatureRow(
                icon: Icons.layers,
                text: 'Pillar — Reactive state modules',
              ),
              const _FeatureRow(
                icon: Icons.auto_awesome,
                text: 'Core & Derived — Fine-grained signals',
              ),
              const _FeatureRow(
                icon: Icons.visibility,
                text: 'Vestige — Surgical UI rebuilds',
              ),
              const _FeatureRow(
                icon: Icons.cell_tower,
                text: 'Beacon — Scoped state provision',
              ),
              const _FeatureRow(
                icon: Icons.map,
                text: 'Atlas — Declarative navigation',
              ),
              const _FeatureRow(
                icon: Icons.message,
                text: 'Herald — Event bus',
              ),
              const _FeatureRow(
                icon: Icons.security,
                text: 'Vigil — Error tracking',
              ),
              const _FeatureRow(icon: Icons.history, text: 'Epoch — Undo/redo'),
              const _FeatureRow(
                icon: Icons.edit_note,
                text: 'Scroll — Form validation',
              ),
              const _FeatureRow(icon: Icons.book, text: 'Codex — Pagination'),
              const _FeatureRow(
                icon: Icons.cloud_download,
                text: 'Quarry — Data fetching (SWR)',
              ),
              const _FeatureRow(
                icon: Icons.merge_type,
                text: 'Confluence — Multi-Pillar widgets',
              ),
              const _FeatureRow(
                icon: Icons.bug_report,
                text: 'Lens — Debug overlay',
              ),
              const _FeatureRow(
                icon: Icons.account_tree,
                text: 'Loom — Finite state machine',
              ),
              const _FeatureRow(
                icon: Icons.shield_outlined,
                text: 'Bulwark — Circuit breaker',
              ),
              const _FeatureRow(
                icon: Icons.route,
                text: 'Saga — Multi-step workflows',
              ),
              const _FeatureRow(
                icon: Icons.bolt,
                text: 'Volley — Batch async operations',
              ),
              const _FeatureRow(
                icon: Icons.flag,
                text: 'Sigil — Feature flags',
              ),
              const _FeatureRow(
                icon: Icons.replay,
                text: 'Aegis — Retry with backoff',
              ),
              const _FeatureRow(
                icon: Icons.receipt_long,
                text: 'Annals — Audit trail',
              ),
              const _FeatureRow(
                icon: Icons.cable,
                text: 'Tether — Request-response channels',
              ),
              const _FeatureRow(
                icon: Icons.build,
                text: 'Core Extensions — toggle, increment, add',
              ),
              const _FeatureRow(
                icon: Icons.speed,
                text: 'Colossus — Performance monitoring',
              ),
              const _FeatureRow(
                icon: Icons.fiber_smart_record,
                text: 'Shade — Gesture recording & macros',
              ),
              const _FeatureRow(
                icon: Icons.replay_circle_filled,
                text: 'Phantom — Automated gesture replay',
              ),
              const _FeatureRow(
                icon: Icons.refresh,
                text: 'CoreRefresh — Reactive auth routing',
              ),
              const SizedBox(height: 32),
              Text(
                'Built by Ikolvi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
