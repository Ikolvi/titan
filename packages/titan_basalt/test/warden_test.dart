import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

Future<void> _healthy() async {}

Future<void> _failing() async {
  throw Exception('service down');
}

int _callCount = 0;

Future<void> _countedCheck() async {
  _callCount++;
}

class _MonitorPillar extends Pillar {
  late final health = warden(
    interval: const Duration(seconds: 30),
    services: [
      WardenService(name: 'api', check: _healthy),
      WardenService(name: 'db', check: _healthy),
    ],
    name: 'test',
  );

  @override
  void initialize() {
    health; // Trigger lazy init.
  }
}

void main() {
  group('Warden', () {
    // ── Construction ───────────────────────────────────────────────────

    test('creates with services', () {
      final w = Warden(
        interval: const Duration(seconds: 10),
        services: [WardenService(name: 'api', check: _healthy)],
      );
      expect(w.serviceNames, ['api']);
      expect(w.isRunning, false);
      expect(w.overallHealth.value, ServiceStatus.unknown);
      expect(w.healthyCount.value, 0);
      expect(w.degradedCount.value, 0);
      expect(w.isChecking.value, false);
      expect(w.totalChecks.value, 0);
    });

    test('accepts multiple services', () {
      final w = Warden(
        interval: const Duration(seconds: 10),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _healthy),
          WardenService(name: 'cache', check: _healthy),
        ],
      );
      expect(w.serviceNames, hasLength(3));
    });

    test('asserts on empty services', () {
      expect(
        () => Warden(interval: const Duration(seconds: 10), services: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── Per-service state ──────────────────────────────────────────────

    test('initial per-service state is unknown', () {
      final w = Warden(
        interval: const Duration(seconds: 10),
        services: [WardenService(name: 'api', check: _healthy)],
      );
      expect(w.status('api').value, ServiceStatus.unknown);
      expect(w.latency('api').value, 0);
      expect(w.failures('api').value, 0);
      expect(w.lastChecked('api').value, isNull);
    });

    test('throws on unknown service name', () {
      final w = Warden(
        interval: const Duration(seconds: 10),
        services: [WardenService(name: 'api', check: _healthy)],
      );
      expect(() => w.status('unknown'), throwsArgumentError);
    });

    // ── Health checking ────────────────────────────────────────────────

    test('checkService marks healthy on success', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [WardenService(name: 'api', check: _healthy)],
      );

      await w.checkService('api');

      expect(w.status('api').value, ServiceStatus.healthy);
      expect(w.failures('api').value, 0);
      expect(w.lastChecked('api').value, isNotNull);
      expect(w.totalChecks.value, 1);
    });

    test('checkService marks degraded on failure', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [WardenService(name: 'api', check: _failing)],
      );

      await w.checkService('api');

      expect(w.status('api').value, ServiceStatus.degraded);
      expect(w.failures('api').value, 1);
    });

    test('checkService marks down after threshold failures', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'api', check: _failing, downThreshold: 3),
        ],
      );

      await w.checkService('api');
      expect(w.status('api').value, ServiceStatus.degraded);
      expect(w.failures('api').value, 1);

      await w.checkService('api');
      expect(w.status('api').value, ServiceStatus.degraded);
      expect(w.failures('api').value, 2);

      await w.checkService('api');
      expect(w.status('api').value, ServiceStatus.down);
      expect(w.failures('api').value, 3);
    });

    test('successful check resets failure count', () async {
      var shouldFail = true;
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(
            name: 'api',
            check: () async {
              if (shouldFail) throw Exception('fail');
            },
          ),
        ],
      );

      await w.checkService('api');
      expect(w.failures('api').value, 1);

      shouldFail = false;
      await w.checkService('api');
      expect(w.failures('api').value, 0);
      expect(w.status('api').value, ServiceStatus.healthy);
    });

    test('checkAll checks all services', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _healthy),
          WardenService(name: 'cache', check: _failing),
        ],
      );

      await w.checkAll();

      expect(w.status('auth').value, ServiceStatus.healthy);
      expect(w.status('db').value, ServiceStatus.healthy);
      expect(w.status('cache').value, ServiceStatus.degraded);
      expect(w.totalChecks.value, 3);
    });

    // ── Latency tracking ───────────────────────────────────────────────

    test('tracks latency', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(
            name: 'slow',
            check: () async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            },
          ),
        ],
      );

      await w.checkService('slow');
      expect(w.latency('slow').value, greaterThanOrEqualTo(15));
    });

    // ── Aggregate health ───────────────────────────────────────────────

    test('overallHealth is healthy when all critical pass', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _healthy),
        ],
      );

      await w.checkAll();
      expect(w.overallHealth.value, ServiceStatus.healthy);
      expect(w.healthyCount.value, 2);
      expect(w.degradedCount.value, 0);
    });

    test('overallHealth degrades when critical service fails', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _failing),
        ],
      );

      await w.checkAll();
      expect(w.overallHealth.value, ServiceStatus.degraded);
    });

    test('non-critical failures do not affect overallHealth', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'analytics', check: _failing, critical: false),
        ],
      );

      await w.checkAll();
      expect(w.overallHealth.value, ServiceStatus.healthy);
      expect(w.status('analytics').value, ServiceStatus.degraded);
      expect(w.healthyCount.value, 1);
      expect(w.degradedCount.value, 1);
    });

    test('overallHealth is unknown when not all checked', () {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _healthy),
        ],
      );
      expect(w.overallHealth.value, ServiceStatus.unknown);
    });

    // ── Start/Stop ─────────────────────────────────────────────────────

    test('start begins polling', () async {
      _callCount = 0;
      final w = Warden(
        interval: const Duration(milliseconds: 50),
        services: [WardenService(name: 'api', check: _countedCheck)],
      );

      w.start();
      expect(w.isRunning, true);

      // Wait for initial check + at least one periodic.
      await Future<void>.delayed(const Duration(milliseconds: 130));
      w.stop();

      expect(_callCount, greaterThanOrEqualTo(2));
      expect(w.isRunning, false);
    });

    test('stop cancels timers', () async {
      _callCount = 0;
      final w = Warden(
        interval: const Duration(milliseconds: 50),
        services: [WardenService(name: 'api', check: _countedCheck)],
      );

      w.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      w.stop();
      final count = _callCount;

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(_callCount, count); // No more calls after stop.
    });

    test('start is idempotent', () {
      final w = Warden(
        interval: const Duration(seconds: 10),
        services: [WardenService(name: 'api', check: _healthy)],
      );
      w.start();
      w.start(); // Should not double-start.
      w.stop();
    });

    // ── Reset ──────────────────────────────────────────────────────────

    test('reset clears all state', () async {
      final w = Warden(
        interval: const Duration(seconds: 60),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _failing),
        ],
      );

      await w.checkAll();
      expect(w.totalChecks.value, 2);

      w.reset();

      expect(w.status('auth').value, ServiceStatus.unknown);
      expect(w.status('db').value, ServiceStatus.unknown);
      expect(w.failures('db').value, 0);
      expect(w.totalChecks.value, 0);
      expect(w.isRunning, false);
    });

    // ── Per-service interval ───────────────────────────────────────────

    test('per-service interval override works', () async {
      var authCalls = 0;
      var dbCalls = 0;

      final w = Warden(
        interval: const Duration(milliseconds: 200),
        services: [
          WardenService(
            name: 'auth',
            check: () async => authCalls++,
            interval: const Duration(milliseconds: 50),
          ),
          WardenService(name: 'db', check: () async => dbCalls++),
        ],
      );

      w.start();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      w.stop();

      // Auth should have more calls (faster interval).
      expect(authCalls, greaterThan(dbCalls));
    });

    // ── ServiceStatus enum ─────────────────────────────────────────────

    test('ServiceStatus values', () {
      expect(ServiceStatus.values, hasLength(4));
      expect(ServiceStatus.unknown.name, 'unknown');
      expect(ServiceStatus.healthy.name, 'healthy');
      expect(ServiceStatus.degraded.name, 'degraded');
      expect(ServiceStatus.down.name, 'down');
    });

    // ── WardenService config ───────────────────────────────────────────

    test('WardenService defaults', () {
      final svc = WardenService(name: 'test', check: _healthy);
      expect(svc.name, 'test');
      expect(svc.interval, isNull);
      expect(svc.critical, true);
      expect(svc.downThreshold, 3);
    });

    // ── managedNodes ───────────────────────────────────────────────────

    test('managedNodes includes all reactive nodes', () {
      final w = Warden(
        interval: const Duration(seconds: 10),
        services: [
          WardenService(name: 'auth', check: _healthy),
          WardenService(name: 'db', check: _healthy),
        ],
      );
      // 2 global (isChecking, totalChecks) + 2×4 per-service = 10.
      expect(w.managedNodes.toList(), hasLength(10));
    });

    // ── Dispose ────────────────────────────────────────────────────────

    test('dispose stops timers', () async {
      _callCount = 0;
      final w = Warden(
        interval: const Duration(milliseconds: 50),
        services: [WardenService(name: 'api', check: _countedCheck)],
      );
      w.start();
      w.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final count = _callCount;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(_callCount, count);
    });

    // ── Pillar integration ─────────────────────────────────────────────

    test('works as Pillar extension', () async {
      final pillar = _MonitorPillar();
      pillar.initialize();

      await pillar.health.checkAll();

      expect(pillar.health.overallHealth.value, ServiceStatus.healthy);
      expect(pillar.health.healthyCount.value, 2);

      pillar.dispose();
    });
  });
}
