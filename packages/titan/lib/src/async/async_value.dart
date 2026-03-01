/// Represents the state of an asynchronous operation.
///
/// [AsyncValue] is a sealed class with three states:
/// - [AsyncData] — The operation completed successfully with data.
/// - [AsyncLoading] — The operation is in progress.
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
///   case AsyncError(:final error):
///     return ErrorWidget(error);
/// }
/// ```
sealed class AsyncValue<T> {
  const AsyncValue();

  /// Creates a data state.
  const factory AsyncValue.data(T data) = AsyncData<T>;

  /// Creates a loading state.
  const factory AsyncValue.loading() = AsyncLoading<T>;

  /// Creates an error state.
  const factory AsyncValue.error(Object error, [StackTrace? stackTrace]) =
      AsyncError<T>;

  /// Whether this is a data state.
  bool get isData => this is AsyncData<T>;

  /// Whether this is a loading state.
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether this is an error state.
  bool get isError => this is AsyncError<T>;

  /// Returns the data if this is a [AsyncData], otherwise `null`.
  T? get dataOrNull {
    if (this is AsyncData<T>) {
      return (this as AsyncData<T>).data;
    }
    return null;
  }

  /// Returns the error if this is [AsyncError], otherwise `null`.
  Object? get errorOrNull {
    if (this is AsyncError<T>) {
      return (this as AsyncError<T>).error;
    }
    return null;
  }

  /// Maps each state to a value.
  R when<R>({
    required R Function(T data) onData,
    required R Function() onLoading,
    required R Function(Object error, StackTrace? stackTrace) onError,
  }) {
    return switch (this) {
      AsyncData<T>(:final data) => onData(data),
      AsyncLoading<T>() => onLoading(),
      AsyncError<T>(:final error, :final stackTrace) =>
        onError(error, stackTrace),
    };
  }

  /// Maps each state to a value with optional fallbacks.
  R maybeWhen<R>({
    R Function(T data)? onData,
    R Function()? onLoading,
    R Function(Object error, StackTrace? stackTrace)? onError,
    required R Function() orElse,
  }) {
    return switch (this) {
      AsyncData<T>(:final data) =>
        onData != null ? onData(data) : orElse(),
      AsyncLoading<T>() =>
        onLoading != null ? onLoading() : orElse(),
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
      identical(this, other) ||
      other is AsyncData<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'AsyncData<$T>($data)';
}

/// Loading async state.
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
      identical(this, other) ||
      other is AsyncError<T> && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'AsyncError<$T>($error)';
}
