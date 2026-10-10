import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class Tag {
  final String name;
  final int category;
  final int count;
  final String? translatedName;

  Tag({
    required this.name,
    this.category = TagCategory.general,
    this.count = 0,
    this.translatedName,
  });

  String get categoryName => TagCategory.getCategoryName(category);

  String displayName({String tagLanguage = 'zh'}) {
    if (tagLanguage == 'zh' && translatedName != null && translatedName!.isNotEmpty) {
      return translatedName!;
    }
    return name;
  }

  Tag copyWith({
    String? name,
    int? category,
    int? count,
    String? translatedName,
  }) {
    return Tag(
      name: name ?? this.name,
      category: category ?? this.category,
      count: count ?? this.count,
      translatedName: translatedName ?? this.translatedName,
    );
  }

  Color get color {
    switch (category) {
      case TagCategory.artist:
        return const Color(0xFFE53935); // Red / Coral
      case TagCategory.copyright:
        return const Color(0xFFAB47BC); // Purple / Violet
      case TagCategory.character:
        return const Color(0xFF43A047); // Green
      case TagCategory.circle:
      case TagCategory.studio:
        return const Color(0xFFFB8C00); // Orange
      case TagCategory.meta:
      case TagCategory.legacyMeta:
        return const Color(0xFF78909C); // Blue grey
      case TagCategory.faults:
        return const Color(0xFFD81B60); // Pink
      case TagCategory.general:
      default:
        return const Color(0xFF1E88E5); // Blue
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'count': count,
    if (translatedName != null) 'translatedName': translatedName,
  };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    name: json['name']?.toString() ?? '',
    category: json['category'] as int? ?? TagCategory.general,
    count: json['count'] as int? ?? 0,
    translatedName: json['translatedName']?.toString(),
  );
}
