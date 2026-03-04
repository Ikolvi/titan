import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Lode', () {
    // ─── Construction ─────────────────────────────────────────

    test('initial state is empty', () {
      final pool = Lode<int>(create: () async => 42);
      expect(pool.available.value, 0);
      expect(pool.inUse.value, 0);
      expect(pool.size.value, 0);
      expect(pool.waiters.value, 0);
      expect(pool.utilization.value, 0.0);
      expect(pool.maxSize, 10);
      expect(pool.status, LodeStatus.idle);
    });

    // ─── Acquire / Release ────────────────────────────────────

    test('acquire creates and checks out a resource', () async {
      var created = 0;
      final pool = Lode<int>(create: () async => ++created, maxSize: 3);

      final lease = await pool.acquire();
      expect(lease.resource, 1);
      expect(pool.inUse.value, 1);
      expect(pool.available.value, 0);
      expect(pool.size.value, 1);
      expect(pool.status, LodeStatus.active);

      lease.release();
      expect(pool.inUse.value, 0);
      expect(pool.available.value, 1);
      expect(pool.size.value, 1);
      expect(pool.status, LodeStatus.active); // Still has idle resource
    });

    test('release returns resource to idle pool', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 5);

      final lease1 = await pool.acquire();
      final lease2 = await pool.acquire();
      expect(pool.inUse.value, 2);
      expect(pool.available.value, 0);

      lease1.release();
      expect(pool.inUse.value, 1);
      expect(pool.available.value, 1);

      lease2.release();
      expect(pool.inUse.value, 0);
      expect(pool.available.value, 2);
    });

    test('reuses idle resources instead of creating new', () async {
      var created = 0;
      final pool = Lode<int>(create: () async => ++created, maxSize: 5);

      final lease1 = await pool.acquire();
      lease1.release();

      final lease2 = await pool.acquire();
      expect(lease2.resource, 1); // Same resource reused
      expect(created, 1); // Only created once
      lease2.release();
    });

    // ─── withResource ─────────────────────────────────────────

    test('withResource auto-releases after action', () async {
      final pool = Lode<int>(create: () async => 42, maxSize: 2);

      final result = await pool.withResource((r) async => r * 2);
      expect(result, 84);
      expect(pool.inUse.value, 0);
      expect(pool.available.value, 1);
    });

    test('withResource releases even on error', () async {
      final pool = Lode<int>(create: () async => 42, maxSize: 2);

      try {
        await pool.withResource((_) async => throw Exception('fail'));
      } catch (_) {}

      expect(pool.inUse.value, 0);
      expect(pool.available.value, 1);
    });

    // ─── Validation ───────────────────────────────────────────

    test('validates resources before checkout', () async {
      var created = 0;
      var valid = true;
      final pool = Lode<int>(
        create: () async => ++created,
        validate: (_) async => valid,
        maxSize: 5,
      );

      // Create and release a resource
      final lease1 = await pool.acquire();
      lease1.release();
      expect(created, 1);

      // Invalidate it
      valid = false;
      final lease2 = await pool.acquire();
      // Old resource was invalid and destroyed; new one created
      expect(created, 2);
      expect(lease2.resource, 2);
      lease2.release();
    });

    // ─── Invalidate ───────────────────────────────────────────

    test('LodeLease.invalidate destroys resource', () async {
      var destroyed = <int>[];
      var n = 0;
      final pool = Lode<int>(
        create: () async => ++n,
        destroy: (r) async => destroyed.add(r),
        maxSize: 5,
      );

      final lease = await pool.acquire();
      await lease.invalidate();
      expect(destroyed, [1]);
      expect(pool.inUse.value, 0);
      expect(pool.available.value, 0);
      expect(pool.size.value, 0);
    });

    // ─── Pool Exhaustion & Waiting ────────────────────────────

    test('waiters queue when pool is exhausted', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 1);

      final lease1 = await pool.acquire();
      expect(pool.status, LodeStatus.exhausted);

      // Try to acquire — will wait
      late LodeLease<int> lease2;
      unawaited(pool.acquire().then((l) => lease2 = l));

      // Allow microtask to schedule
      await Future<void>.delayed(Duration.zero);
      expect(pool.waiters.value, 1);

      // Release first lease — waiter gets the resource
      lease1.release();
      await Future<void>.delayed(Duration.zero);
      expect(pool.waiters.value, 0);
      expect(lease2.resource, 1); // Same resource handed off
      lease2.release();
    });

    test('acquire with timeout throws TimeoutException', () async {
      final pool = Lode<int>(create: () async => 42, maxSize: 1);

      final lease = await pool.acquire();

      await expectLater(
        pool.acquire(timeout: Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );

      expect(pool.waiters.value, 0); // Waiter removed on timeout
      lease.release();
    });

    // ─── Warmup ───────────────────────────────────────────────

    test('warmup pre-creates resources', () async {
      var created = 0;
      final pool = Lode<int>(create: () async => ++created, maxSize: 5);

      await pool.warmup(3);
      expect(created, 3);
      expect(pool.available.value, 3);
      expect(pool.inUse.value, 0);
      expect(pool.size.value, 3);
    });

    test('warmup respects maxSize', () async {
      var created = 0;
      final pool = Lode<int>(create: () async => ++created, maxSize: 2);

      await pool.warmup(10);
      expect(created, 2);
      expect(pool.available.value, 2);
    });

    // ─── Drain ────────────────────────────────────────────────

    test('drain destroys idle resources', () async {
      var destroyed = <int>[];
      var n = 0;
      final pool = Lode<int>(
        create: () async => ++n,
        destroy: (r) async => destroyed.add(r),
        maxSize: 5,
      );

      await pool.warmup(3);
      expect(pool.available.value, 3);

      await pool.drain();
      expect(pool.available.value, 0);
      expect(pool.size.value, 0);
      expect(destroyed, [1, 2, 3]);
    });

    test('drain does not affect checked-out resources', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 5);

      await pool.warmup(2);
      final lease = await pool.acquire(); // Checks out resource 1

      await pool.drain();
      expect(pool.inUse.value, 1); // Checked-out resource remains
      expect(pool.available.value, 0); // Idle resource destroyed

      lease.release();
    });

    // ─── Utilization ──────────────────────────────────────────

    test('utilization is inUse / maxSize', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 4);

      final l1 = await pool.acquire();
      expect(pool.utilization.value, 0.25);

      final l2 = await pool.acquire();
      expect(pool.utilization.value, 0.5);

      l1.release();
      expect(pool.utilization.value, 0.25);

      l2.release();
      expect(pool.utilization.value, 0.0);
    });

    // ─── Dispose ──────────────────────────────────────────────

    test('dispose destroys all resources', () async {
      var destroyed = <int>[];
      var n = 0;
      final pool = Lode<int>(
        create: () async => ++n,
        destroy: (r) async => destroyed.add(r),
        maxSize: 5,
      );

      await pool.warmup(2); // Creates 1, 2 in idle
      final lease = await pool.acquire(); // Pops 1 from idle
      expect(lease.resource, 1);

      await pool.dispose();
      // Idle [2] destroyed first, then checked-out {1}
      expect(destroyed, containsAll([1, 2]));
      expect(destroyed, hasLength(2));
      expect(pool.status, LodeStatus.draining);
    });

    test('dispose cancels waiters with StateError', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 1);

      final lease = await pool.acquire();

      final future = pool.acquire();

      await Future<void>.delayed(Duration.zero);
      expect(pool.waiters.value, 1);

      // Capture expectation BEFORE dispose triggers the error
      final expectFuture = expectLater(future, throwsA(isA<StateError>()));

      await pool.dispose();
      lease.release();

      await expectFuture;
    });

    test('double dispose is safe', () async {
      final pool = Lode<int>(create: () async => 42);
      await pool.dispose();
      await pool.dispose(); // No throw
    });

    // ─── Double release is safe ───────────────────────────────

    test('double release is safe', () async {
      final pool = Lode<int>(create: () async => 42, maxSize: 2);
      final lease = await pool.acquire();
      lease.release();
      lease.release(); // No throw, no double-return
      expect(pool.available.value, 1);
    });

    // ─── Managed Nodes ────────────────────────────────────────

    test('managedNodes exposes all reactive nodes', () {
      final pool = Lode<int>(create: () async => 42);
      expect(pool.managedNodes, hasLength(5));
    });

    // ─── Status transitions ──────────────────────────────────

    test('status transitions through lifecycle', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 2);

      expect(pool.status, LodeStatus.idle);

      final l1 = await pool.acquire();
      expect(pool.status, LodeStatus.active);

      final l2 = await pool.acquire();
      expect(pool.status, LodeStatus.exhausted);

      l1.release();
      expect(pool.status, LodeStatus.active);

      l2.release();
      expect(pool.status, LodeStatus.active); // idle resources exist

      await pool.drain();
      expect(pool.status, LodeStatus.idle);

      await pool.dispose();
      expect(pool.status, LodeStatus.draining);
    });

    // ─── Multiple waiters ─────────────────────────────────────

    test('multiple waiters are served in FIFO order', () async {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 1);

      final lease = await pool.acquire(); // resource 1

      final results = <int>[];
      final f1 = pool.acquire().then((l) {
        results.add(l.resource);
        l.release();
      });
      final f2 = pool.acquire().then((l) {
        results.add(l.resource);
        l.release();
      });

      await Future<void>.delayed(Duration.zero);
      expect(pool.waiters.value, 2);

      lease.release(); // Hands resource 1 to first waiter

      await Future.wait([f1, f2]);
      expect(results, [1, 1]); // Same resource reused FIFO
    });

    // ─── Validation failure creates new resource ──────────────

    test('validation failure on all idle creates new resource', () async {
      var n = 0;
      final pool = Lode<int>(
        create: () async => ++n,
        validate: (r) async => r > 2, // Only > 2 passes
        maxSize: 5,
      );

      await pool.warmup(2); // Creates 1, 2 — both will fail validation
      expect(pool.available.value, 2);

      final lease = await pool.acquire();
      expect(lease.resource, 3); // 1 and 2 failed, 3 created
      expect(pool.available.value, 0); // 1 and 2 destroyed
      lease.release();
    });

    // ─── acquire after dispose throws assert ──────────────────

    test('acquire after dispose throws assertion error', () async {
      final pool = Lode<int>(create: () async => 42);
      await pool.dispose();

      expect(() => pool.acquire(), throwsA(isA<StateError>()));
    });

    // ─── Pillar Extension ─────────────────────────────────────

    test('Pillar extension creates lifecycle-managed Lode', () async {
      final pillar = _TestPillar();
      pillar.initialize();

      await pillar.pool.warmup(2);
      expect(pillar.pool.available.value, 2);

      final result = await pillar.pool.withResource((r) async => r * 3);
      expect(result, isPositive);

      pillar.dispose();
    });
  });
}

class _TestPillar extends Pillar {
  var _n = 0;

  late final pool = lode<int>(create: () async => ++_n, maxSize: 5);
}
