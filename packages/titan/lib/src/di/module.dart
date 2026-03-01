import '../store/store.dart';
import 'container.dart';

/// A module for organizing related store registrations.
///
/// [TitanModule] groups related store registrations together, promoting
/// modularity and separation of concerns. Modules can be composed to
/// build the complete dependency graph.
///
/// ## Usage
///
/// ```dart
/// class AuthModule extends TitanModule {
///   @override
///   void register(TitanContainer container) {
///     container.register(() => AuthStore());
///     container.register(() => UserProfileStore());
///   }
/// }
///
/// class AppModule extends TitanModule {
///   @override
///   void register(TitanContainer container) {
///     container.register(() => AppSettingsStore());
///     container.register(() => ThemeStore());
///   }
/// }
///
/// // In Flutter:
/// TitanScope(
///   modules: [AuthModule(), AppModule()],
///   child: MyApp(),
/// )
/// ```
abstract class TitanModule {
  /// Registers all stores provided by this module.
  void register(TitanContainer container);
}

/// A convenience module created from a list of store factories.
///
/// ```dart
/// final module = TitanSimpleModule([
///   () => CounterStore(),
///   () => AuthStore(),
/// ]);
/// ```
class TitanSimpleModule extends TitanModule {
  final List<TitanStore Function()> _factories;

  /// Creates a simple module from a list of store factory functions.
  TitanSimpleModule(this._factories);

  @override
  void register(TitanContainer container) {
    for (final factory in _factories) {
      container.register(factory);
    }
  }
}
