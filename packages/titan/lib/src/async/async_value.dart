/// Represents the state of an asynchronous operation.
///
/// [AsyncValue] is a sealed class with four states:
/// - [AsyncData] — The operation completed successfully with data.
/// - [AsyncLoading] — The operation is in progress (no previous data).
/// - [AsyncRefreshing] — The operation is refreshing (has previous data).
/// - [AsyncError] — The operation failed with an error.
///
/// ## Usage
///
/// ```dart
/// final users = TitanState<AsyncValue<List<User>>>(
///   const AsyncLoading(),
/// );
///
/// // In UI:
/// switch (users.value) {
///   case AsyncData(:final data):
///     return UserList(users: data);
///   case AsyncLoading():
///     return CircularProgressIndicator();
///   case AsyncRefreshing(:final data):
///     return Stack(children: [UserList(users: data), LoadingOverlay()]);
///   case AsyncError(:final error):
///     return ErrorWidget(error);
/// }
/// ```
sealed class AsyncValue<T> {
  const AsyncValue();

  /// Creates a data state.
  const factory AsyncValue.data(T data) = AsyncData<T>;

  /// Creates a loading state (no previous data).
  const factory AsyncValue.loading() = AsyncLoading<T>;

  /// Creates a refreshing state (loading with previous data).
  const factory AsyncValue.refreshing(T data) = AsyncRefreshing<T>;

  /// Creates an error state.
  const factory AsyncValue.error(Object error, [StackTrace? stackTrace]) =
      AsyncError<T>;

  /// Whether this is a data state.
  bool get isData => this is AsyncData<T>;

  /// Whether this is a loading state (no previous data).
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether this is a refreshing state (loading with previous data).
  bool get isRefreshing => this is AsyncRefreshing<T>;

  /// Whether this is currently loading or refreshing.
  bool get isLoadingOrRefreshing => isLoading || isRefreshing;

  /// Whether this is an error state.
  bool get isError => this is AsyncError<T>;

  /// Whether this state contains data (either [AsyncData] or [AsyncRefreshing]).
  bool get hasData => this is AsyncData<T> || this is AsyncRefreshing<T>;

  /// Returns the data if this is a [AsyncData] or [AsyncRefreshing],
  /// otherwise `null`.
  T? get dataOrNull {
    if (this is AsyncData<T>) {
      return (this as AsyncData<T>).data;
    }
    if (this is AsyncRefreshing<T>) {
      return (this as AsyncRefreshing<T>).data;
    }
    return null;
  }

  /// Returns the data or throws if no data is available.
  ///
  /// Throws [StateError] if not in a data-containing state.
  T get requireData {
    final d = dataOrNull;
    if (d != null) return d;
    throw StateError('AsyncValue has no data: $this');
  }

  /// Returns the error if this is [AsyncError], otherwise `null`.
  Object? get errorOrNull {
    if (this is AsyncError<T>) {
      return (this as AsyncError<T>).error;
    }
    return null;
  }

  /// Transforms the data value using [transform] if data is available.
  ///
  /// ```dart
  /// final names = users.map((list) => list.map((u) => u.name).toList());
  /// ```
  AsyncValue<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      AsyncData<T>(:final data) => AsyncValue<R>.data(transform(data)),
      AsyncLoading<T>() => AsyncValue<R>.loading(),
      AsyncRefreshing<T>(:final data) =>
        AsyncValue<R>.refreshing(transform(data)),
      AsyncError<T>(:final error, :final stackTrace) =>
        AsyncValue<R>.error(error, stackTrace),
    };
  }

  /// Maps each state to a value.
  R when<R>({
    required R Function(T data) onData,
    required R Function() onLoading,
    required R Function(Object error, StackTrace? stackTrace) onError,
    R Function(T data)? onRefreshing,
  }) {
    return switch (this) {
      AsyncData<T>(:final data) => onData(data),
      AsyncLoading<T>() => onLoading(),
      AsyncRefreshing<T>(:final data) =>
        onRefreshing != null ? onRefreshing(data) : onData(data),
      AsyncError<T>(:final error, :final stackTrace) => onError(
        error,
        stackTrace,
      ),
    };
  }

  /// Maps each state to a value with optional fallbacks.
  R maybeWhen<R>({
    R Function(T data)? onData,
    R Function()? onLoading,
    R Function(Object error, StackTrace? stackTrace)? onError,
    R Function(T data)? onRefreshing,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncData<T>(:final data) => onData != null ? onData(data) : orElse(),
      AsyncLoading<T>() => onLoading != null ? onLoading() : orElse(),
      AsyncRefreshing<T>(:final data) =>
        onRefreshing != null ? onRefreshing(data) : orElse(),
      AsyncError<T>(:final error, :final stackTrace) =>
        onError != null ? onError(error, stackTrace) : orElse(),
    };
  }
}

/// Successful async state with data.
class AsyncData<T> extends AsyncValue<T> {
  /// The data value.
  final T data;

  /// Creates a data state.
  const AsyncData(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AsyncData<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'AsyncData<$T>($data)';
}

/// Loading async state (no previous data available).
class AsyncLoading<T> extends AsyncValue<T> {
  /// Creates a loading state.
  const AsyncLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AsyncLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AsyncLoading<$T>()';
}

/// Refreshing async state — loading with previous data preserved.
///
/// Used when refetching data while still displaying the previous result.
/// This enables smooth UX patterns like pull-to-refresh, background
/// revalidation, and stale-while-revalidate.
///
/// ```dart
/// // Transition from data to refreshing
/// if (state.value is AsyncData<User>) {
///   state.value = AsyncValue.refreshing(state.value.dataOrNull!);
///   final freshData = await api.fetchUser();
///   state.value = AsyncValue.data(freshData);
/// }
/// ```
class AsyncRefreshing<T> extends AsyncValue<T> {
  /// The previous data that is being refreshed.
  final T data;

  /// Creates a refreshing state with previous [data].
  const AsyncRefreshing(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncRefreshing<T> && other.data == data;

  @override
  int get hashCode => data.hashCode ^ 0x7ef1;

  @override
  String toString() => 'AsyncRefreshing<$T>($data)';
}

/// Error async state.
class AsyncError<T> extends AsyncValue<T> {
  /// The error object.
  final Object error;

  /// The stack trace, if available.
  final StackTrace? stackTrace;

  /// Creates an error state.
  const AsyncError(this.error, [this.stackTrace]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AsyncError<T> && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'AsyncError<$T>($error)';
}
