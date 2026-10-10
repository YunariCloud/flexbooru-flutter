import 'package:flutter/material.dart';
import '../core/utils/url_util.dart';
import 'tag.dart';

class Post {
  // Sankaku uses opaque string IDs; older engines still use integer IDs.
  final Object id;
  final String booruId;
  final int width;
  final int height;
  final int fileSize;
  final int score;
  final String rating;
  final String previewUrl;
  final String sampleUrl;
  final String originUrl;
  final String? source;
  final int? pixivId;
  final DateTime? createdAt;
  final List<Tag> tags;
  final String tagString;
  final String uploader;
  final Object? uploaderId;
  bool isFavored;

  Post({
    required this.id,
    required this.booruId,
    required this.width,
    required this.height,
    this.fileSize = 0,
    this.score = 0,
    required this.rating,
    required this.previewUrl,
    required this.sampleUrl,
    required this.originUrl,
    this.source,
    this.pixivId,
    this.createdAt,
    required this.tags,
    required this.tagString,
    this.uploader = '',
    this.uploaderId,
    this.isFavored = false,
  });

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1.0;
    return width / height;
  }

  bool get isVideo => UrlUtil.isVideo(originUrl) || UrlUtil.isVideo(sampleUrl);

  bool get isGif => UrlUtil.isGif(originUrl) || UrlUtil.isGif(sampleUrl);

  bool get isSafe {
    final r = rating.toLowerCase();
    return r == 's' || r == 'safe' || r == 'g' || r == 'general';
  }

  String get ratingDisplay {
    final r = rating.toLowerCase();
    switch (r) {
      case 'g':
      case 'general':
        return 'General';
      case 's':
      case 'safe':
        return 'Safe';
      case 'q':
      case 'questionable':
        return 'Questionable';
      case 'e':
      case 'explicit':
        return 'Explicit';
      default:
        return rating.toUpperCase();
    }
  }

  Color get ratingColor {
    final r = rating.toLowerCase();
    switch (r) {
      case 'g':
      case 'general':
      case 's':
      case 'safe':
        return Colors.green;
      case 'q':
      case 'questionable':
        return Colors.orange;
      case 'e':
      case 'explicit':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'booruId': booruId,
    'width': width,
    'height': height,
    'fileSize': fileSize,
    'score': score,
    'rating': rating,
    'previewUrl': previewUrl,
    'sampleUrl': sampleUrl,
    'originUrl': originUrl,
    'source': source,
    'pixivId': pixivId,
    'createdAt': createdAt?.toIso8601String(),
    'tags': tags.map((t) => t.toJson()).toList(),
    'tagString': tagString,
    'uploader': uploader,
    'uploaderId': uploaderId,
    'isFavored': isFavored,
  };

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] is String || json['id'] is int ? json['id'] as Object : 0,
    booruId: json['booruId']?.toString() ?? '',
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
    fileSize: json['fileSize'] as int? ?? 0,
    score: json['score'] as int? ?? 0,
    rating: json['rating']?.toString() ?? 's',
    previewUrl: json['previewUrl']?.toString() ?? '',
    sampleUrl: json['sampleUrl']?.toString() ?? '',
    originUrl: json['originUrl']?.toString() ?? '',
    source: json['source']?.toString(),
    pixivId: json['pixivId'] as int?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'])
        : null,
    tags:
        (json['tags'] as List<dynamic>?)
            ?.map((t) => Tag.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [],
    tagString: json['tagString']?.toString() ?? '',
    uploader: json['uploader']?.toString() ?? '',
    uploaderId: json['uploaderId'],
    isFavored: json['isFavored'] as bool? ?? false,
  );
}
