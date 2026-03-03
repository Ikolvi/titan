# Chapter XLV: The Arbiter Judges

> *"When one source of truth became many, the application descended into chaos. The local database said one thing, the server said another, and the device in the other room said something else entirely. Data collided, overwrote itself, and users lost work. The Arbiter rose to bring order — not by silencing the voices, but by hearing all of them and rendering a fair judgment."*

---

## The Problem

Questboard had grown. Heroes could work offline on their mobile devices, sync with the server when connectivity returned, and collaborate with teammates in real time via WebSocket. Three sources, each with its own version of the truth.

"It works fine until it doesn't," Kael muttered, staring at a bug report. A hero had completed a quest offline, but the server had already reassigned it. When the devices synced, the hero's progress vanished — overwritten by the server's version.

"I can track which version is 'newer'," Kael began:

```dart
DateTime _localTimestamp = DateTime.now();
DateTime _serverTimestamp = DateTime.now();

void sync(Quest localVersion, Quest serverVersion) {
  if (serverVersion.updatedAt.isAfter(localVersion.updatedAt)) {
    // Server wins... but what if the user made important changes?
  } else {
    // Local wins... but what if the server has critical updates?
  }
}
```

"That's last-write-wins with no visibility," Lyra said. "No conflict history, no merge option, no way to let users choose. And none of it is reactive."

She held up a medallion inscribed with scales of justice. "You need the **Arbiter**."

---

## The Arbiter Appears

```dart
class SyncPillar extends Pillar {
  late final questSync = arbiter<Quest>(
    strategy: ArbiterStrategy.lastWriteWins,
  );

  void receiveFromServer(Quest remote) {
    questSync.submit('server', remote);
  }

  void saveLocally(Quest local) {
    questSync.submit('local', local);
  }
}
```

"Submit values from any number of sources," Lyra explained. "When two or more arrive, a conflict is detected. The Arbiter resolves it according to the strategy you choose."

---

## The Four Strategies

### Last Write Wins

```dart
late final sync = arbiter<String>(
  strategy: ArbiterStrategy.lastWriteWins,
);

sync.submit('local', 'old version', timestamp: yesterday);
sync.submit('server', 'new version', timestamp: today);

final result = sync.resolve();
print(result!.resolved);  // 'new version'
```

### First Write Wins

```dart
late final sync = arbiter<String>(
  strategy: ArbiterStrategy.firstWriteWins,
);

sync.submit('local', 'original', timestamp: yesterday);
sync.submit('server', 'overwrite', timestamp: today);

final result = sync.resolve();
print(result!.resolved);  // 'original'
```

### Merge

```dart
late final profileSync = arbiter<Map<String, dynamic>>(
  strategy: ArbiterStrategy.merge,
  merge: (candidates) {
    // Combine all fields — latest timestamp per key wins
    final merged = <String, dynamic>{};
    for (final c in candidates) {
      merged.addAll(c.value);
    }
    return merged;
  },
);
```

### Manual

```dart
late final manualSync = arbiter<String>(
  strategy: ArbiterStrategy.manual,
);

manualSync.submit('local', 'version A');
manualSync.submit('server', 'version B');

// resolve() returns null in manual mode
manualSync.resolve();  // null

// User picks the winner:
final result = manualSync.accept('local');
print(result!.resolved);  // 'version A'
```

---

## Reactive Conflict State

Every aspect of the conflict was observable:

```dart
// How many unresolved submissions exist?
questSync.conflictCount.value     // 2

// Is there an active conflict?
questSync.hasConflicts.value      // true

// Last resolution outcome
questSync.lastResolution.value    // ArbiterResolution<Quest>

// Lifetime total
questSync.totalResolved.value     // 7
```

"Now my UI can show a conflict indicator," Kael realized:

```dart
Vestige<SyncPillar>(
  builder: (context, pillar) {
    if (pillar.questSync.hasConflicts.value) {
      return ConflictBanner(
        candidates: pillar.questSync.pending,
        onAccept: (source) => pillar.questSync.accept(source),
      );
    }
    return const SizedBox.shrink();
  },
)
```

---

## Auto-Resolve

For high-frequency updates, manual resolution wasn't practical:

```dart
late final positionSync = arbiter<LatLng>(
  strategy: ArbiterStrategy.lastWriteWins,
  autoResolve: true,  // Resolve immediately on second submit
);

positionSync.submit('gps', currentLocation);
// Second submit triggers auto-resolution:
final result = positionSync.submit('network', networkLocation);
print(result!.resolved);  // Most recent wins, instantly
```

---

## Multi-Source Conflicts

The Arbiter handled any number of sources:

```dart
sync.submit('local',    v1, timestamp: DateTime(2024, 1, 1));
sync.submit('serverA',  v2, timestamp: DateTime(2024, 1, 3));
sync.submit('serverB',  v3, timestamp: DateTime(2024, 1, 2));

final result = sync.resolve();
// lastWriteWins → serverA (Jan 3 is latest)
print(result!.candidates.length);  // 3
```

---

## Resolution History

Every resolution was recorded for audit and debugging:

```dart
sync.submit('a', 'v1');
sync.submit('b', 'v2');
sync.resolve();

sync.submit('c', 'v3');
sync.submit('d', 'v4');
sync.resolve();

print(sync.history.length);       // 2
print(sync.totalResolved.value);  // 2
```

---

## The Incantation Scroll

```dart
// ─── Arbiter: Reactive Conflict Resolution ───

// 1. Define resolution strategy:
late final sync = arbiter<Quest>(
  strategy: ArbiterStrategy.lastWriteWins,  // or firstWriteWins, merge, manual
);

// 2. Submit from multiple sources:
sync.submit('local', localQuest);
sync.submit('server', serverQuest);
sync.submit('device2', otherQuest, timestamp: customTime);

// 3. Resolve:
final result = sync.resolve();   // Auto strategy
// — or —
final picked = sync.accept('local');  // Manual pick

// 4. Merge strategy:
late final merged = arbiter<Map<String, dynamic>>(
  strategy: ArbiterStrategy.merge,
  merge: (candidates) => combineMaps(candidates),
);

// 5. Auto-resolve on conflict:
late final fast = arbiter<LatLng>(
  strategy: ArbiterStrategy.lastWriteWins,
  autoResolve: true,
);

// 6. Reactive state:
sync.conflictCount.value     // int
sync.hasConflicts.value      // bool
sync.lastResolution.value    // ArbiterResolution<T>?
sync.totalResolved.value     // int

// 7. Inspect pending:
sync.pending                 // List<ArbiterConflict<T>>
sync.sources                 // List<String>
sync.history                 // List<ArbiterResolution<T>>

// 8. Reset / dispose:
sync.reset();
sync.dispose();
```

---

*The Arbiter brought justice to the Questboard's data wars. No more silent overwrites, no more lost progress, no more "whose version is this?" Every conflict was visible, every resolution was tracked, and every strategy — from simple last-write-wins to custom merge logic — was a single parameter away.*

*But as the Arbiter settled disputes between sources, Kael wondered about a deeper problem. The data flowing in was growing richer and more complex. Transforming it — parsing, validating, enriching, normalizing — required a pipeline that was just as observable and just as reactive as the data itself...*

---

| | |
|---|---|
| [← Chapter XLIV: The Warden Patrols](chapter-44-the-warden-patrols.md) | [Chapter XLVI →](chapter-46-tbd.md) |
