import 'package:titan/titan.dart';

import 'envoy.dart';
import 'courier.dart';
import 'metrics.dart';

/// **EnvoyPillar** — A [Pillar] base class that owns and manages an [Envoy]
/// HTTP client instance with automatic lifecycle management.
///
/// Extend this instead of [Pillar] to get a pre-configured Envoy client
/// that is automatically disposed with the Pillar, tracks metrics via
/// [onMetric], and wires up default couriers.
///
/// ```dart
/// class UserPillar extends EnvoyPillar {
///   UserPillar() : super(baseUrl: 'https://api.example.com');
///
///   late final users = core<List<User>>([]);
///   late final isLoading = core(false);
///
///   Future<void> loadUsers() => strikeAsync(() async {
///     isLoading.value = true;
///     final dispatch = await envoy.get('/users');
///     users.value = (dispatch.data as List).map(User.fromJson).toList();
///     isLoading.value = false;
///   });
/// }
/// ```
///
/// ## Features
///
/// - **Auto-disposal**: The Envoy client is closed when the Pillar disposes.
/// - **Metric tracking**: Override [onMetric] to forward metrics to Colossus.
/// - **Default couriers**: Attach couriers in [configureCouriers] for
///   consistent behavior across all requests.
/// - **Base URL inheritance**: All Pillars sharing a base URL can extend
///   this with the same constructor argument.
///
/// ## With EnvoyModule
///
/// For apps that want a single shared [Envoy] across multiple Pillars,
/// use [EnvoyModule] instead:
///
/// ```dart
/// // In main():
/// Titan.put(EnvoyModule(baseUrl: 'https://api.example.com'));
///
/// // In any Pillar:
/// final envoy = Titan.get<Envoy>();
/// ```
abstract class EnvoyPillar extends Pillar {
  /// Creates an [EnvoyPillar] with a dedicated [Envoy] instance.
  ///
  /// - [baseUrl]: Base URL for all requests.
  /// - [connectTimeout]: Connection timeout.
  /// - [sendTimeout]: Request send timeout.
  /// - [receiveTimeout]: Response receive timeout.
  /// - [headers]: Default headers for all requests.
  EnvoyPillar({
    String baseUrl = '',
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    Map<String, String>? headers,
  }) : _envoy = Envoy(
         baseUrl: baseUrl,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         headers: headers,
       );

  final Envoy _envoy;

  /// The managed [Envoy] HTTP client.
  ///
  /// Use this to make HTTP requests. The client is automatically
  /// closed when the Pillar disposes.
  Envoy get envoy => _envoy;

  @override
  void onInit() {
    super.onInit();

    // Allow subclass to configure couriers
    configureCouriers(_envoy);
  }

  @override
  void onDispose() {
    _envoy.close();
    super.onDispose();
  }

  /// Override to add default [Courier]s to the Envoy instance.
  ///
  /// Called during [onInit]. Add logging, retry, auth, caching, etc.:
  ///
  /// ```dart
  /// @override
  /// void configureCouriers(Envoy envoy) {
  ///   envoy.addCourier(LogCourier());
  ///   envoy.addCourier(RetryCourier(maxRetries: 3));
  ///   envoy.addCourier(AuthCourier(
  ///     tokenProvider: () => Titan.get<AuthPillar>().token.value,
  ///   ));
  /// }
  /// ```
  void configureCouriers(Envoy envoy) {}

  /// Override to handle metrics from completed requests.
  ///
  /// Use this to forward metrics to Colossus or custom analytics:
  ///
  /// ```dart
  /// @override
  /// void onMetric(EnvoyMetric metric) {
  ///   Colossus.instance.trackApiMetric(metric.toJson());
  /// }
  /// ```
  void onMetric(EnvoyMetric metric) {}
}
