import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'package:titan_example/pillars/counter_pillar.dart';

void main() {
  test('CounterPillar works with Pillar API', () {
    final counter = CounterPillar();

    expect(counter.count.value, 0);
    expect(counter.doubled.value, 0);
    expect(counter.isEven.value, true);

    counter.increment();
    expect(counter.count.value, 1);
    expect(counter.doubled.value, 2);
    expect(counter.isEven.value, false);

    counter.decrement();
    expect(counter.count.value, 0);

    counter.reset();
    expect(counter.count.value, 0);

    counter.dispose();
  });

  tearDown(() => Titan.reset());
}
