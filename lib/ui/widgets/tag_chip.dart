import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/tag.dart';

class TagChip extends StatelessWidget {
  final Tag tag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
      child: Container(
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tag.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tag.color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tag.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tag.name,
              style: TextStyle(
                color: tag.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tag.count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${tag.count}',
                style: TextStyle(
                  color: tag.color.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
