import '../core/state.dart';
import 'async_value.dart';

/// A reactive state container for asynchronous operations.
///
/// [TitanAsyncState] wraps a [TitanState] of [AsyncValue] and provides
/// convenient methods for loading, refreshing, and error handling.
///
/// ## Usage
///
/// ```dart
/// class UserStore extends TitanStore {
///   late final users = TitanAsyncState<List<User>>(name: 'users');
///
///   Future<void> loadUsers() async {
///     await users.load(() => api.fetchUsers());
///   }
///
///   Future<void> refreshUsers() async {
///     await users.refresh(() => api.fetchUsers());
///   }
/// }
/// ```
class TitanAsyncState<T> {
  final TitanState<AsyncValue<T>> _state;

  /// Creates an async state, initially in loading state.
  ///
  /// - [name] — Optional debug name.
  /// - [initialValue] — Initial async value. Defaults to [AsyncLoading].
  TitanAsyncState({String? name, AsyncValue<T>? initialValue})
    : _state = TitanState<AsyncValue<T>>(
        initialValue ?? const AsyncLoading(),
        name: name,
      );

  /// The underlying reactive state.
  TitanState<AsyncValue<T>> get state => _state;

  /// The current async value.
  AsyncValue<T> get value => _state.value;

  /// The current data, if available.
  T? get data => _state.value.dataOrNull;

  /// Whether the current state is loading.
  bool get isLoading => _state.value.isLoading;

  /// Whether the current state has data.
  bool get hasData => _state.value.isData;

  /// Whether the current state has an error.
  bool get hasError => _state.value.isError;

  /// Loads data using the provided [loader] function.
  ///
  /// Sets the state to [AsyncLoading] before calling the loader,
  /// then sets it to [AsyncData] or [AsyncError] based on the result.
  Future<void> load(Future<T> Function() loader) async {
    _state.value = const AsyncLoading();
    try {
      final result = await loader();
      _state.value = AsyncData<T>(result);
    } catch (e, s) {
      _state.value = AsyncError<T>(e, s);
    }
  }

  /// Refreshes data while keeping the current data visible.
  ///
  /// Unlike [load], this does NOT set the state to loading first.
  /// The previous data remains accessible during the refresh.
  Future<void> refresh(Future<T> Function() loader) async {
    try {
      final result = await loader();
      _state.value = AsyncData<T>(result);
    } catch (e, s) {
      _state.value = AsyncError<T>(e, s);
    }
  }

  /// Sets the state to a specific value.
  void setValue(T data) {
    _state.value = AsyncData<T>(data);
  }

  /// Sets the state to an error.
  void setError(Object error, [StackTrace? stackTrace]) {
    _state.value = AsyncError<T>(error, stackTrace);
  }

  /// Resets the state to loading.
  void reset() {
    _state.value = const AsyncLoading();
  }

  /// Disposes the underlying state.
  void dispose() {
    _state.dispose();
  }
}
