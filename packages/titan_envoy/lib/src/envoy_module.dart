import 'package:titan/titan.dart';

import 'courier.dart';
import 'couriers/auth_courier.dart';
import 'couriers/log_courier.dart';
import 'couriers/metrics_courier.dart';
import 'couriers/retry_courier.dart';
import 'envoy.dart';
import 'metrics.dart';

/// **EnvoyModule** — One-line setup for a shared [Envoy] across the app.
///
/// Registers a pre-configured [Envoy] instance in the Titan DI container
/// with optional default couriers, so any Pillar can access it via
/// `Titan.get<Envoy>()`.
///
/// ```dart
/// void main() {
///   // Register shared Envoy with enterprise defaults
///   EnvoyModule.install(
///     baseUrl: 'https://api.example.com',
///     defaultCouriers: [
///       LogCourier(),
///       RetryCourier(maxRetries: 3),
///       AuthCourier(tokenProvider: () => getToken()),
///     ],
///   );
///
///   runApp(MyApp());
/// }
///
/// // In any Pillar — zero setup needed:
/// class UserPillar extends Pillar {
///   Envoy get envoy => Titan.get<Envoy>();
///
///   Future<void> loadUsers() => strikeAsync(() async {
///     final dispatch = await envoy.get('/users');
///     users.value = parseUsers(dispatch.data);
///   });
/// }
/// ```
///
/// ## Presets
///
/// Use factory constructors for common configurations:
///
/// ```dart
/// // Development preset — logging + no retries
/// EnvoyModule.dev(baseUrl: 'http://localhost:3000');
///
/// // Production preset — retries + metrics + auth
/// EnvoyModule.production(
///   baseUrl: 'https://api.example.com',
///   tokenProvider: () => Titan.get<AuthPillar>().token.value,
///   onMetric: (m) => Colossus.instance.trackApiMetric(m.toJson()),
///   maxRetries: 3,
/// );
/// ```
class EnvoyModule {
  EnvoyModule._();

  /// Installs a shared [Envoy] instance in the Titan DI container.
  ///
  /// - [baseUrl]: Base URL for all requests.
  /// - [defaultCouriers]: Couriers applied to every request.
  /// - [connectTimeout]: Connection timeout.
  /// - [sendTimeout]: Request send timeout.
  /// - [receiveTimeout]: Response receive timeout.
  /// - [headers]: Default headers for all requests.
  /// - [onMetric]: Callback for request metrics (wire to Colossus).
  ///
  /// After calling this, access the client anywhere:
  /// ```dart
  /// final envoy = Titan.get<Envoy>();
  /// ```
  static Envoy install({
    String baseUrl = '',
    List<Courier> defaultCouriers = const [],
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, String>? headers,
    void Function(EnvoyMetric)? onMetric,
  }) {
    final envoy = Envoy(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: headers,
    );

    for (final courier in defaultCouriers) {
      envoy.addCourier(courier);
    }

    if (onMetric != null) {
      envoy.addCourier(MetricsCourier(onMetric: onMetric));
    }

    Titan.put<Envoy>(envoy);
    return envoy;
  }

  /// Development preset — installs an [Envoy] with logging enabled.
  ///
  /// ```dart
  /// EnvoyModule.dev(baseUrl: 'http://localhost:3000');
  /// ```
  static Envoy dev({
    String baseUrl = '',
    Duration? connectTimeout,
    Map<String, String>? headers,
  }) {
    return install(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      headers: headers,
      defaultCouriers: [LogCourier()],
    );
  }

  /// Production preset — retries, auth, and metrics pre-configured.
  ///
  /// ```dart
  /// EnvoyModule.production(
  ///   baseUrl: 'https://api.example.com',
  ///   tokenProvider: () => getToken(),
  ///   onMetric: (m) => analytics.track(m),
  ///   maxRetries: 3,
  /// );
  /// ```
  static Envoy production({
    String baseUrl = '',
    int maxRetries = 3,
    String Function()? tokenProvider,
    void Function(EnvoyMetric)? onMetric,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, String>? headers,
  }) {
    final couriers = <Courier>[RetryCourier(maxRetries: maxRetries)];

    if (tokenProvider != null) {
      couriers.add(AuthCourier(tokenProvider: tokenProvider));
    }

    return install(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: headers,
      defaultCouriers: couriers,
      onMetric: onMetric,
    );
  }

  /// Removes the registered [Envoy] from the DI container and closes it.
  static void uninstall() {
    final envoy = Titan.find<Envoy>();
    if (envoy != null) {
      envoy.close();
      Titan.remove<Envoy>();
    }
  }
}
