import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../models/hero.dart';
import '../pillars/hero_registration_pillar.dart';

/// Hero Registration Screen — form validation with Scroll.
///
/// Demonstrates: Scroll (form fields with validation), ScrollGroup,
/// Vestige (auto-tracking dirty/error state), Herald (emitting events).
class HeroRegistrationScreen extends StatelessWidget {
  const HeroRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Hero'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.atlas.back(),
        ),
      ),
      body: Beacon(
        pillars: [HeroRegistrationPillar.new],
        child: const _RegistrationForm(),
      ),
    );
  }
}

class _RegistrationForm extends StatelessWidget {
  const _RegistrationForm();

  @override
  Widget build(BuildContext context) {
    return Vestige<HeroRegistrationPillar>(
      builder: (context, reg) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Join the Questboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Register as a hero to claim quests and earn glory.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),

              // Name field
              _ScrollTextField(
                label: 'Hero Name',
                value: reg.name.value,
                error: reg.name.error,
                isTouched: reg.name.isTouched,
                onChanged: (v) {
                  reg.name.value = v;
                  reg.name.validate();
                },
                onBlur: () => reg.name.touch(),
              ),
              const SizedBox(height: 16),

              // Email field
              _ScrollTextField(
                label: 'Email',
                value: reg.email.value,
                error: reg.email.error,
                isTouched: reg.email.isTouched,
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) {
                  reg.email.value = v;
                  reg.email.validate();
                },
                onBlur: () => reg.email.touch(),
              ),
              const SizedBox(height: 16),

              // Hero class selector
              Text('Hero Class', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<HeroClass>(
                segments: HeroClass.values
                    .map((c) => ButtonSegment(value: c, label: Text(c.label)))
                    .toList(),
                selected: {reg.heroClass.value},
                onSelectionChanged: (s) => reg.heroClass.value = s.first,
              ),
              const SizedBox(height: 16),

              // Bio field
              _ScrollTextField(
                label: 'Bio (optional)',
                value: reg.bio.value,
                error: reg.bio.error,
                isTouched: reg.bio.isTouched,
                maxLines: 3,
                onChanged: (v) {
                  reg.bio.value = v;
                  reg.bio.validate();
                },
                onBlur: () => reg.bio.touch(),
              ),
              const SizedBox(height: 8),
              Text(
                '${reg.bio.value.length}/200',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
              const SizedBox(height: 24),

              // Form status
              if (reg.form.isDirty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(
                        reg.form.isValid
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        size: 16,
                        color: reg.form.isValid ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        reg.form.isValid
                            ? 'All fields valid'
                            : '${reg.form.invalidFields.length} field(s) need attention',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

              // Submit / Reset buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: reg.form.isDirty ? reg.resetForm : null,
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        if (reg.submit()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Welcome, ${reg.name.value}! Your quest begins.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          context.atlas.back();
                        }
                      },
                      child: const Text('Register'),
                    ),
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
// Reusable Scroll-backed TextField
// ---------------------------------------------------------------------------

class _ScrollTextField extends StatefulWidget {
  final String label;
  final String value;
  final String? error;
  final bool isTouched;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final VoidCallback onBlur;

  const _ScrollTextField({
    required this.label,
    required this.value,
    required this.error,
    required this.isTouched,
    this.keyboardType,
    this.maxLines = 1,
    required this.onChanged,
    required this.onBlur,
  });

  @override
  State<_ScrollTextField> createState() => _ScrollTextFieldState();
}

class _ScrollTextFieldState extends State<_ScrollTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_ScrollTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        errorText: widget.isTouched ? widget.error : null,
      ),
      onChanged: widget.onChanged,
      onTapOutside: (_) => widget.onBlur(),
    );
  }
}
