/// A quest that heroes can claim and complete.
class Quest {
  final String id;
  final String title;
  final String description;
  final QuestDifficulty difficulty;
  final int gloryReward;
  final bool isCompleted;
  final String? claimedBy;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    this.difficulty = QuestDifficulty.novice,
    this.gloryReward = 10,
    this.isCompleted = false,
    this.claimedBy,
  });

  Quest copyWith({
    String? title,
    String? description,
    QuestDifficulty? difficulty,
    int? gloryReward,
    bool? isCompleted,
    String? claimedBy,
  }) => Quest(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    difficulty: difficulty ?? this.difficulty,
    gloryReward: gloryReward ?? this.gloryReward,
    isCompleted: isCompleted ?? this.isCompleted,
    claimedBy: claimedBy ?? this.claimedBy,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Quest && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Quest difficulty levels.
enum QuestDifficulty {
  novice('Novice', 10),
  warrior('Warrior', 25),
  champion('Champion', 50),
  titan('Titan', 100);

  final String label;
  final int baseGlory;
  const QuestDifficulty(this.label, this.baseGlory);
}
