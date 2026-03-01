import 'package:titan_bastion/titan_bastion.dart';

/// Counter Pillar — structured state with fine-grained reactivity.
///
/// Each [Core] tracks independently. A [Vestige] reading only [count]
/// won't rebuild when [label] changes, and vice versa.
class CounterPillar extends Pillar {
  late final count = core(0, name: 'count');
  late final label = core('Counter', name: 'label');

  late final doubled = derived(() => count.value * 2, name: 'doubled');
  late final isEven = derived(() => count.value % 2 == 0, name: 'isEven');

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void reset() => strike(() => count.value = 0);

  void rename(String name) => label.value = name;
}
