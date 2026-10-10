import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String tagLanguage; // 'zh' or 'en'
  final bool showCategoryDot;
  final EdgeInsetsGeometry? margin;

  const TagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onLongPress,
    this.tagLanguage = 'zh',
    this.showCategoryDot = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final hasTranslation = tag.translatedName != null &&
        tag.translatedName!.isNotEmpty &&
        tag.translatedName != tag.name;
    final isZh = tagLanguage == 'zh';

    final primaryText = (isZh && hasTranslation) ? tag.translatedName! : tag.name;
    final secondaryText = (isZh && hasTranslation) ? tag.name : null;

    final chipWidget = Material(
      color: tag.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress ??
            () {
              Clipboard.setData(ClipboardData(text: tag.name));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied "${tag.name}" to clipboard'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
        borderRadius: BorderRadius.circular(16),
        splashColor: tag.color.withValues(alpha: 0.25),
        highlightColor: tag.color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tag.color.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCategoryDot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: tag.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                primaryText,
                style: TextStyle(
                  color: tag.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (secondaryText != null) ...[
                const SizedBox(width: 4),
                Text(
                  secondaryText,
                  style: TextStyle(
                    color: tag.color.withValues(alpha: 0.65),
                    fontSize: 10,
                  ),
                ),
              ],
              if (tag.count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: tag.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag.count > 999999
                        ? '${(tag.count / 1000000).toStringAsFixed(1)}M'
                        : (tag.count > 999
                            ? '${(tag.count / 1000).toStringAsFixed(0)}k'
                            : '${tag.count}'),
                    style: TextStyle(
                      color: tag.color.withValues(alpha: 0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: chipWidget);
    }
    return chipWidget;
  }
}
