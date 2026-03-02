import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'package:titan_example/models/hero.dart';
import 'package:titan_example/models/quest.dart';
import 'package:titan_example/pillars/questboard_pillar.dart';

void main() {
  tearDown(() {
    Herald.reset();
    Vigil.reset();
    Titan.reset();
  });

  test('QuestboardPillar initializes with default hero state', () {
    final board = QuestboardPillar();
    board.initialize();

    expect(board.heroName.value, 'Kael');
    expect(board.heroClass.value, HeroClass.scout);
    expect(board.glory.value, 0);
    expect(board.questsCompleted.value, 0);
    expect(board.rank.value, 'Novice');
    expect(board.rankProgress.value, 0.0);

    board.dispose();
  });

  test('QuestboardPillar.renameHero updates name with Epoch history', () {
    final board = QuestboardPillar();
    board.initialize();

    board.renameHero('Atlas');
    expect(board.heroName.value, 'Atlas');
    expect(board.heroName.canUndo, true);

    board.undoName();
    expect(board.heroName.value, 'Kael');

    board.redoName();
    expect(board.heroName.value, 'Atlas');

    board.dispose();
  });

  test('QuestboardPillar awards glory on QuestCompletedEvent', () {
    final board = QuestboardPillar();
    board.initialize();

    Herald.emit(
      const QuestCompletedEvent(
        Quest(
          id: 'q1',
          title: 'Test Quest',
          description: 'A test quest',
          gloryReward: 25,
        ),
      ),
    );

    expect(board.glory.value, 25);
    expect(board.questsCompleted.value, 1);

    board.dispose();
  });
}
