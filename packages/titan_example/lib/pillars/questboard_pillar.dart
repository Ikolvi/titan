import 'package:titan_bastion/titan_bastion.dart';

import '../models/hero.dart';
import '../models/quest.dart';

// ---------------------------------------------------------------------------
// Herald Events — cross-Pillar communication
// ---------------------------------------------------------------------------

/// Emitted when a quest is completed.
class QuestCompletedEvent {
  final Quest quest;
  const QuestCompletedEvent(this.quest);
}

/// Emitted when the hero profile is updated.
class HeroUpdatedEvent {
  final Hero hero;
  const HeroUpdatedEvent(this.hero);
}

// ---------------------------------------------------------------------------
// Questboard Pillar — hero state, glory tracking, undo
// ---------------------------------------------------------------------------

/// The main Pillar for the Questboard app.
///
/// Demonstrates: Core, Derived, Epoch (undo/redo), watch (side effects),
/// Herald (events), Vigil (error capture), Chronicle (logging).
class QuestboardPillar extends Pillar {
  // --------------- Core State ---------------

  /// Hero name with undo/redo history (Epoch).
  late final heroName = epoch<String>('Kael', maxHistory: 20, name: 'heroName');

  /// Hero class selection.
  late final heroClass = core(HeroClass.scout, name: 'heroClass');

  /// Total glory earned.
  late final glory = core(0, name: 'glory');

  /// Number of quests completed.
  late final questsCompleted = core(0, name: 'questsCompleted');

  // --------------- Derived State ---------------

  /// The hero's current rank based on glory.
  late final rank = derived(() {
    final g = glory.value;
    if (g >= 500) return 'Titan';
    if (g >= 200) return 'Champion';
    if (g >= 50) return 'Warrior';
    return 'Novice';
  }, name: 'rank');

  /// Progress to next rank (0.0 – 1.0).
  late final rankProgress = derived(() {
    final g = glory.value;
    if (g >= 500) return 1.0;
    if (g >= 200) return (g - 200) / 300;
    if (g >= 50) return (g - 50) / 150;
    return g / 50;
  }, name: 'rankProgress');

  /// Full hero object composed from individual Cores.
  late final hero = derived(
    () => Hero(
      id: 'hero-1',
      name: heroName.value,
      email: '',
      heroClass: heroClass.value,
      glory: glory.value,
      questsCompleted: questsCompleted.value,
    ),
    name: 'hero',
  );

  // --------------- Lifecycle ---------------

  @override
  void onInit() {
    log.info('Questboard initialized. Welcome, ${heroName.value}!');

    // Listen for quest completion events from other Pillars
    listen<QuestCompletedEvent>((event) {
      _onQuestCompleted(event.quest);
    });

    // Watch glory changes to log rank milestones
    watch(() {
      final r = rank.value;
      log.info('Rank updated: $r (glory: ${glory.value})');
    });
  }

  // --------------- Strikes (Actions) ---------------

  /// Award glory for completing a quest.
  void _onQuestCompleted(Quest quest) {
    strike(() {
      glory.value += quest.gloryReward;
      questsCompleted.value++;
    });
    log.info('Quest completed: "${quest.title}" (+${quest.gloryReward} glory)');
  }

  /// Rename the hero (tracked in Epoch for undo/redo).
  void renameHero(String name) {
    if (name.trim().isEmpty) {
      captureError(
        ArgumentError('Hero name cannot be empty'),
        action: 'renameHero',
      );
      return;
    }
    heroName.value = name.trim();
    emit(HeroUpdatedEvent(hero.value));
  }

  /// Undo the last hero name change.
  void undoName() {
    if (heroName.canUndo) heroName.undo();
  }

  /// Redo the last hero name change.
  void redoName() {
    if (heroName.canRedo) heroName.redo();
  }

  /// Change hero class.
  void changeClass(HeroClass cls) {
    heroClass.value = cls;
    emit(HeroUpdatedEvent(hero.value));
    log.debug('Hero class changed to ${cls.label}');
  }
}
