/// A hero that takes on quests.
class Hero {
  final String id;
  final String name;
  final String email;
  final HeroClass heroClass;
  final String bio;
  final int glory;
  final int questsCompleted;

  const Hero({
    required this.id,
    required this.name,
    required this.email,
    this.heroClass = HeroClass.scout,
    this.bio = '',
    this.glory = 0,
    this.questsCompleted = 0,
  });

  Hero copyWith({
    String? name,
    String? email,
    HeroClass? heroClass,
    String? bio,
    int? glory,
    int? questsCompleted,
  }) => Hero(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    heroClass: heroClass ?? this.heroClass,
    bio: bio ?? this.bio,
    glory: glory ?? this.glory,
    questsCompleted: questsCompleted ?? this.questsCompleted,
  );
}

/// Hero class archetypes.
enum HeroClass {
  scout('Scout'),
  sentinel('Sentinel'),
  builder('Builder'),
  oracle('Oracle');

  final String label;
  const HeroClass(this.label);
}
