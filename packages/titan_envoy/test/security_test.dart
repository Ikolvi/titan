import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';
import 'package:titan_envoy/src/transport/transport_io.dart' as io_transport;

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

    group('transport integration', () {
      test('creates transport with self-signed pin without error', () {
        final pin = EnvoyPin(allowSelfSigned: true);
        final transport = io_transport.createTransport(pin: pin);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
      });

      test('creates transport with empty fingerprints without error', () {
        final pin = EnvoyPin();
        final transport = io_transport.createTransport(pin: pin);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
      });

      test('creates transport with fingerprint pinning without error', () {
        final pin = EnvoyPin(
          fingerprints: ['abcdef1234567890abcdef1234567890abcdef12'],
        );
        final transport = io_transport.createTransport(pin: pin);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
      });

      test('creates transport with hostOverride without error', () {
        final pin = EnvoyPin(
          fingerprints: ['abc123'],
          hostOverride: 'api.example.com',
        );
        final transport = io_transport.createTransport(pin: pin);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
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

    group('transport integration', () {
      test('creates transport with proxy without error', () {
        final proxy = EnvoyProxy(host: 'proxy.test.com', port: 9090);
        final transport = io_transport.createTransport(proxy: proxy);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
      });

      test('creates transport with proxy credentials without error', () {
        final proxy = EnvoyProxy(
          host: 'proxy.test.com',
          port: 9090,
          username: 'user',
          password: 'pass',
        );
        final transport = io_transport.createTransport(proxy: proxy);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
      });

      test('creates transport with bypass list without error', () {
        final proxy = EnvoyProxy(
          host: 'proxy.test.com',
          port: 9090,
          bypass: ['localhost', '127.0.0.1'],
        );
        final transport = io_transport.createTransport(proxy: proxy);
        addTearDown(() => transport.close());

        // Should not throw
        expect(transport, isNotNull);
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
