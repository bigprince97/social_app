class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime createdAt;
  final String? region;
  final String? language;

  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    required this.createdAt,
    this.region,
    this.language,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        followersCount: (json['followers_count'] as int?) ?? 0,
        followingCount: (json['following_count'] as int?) ?? 0,
        postsCount: (json['posts_count'] as int?) ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        region: json['region'] as String?,
        language: json['language'] as String?,
      );

  Profile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    String? region,
    String? language,
  }) =>
      Profile(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount ?? this.followingCount,
        postsCount: postsCount ?? this.postsCount,
        createdAt: createdAt,
        region: region ?? this.region,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
      };
}
