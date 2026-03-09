import 'dart:io';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

void main() {
  group('EnvoyPin', () {
    group('construction', () {
      test('creates with defaults', () {
        final pin = EnvoyPin();
        expect(pin.fingerprints, isEmpty);
        expect(pin.hostOverride, isNull);
        expect(pin.allowSelfSigned, isFalse);
      });

      test('creates with custom values', () {
        final pin = EnvoyPin(
          fingerprints: ['abcdef1234567890abcdef1234567890abcdef12'],
          hostOverride: 'api.example.com',
          allowSelfSigned: true,
        );
        expect(pin.fingerprints, hasLength(1));
        expect(pin.hostOverride, 'api.example.com');
        expect(pin.allowSelfSigned, isTrue);
      });
    });

    group('applyTo', () {
      test('applies self-signed to HttpClient without error', () {
        final pin = EnvoyPin(allowSelfSigned: true);
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        pin.applyTo(client);
      });

      test('no-op when fingerprints empty and not self-signed', () {
        final pin = EnvoyPin();
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        pin.applyTo(client);
      });

      test('applies fingerprint pinning without error', () {
        final pin = EnvoyPin(
          fingerprints: ['abcdef1234567890abcdef1234567890abcdef12'],
        );
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        pin.applyTo(client);
      });

      test('applies with hostOverride without error', () {
        final pin = EnvoyPin(
          fingerprints: ['abc123'],
          hostOverride: 'api.example.com',
        );
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        pin.applyTo(client);
      });
    });
  });

  group('EnvoyProxy', () {
    group('construction', () {
      test('creates with required fields', () {
        final proxy = EnvoyProxy(host: 'proxy.example.com', port: 8080);
        expect(proxy.host, 'proxy.example.com');
        expect(proxy.port, 8080);
        expect(proxy.username, isNull);
        expect(proxy.password, isNull);
        expect(proxy.bypass, isEmpty);
      });

      test('creates with all fields', () {
        final proxy = EnvoyProxy(
          host: 'proxy.corp.com',
          port: 3128,
          username: 'admin',
          password: 'secret',
          bypass: ['localhost', '127.0.0.1', 'internal.corp.com'],
        );
        expect(proxy.host, 'proxy.corp.com');
        expect(proxy.port, 3128);
        expect(proxy.username, 'admin');
        expect(proxy.password, 'secret');
        expect(proxy.bypass, hasLength(3));
      });
    });

    group('applyTo', () {
      test('applies proxy to HttpClient without error', () {
        final proxy = EnvoyProxy(host: 'proxy.test.com', port: 9090);
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        proxy.applyTo(client);
      });

      test('applies proxy with credentials without error', () {
        final proxy = EnvoyProxy(
          host: 'proxy.test.com',
          port: 9090,
          username: 'user',
          password: 'pass',
        );
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        proxy.applyTo(client);
      });

      test('applies proxy with bypass list without error', () {
        final proxy = EnvoyProxy(
          host: 'proxy.test.com',
          port: 9090,
          bypass: ['localhost', '127.0.0.1'],
        );
        final client = HttpClient();
        addTearDown(client.close);

        // Should not throw
        proxy.applyTo(client);
      });
    });

    group('toString', () {
      test('without auth', () {
        final proxy = EnvoyProxy(host: 'proxy.com', port: 8080);
        expect(proxy.toString(), 'EnvoyProxy(proxy.com:8080)');
      });

      test('with auth', () {
        final proxy = EnvoyProxy(
          host: 'proxy.com',
          port: 8080,
          username: 'user',
          password: 'pass',
        );
        expect(proxy.toString(), 'EnvoyProxy(proxy.com:8080 auth=user)');
      });
    });
  });
}
