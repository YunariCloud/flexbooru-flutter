class Pool {
  final int id;
  final String name;
  final int postCount;
  final String description;
  final DateTime? createdAt;
  final String? creatorName;

  Pool({
    required this.id,
    required this.name,
    required this.postCount,
    this.description = '',
    this.createdAt,
    this.creatorName,
  });

  factory Pool.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['created_at'] != null) {
      if (json['created_at'] is int) {
        dt = DateTime.fromMillisecondsSinceEpoch((json['created_at'] as int) * 1000);
      } else {
        dt = DateTime.tryParse(json['created_at'].toString());
      }
    }
    return Pool(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      postCount: json['post_count'] as int? ?? json['count'] as int? ?? 0,
      description: json['description']?.toString() ?? '',
      createdAt: dt,
      creatorName: json['creator_name']?.toString() ?? json['user']?['name']?.toString(),
    );
  }
}

class Artist {
  final int id;
  final String name;
  final List<String> otherNames;
  final List<String> urls;

  Artist({
    required this.id,
    required this.name,
    this.otherNames = const [],
    this.urls = const [],
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) return val.split(RegExp(r'\s+'));
      return [];
    }

    return Artist(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      otherNames: parseList(json['other_names']),
      urls: parseList(json['urls'] ?? json['url_string']),
    );
  }
}
