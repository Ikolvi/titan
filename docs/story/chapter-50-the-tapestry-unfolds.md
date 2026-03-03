# Chapter L — The Tapestry Unfolds

*In which Kael discovers that the present is not stored — it is woven from every event that came before.*

---

The Elder Architect led Kael past the war room's shelves of Annals and Ledgers, past the Codex and the Quarry, to a loom the size of a wall. Threads of every color hung from its frame — amber for quest assignments, crimson for failures, silver for completions.

"We've been storing state," the Elder said, running a finger along a thread. "But state is a shadow. The *truth* is the sequence of things that happened. The Annals record it for auditors. But what if the events themselves *were* the state?"

"Event sourcing," Kael whispered.

"**Tapestry**," the Elder corrected. "Every thread is an event. Every pattern that emerges is a projection — a **Weave**. When a new thread is added, every Weave updates itself. When you want the truth at any point in time, you replay the threads."

---

## Weaving the First Pattern

A Tapestry is an append-only event store. A Weave is a reactive projection that folds events into state with a pure function.

```dart
class QuestPillar extends Pillar {
  late final store = tapestry<QuestEvent>(name: 'quests');

  /// Read model: total quests by status.
  late final statusCounts = store.weave<Map<String, int>>(
    name: 'status-counts',
    initial: {},
    fold: (counts, event) => switch (event) {
      QuestCreated() => {
        ...counts,
        'pending': (counts['pending'] ?? 0) + 1,
      },
      QuestCompleted() => {
        ...counts,
        'pending': (counts['pending'] ?? 0) - 1,
        'completed': (counts['completed'] ?? 0) + 1,
      },
      _ => counts,
    },
  );

  /// Write side: commands append events.
  void createQuest(String title) {
    store.append(
      QuestCreated(title: title),
      correlationId: 'quest-$title',
    );
  }
}
```

"One event stream, many read models," the Elder said. "The dashboard counts quests. The report tallies gold. The sync module tracks what changed. They all read from the same tapestry — they just weave different patterns."

---

## Multiple Weaves, One Truth

Each Weave folds the same events through its own lens. A `where` filter narrows which events it cares about.

```dart
// Read model 2: total gold earned (only from completions).
late final goldEarned = store.weave<int>(
  name: 'gold',
  initial: 0,
  fold: (total, event) => switch (event) {
    QuestCompleted(:final reward) => total + reward,
    _ => total,
  },
  where: (event) => event is QuestCompleted,
);

print(goldEarned.state.value); // Reactive — updates on every append.
```

"The gold Weave ignores quest creations entirely," Kael realized. "It only folds completions."

"Precisely. A Weave is a *question*. Different questions, same tapestry."

---

## Querying the Past

The raw event log supports temporal queries — find events by sequence range, time window, correlation, or predicate.

```dart
// What happened between sequences 10 and 50?
final recent = store.query(fromSequence: 10, toSequence: 50);

// What quests were created in the last hour?
final lastHour = store.query(
  after: DateTime.now().subtract(Duration(hours: 1)),
  where: (e) => e is QuestCreated,
);

// All events in a distributed transaction.
final related = store.query(correlationId: 'checkout-42');
```

---

## Replay and Compaction

When a Weave's fold function changes — say, after a bug fix — replay rebuilds all projections from scratch.

```dart
store.replay(); // Reset all weaves and re-fold all events.

// Trim old events to save memory (projections keep their state).
store.compact(1000); // Remove events with sequence ≤ 1000.
```

"The tapestry at 0.239 µs per append," the Elder noted. "Fast enough to weave a kingdom's history in real time."

---

*State is a snapshot. Events are the truth. When you store the truth, you can answer any question — even questions you haven't thought to ask yet.*

---

### Lexicon Entry

| Standard Term | Titan Name | Purpose |
|---|---|---|
| Event Store | **Tapestry** | Append-only event log with reactive projections |
| Event Envelope | **TapestryStrand** | Immutable wrapper: sequence, timestamp, correlationId, metadata |
| Projection | **TapestryWeave** | Reactive fold: `(state, event) → state` |
| Snapshot | **TapestryFrame** | Captured weave state at a sequence number |
| Store Status | **TapestryStatus** | `idle` · `appending` · `replaying` · `disposed` |
