class Comment {
  final int id;
  final int postId;
  final String author;
  final String body;
  final DateTime? createdAt;
  final String? avatar;

  Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.body,
    this.createdAt,
    this.avatar,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['created_at'] != null) {
      if (json['created_at'] is int) {
        dt = DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000);
      } else {
        dt = DateTime.tryParse(json['created_at'].toString());
      }
    }
    return Comment(
      id: json['id'] as int? ?? 0,
      postId: json['post_id'] as int? ?? 0,
      author: json['creator_name'] ?? json['author'] ?? json['user']?['name'] ?? 'Anonymous',
      body: json['body'] ?? json['content'] ?? '',
      createdAt: dt,
      avatar: json['creator_avatar'] ?? json['avatar'],
    );
  }
}
