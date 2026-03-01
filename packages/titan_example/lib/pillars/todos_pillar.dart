import 'package:titan_bastion/titan_bastion.dart';

/// A single todo item.
class Todo {
  final String id;
  final String title;
  final bool done;

  const Todo({required this.id, required this.title, this.done = false});

  Todo copyWith({String? title, bool? done}) =>
      Todo(id: id, title: title ?? this.title, done: done ?? this.done);
}

/// Filter modes for the todo list.
enum TodoFilter { all, active, done }

/// Todos Pillar — manages a reactive todo list with filtering.
class TodosPillar extends Pillar {
  late final items = core<List<Todo>>([], name: 'items');
  late final filter = core(TodoFilter.all, name: 'filter');

  late final filtered = derived(() {
    final list = items.value;
    return switch (filter.value) {
      TodoFilter.all => list,
      TodoFilter.active => list.where((t) => !t.done).toList(),
      TodoFilter.done => list.where((t) => t.done).toList(),
    };
  }, name: 'filtered');

  late final remaining = derived(
    () => items.value.where((t) => !t.done).length,
    name: 'remaining',
  );

  void add(String title) => strike(() {
        items.value = [
          ...items.value,
          Todo(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
          ),
        ];
      });

  void toggle(String id) => strike(() {
        items.value = items.value
            .map((t) => t.id == id ? t.copyWith(done: !t.done) : t)
            .toList();
      });

  void remove(String id) => strike(() {
        items.value = items.value.where((t) => t.id != id).toList();
      });

  void clearDone() => strike(() {
        items.value = items.value.where((t) => !t.done).toList();
      });
}
