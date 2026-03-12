/// A tale posted on the Tavern bulletin board.
///
/// Maps to a DummyJSON post — themed as a hero's tale
/// shared at the local tavern.
class Tale {
  final int id;
  final int userId;
  final String title;
  final String body;

  /// Tags from DummyJSON.
  final List<String> tags;

  /// View count.
  final int views;

  /// Author name — populated lazily from the users endpoint.
  String? authorName;

  Tale({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.tags = const [],
    this.views = 0,
    this.authorName,
  });

  /// Creates a [Tale] from a DummyJSON post JSON response.
  factory Tale.fromJson(Map<String, dynamic> json) => Tale(
    id: json['id'] as int,
    userId: json['userId'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    views: (json['views'] as num?)?.toInt() ?? 0,
  );

  /// Serializes to JSON for POST/PUT requests.
  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'userId': userId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tale && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A comment on a tavern tale — represents feedback from other heroes.
///
/// Maps to a DummyJSON comment.
class TaleComment {
  final int id;
  final int postId;
  final String body;
  final int likes;
  final String username;
  final String fullName;

  const TaleComment({
    required this.id,
    required this.postId,
    required this.body,
    this.likes = 0,
    this.username = '',
    this.fullName = '',
  });

  /// Creates a [TaleComment] from a DummyJSON comment JSON.
  factory TaleComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return TaleComment(
      id: json['id'] as int,
      postId: json['postId'] as int,
      body: json['body'] as String,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      username: user?['username'] as String? ?? '',
      fullName: user?['fullName'] as String? ?? '',
    );
  }
}

/// Author identity — a guild member who posts tales.
///
/// Maps to a DummyJSON user object.
class GuildMember {
  final int id;
  final String name;
  final String username;
  final String email;

  const GuildMember({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
  });

  /// Creates a [GuildMember] from a DummyJSON user JSON.
  factory GuildMember.fromJson(Map<String, dynamic> json) => GuildMember(
    id: json['id'] as int,
    name:
        '${json['firstName'] as String} ${json['lastName'] as String}',
    username: json['username'] as String,
    email: json['email'] as String,
  );
}
