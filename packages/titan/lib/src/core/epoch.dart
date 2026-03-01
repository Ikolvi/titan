/// **Epoch** — Marks a point in time, enabling undo & redo.
///
/// `Epoch<T>` extends [TitanState] with a history stack, allowing you to
/// revert or replay state changes — perfect for editors, form builders,
/// and any feature that needs time-travel state.
///
/// ## Quick Start
///
/// ```dart
/// class EditorPillar extends Pillar {
///   late final text = epoch('');
///
///   void type(String s) => strike(() => text.value = s);
///   void undo() => text.undo();
///   void redo() => text.redo();
/// }
/// ```
///
/// ## API
///
/// - [undo] — Revert to the previous value
/// - [redo] — Replay the next value
/// - [canUndo] / [canRedo] — Check capability
/// - [clearHistory] — Wipe history, keep current value
/// - [history] — Read-only list of past values
/// - [maxHistory] — Configurable stack depth (default 100)
library;

import 'state.dart';

/// A [TitanState] with undo/redo history.
///
/// **Epoch** marks a point in time — each value change is recorded, allowing
/// navigation back and forth through the state's history.
///
/// ```dart
/// final name = Epoch<String>('');
///
/// name.value = 'Alice';
/// name.value = 'Bob';
///
/// name.undo();           // 'Alice'
/// name.undo();           // ''
/// name.redo();           // 'Alice'
///
/// name.canUndo;          // true
/// name.canRedo;          // true
/// name.history;          // ['', 'Alice']
/// ```
///
/// Inside a Pillar, use [Pillar.epoch] instead:
///
/// ```dart
/// class EditorPillar extends Pillar {
///   late final content = epoch('', maxHistory: 200);
///
///   void updateContent(String text) {
///     strike(() => content.value = text);
///   }
///
///   void undo() => content.undo();
///   void redo() => content.redo();
/// }
/// ```
class Epoch<T> extends TitanState<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];

  /// Maximum number of undo entries to keep.
  ///
  /// When the stack exceeds this size, the oldest entry is discarded.
  /// Defaults to 100.
  final int maxHistory;

  /// Creates an [Epoch] with the given initial value.
  ///
  /// - [maxHistory] — Maximum undo depth (default 100).
  /// - [name] — Optional debug name.
  /// - [equals] — Custom equality function.
  Epoch(
    super.initialValue, {
    this.maxHistory = 100,
    super.name,
    super.equals,
  });

  /// Sets the value, recording the previous value for undo.
  ///
  /// Setting a new value clears the redo stack (forward history is lost
  /// when you branch).
  @override
  set value(T newValue) {
    final current = peek();

    // Let TitanState handle equality check and notification
    super.value = newValue;

    // Only record history if value actually changed
    if (!identical(peek(), current) && peek() == newValue) {
      _undoStack.add(current);
      _redoStack.clear();

      // Trim oldest entries if over limit
      while (_undoStack.length > maxHistory) {
        _undoStack.removeAt(0);
      }
    }
  }

  /// Whether there is a previous state to revert to.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is a forward state to replay.
  bool get canRedo => _redoStack.isNotEmpty;

  /// The number of undo steps available.
  int get undoCount => _undoStack.length;

  /// The number of redo steps available.
  int get redoCount => _redoStack.length;

  /// A read-only view of the undo history (oldest first).
  List<T> get history => List.unmodifiable(_undoStack);

  /// Reverts to the previous value.
  ///
  /// Does nothing if [canUndo] is `false`.
  ///
  /// ```dart
  /// epoch.value = 'A';
  /// epoch.value = 'B';
  /// epoch.undo(); // value is now 'A'
  /// ```
  void undo() {
    if (!canUndo) return;

    final current = peek();
    final previous = _undoStack.removeLast();

    _redoStack.add(current);
    super.value = previous;
  }

  /// Replays the next value in the redo stack.
  ///
  /// Does nothing if [canRedo] is `false`.
  ///
  /// ```dart
  /// epoch.undo();
  /// epoch.redo(); // restores the value before undo
  /// ```
  void redo() {
    if (!canRedo) return;

    final current = peek();
    final next = _redoStack.removeLast();

    _undoStack.add(current);
    super.value = next;
  }

  /// Clears all undo/redo history, keeping the current value.
  ///
  /// ```dart
  /// epoch.clearHistory();
  /// epoch.canUndo; // false
  /// epoch.canRedo; // false
  /// ```
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  @override
  String toString() {
    final label = name != null ? '($name)' : '';
    return 'Epoch$label<$T>: ${peek()} '
        '[undo: ${_undoStack.length}, redo: ${_redoStack.length}]';
  }
}
