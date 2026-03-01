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
  late List<T?> _undoBuffer;
  int _undoHead = 0;
  int _undoCount = 0;
  final List<T> _redoStack = [];

  /// Maximum number of undo entries to keep.
  ///
  /// When the buffer exceeds this size, the oldest entry is discarded
  /// in O(1) time using a ring buffer.
  /// Defaults to 100.
  final int maxHistory;

  /// Creates an [Epoch] with the given initial value.
  ///
  /// - [maxHistory] — Maximum undo depth (default 100).
  /// - [name] — Optional debug name.
  /// - [equals] — Custom equality function.
  Epoch(super.initialValue, {this.maxHistory = 100, super.name, super.equals})
    : _undoBuffer = List<T?>.filled(maxHistory, null);

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
      // Write to ring buffer at the next position
      if (_undoCount < maxHistory) {
        // Buffer not yet full
        _undoBuffer[_undoCount] = current;
        _undoCount++;
      } else {
        // Buffer full — overwrite oldest entry (O(1))
        _undoBuffer[_undoHead] = current;
        _undoHead = (_undoHead + 1) % maxHistory;
      }
      _redoStack.clear();
    }
  }

  /// Whether there is a previous state to revert to.
  bool get canUndo => _undoCount > 0;

  /// Whether there is a forward state to replay.
  bool get canRedo => _redoStack.isNotEmpty;

  /// The number of undo steps available.
  int get undoCount => _undoCount;

  /// The number of redo steps available.
  int get redoCount => _redoStack.length;

  /// A read-only view of the undo history (oldest first).
  List<T> get history {
    if (_undoCount == 0) return const [];
    final result = <T>[];
    if (_undoCount < maxHistory) {
      // Buffer not full — entries at 0.._undoCount-1
      for (var i = 0; i < _undoCount; i++) {
        result.add(_undoBuffer[i] as T);
      }
    } else {
      // Buffer full — oldest at _undoHead, wrap around
      for (var i = 0; i < _undoCount; i++) {
        result.add(_undoBuffer[(_undoHead + i) % maxHistory] as T);
      }
    }
    return List.unmodifiable(result);
  }

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
    // Pop from ring buffer (read the most recent entry)
    _undoCount--;
    final readIndex = _undoCount < maxHistory
        ? _undoCount
        : (_undoHead + _undoCount) % maxHistory;
    final previous = _undoBuffer[readIndex] as T;

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

    // Push back onto ring buffer
    if (_undoCount < maxHistory) {
      _undoBuffer[_undoCount] = current;
      _undoCount++;
    } else {
      _undoBuffer[_undoHead] = current;
      _undoHead = (_undoHead + 1) % maxHistory;
    }
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
    _undoBuffer = List<T?>.filled(maxHistory, null);
    _undoHead = 0;
    _undoCount = 0;
    _redoStack.clear();
  }

  @override
  String toString() {
    final label = name != null ? '($name)' : '';
    return 'Epoch$label<$T>: ${peek()} '
        '[undo: $_undoCount, redo: ${_redoStack.length}]';
  }
}
