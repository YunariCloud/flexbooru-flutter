import 'package:flutter/material.dart';

/// Keep settings controls below their description on narrow screens.
class SettingsControlTile extends StatelessWidget {
  const SettingsControlTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.control,
    this.controlWidth,
    this.onTap,
  });

  final Widget leading, title, subtitle, control;
  final double? controlWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 600 ||
          (constraints.maxWidth < 900 &&
              MediaQuery.textScalerOf(context).scale(14) > 18);
      final action = SizedBox(
        width: controlWidth == null
            ? null
            : stacked
            ? double.infinity
            : controlWidth,
        child: control,
      );
      return ListTile(
        leading: leading,
        title: title,
        subtitle: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  subtitle,
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: action,
                    ),
                  ),
                ],
              )
            : subtitle,
        trailing: stacked ? null : action,
        onTap: onTap,
      );
    },
  );
}
