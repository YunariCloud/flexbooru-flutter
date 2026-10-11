import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/settings_provider.dart';

class ThemeColorDialog extends StatefulWidget {
  final SettingsProvider settingsProv;
  final AppLocalizations l10n;

  const ThemeColorDialog({
    super.key,
    required this.settingsProv,
    required this.l10n,
  });

  @override
  State<ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<ThemeColorDialog> {
  late bool _isGradient;
  late Color _startColor;
  late Color _endColor;
  late TextEditingController _startController;
  late TextEditingController _endController;
  String? _errorMessage;

  static const List<(String, Color, Color)> _gradientPresets = [
    ('极光紫粉', Color(0xFF7F00FF), Color(0xFFE100FF)),
    ('暮光霞红', Color(0xFFFF416C), Color(0xFFFF4B2B)),
    ('深海蔚蓝', Color(0xFF0052D4), Color(0xFF4364F7)),
    ('碧海青蓝', Color(0xFF00B4DB), Color(0xFF0083B0)),
    ('翡翠生机', Color(0xFF11998E), Color(0xFF38EF7D)),
    ('熔金暖阳', Color(0xFFF7971E), Color(0xFFFFD200)),
    ('赛博朋克', Color(0xFF8A2387), Color(0xFFE94057)),
    ('冰川幽蓝', Color(0xFF3A7BD5), Color(0xFF3A6073)),
    ('幻影粉紫', Color(0xFFF857A6), Color(0xFFFF5858)),
    ('钛金曜灰', Color(0xFF4B6CB7), Color(0xFF182848)),
  ];

  static const List<Color> _solidColors = [
    Color(0xFF3F51B5), // Indigo
    Color(0xFF2196F3), // Blue
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE53935), // Crimson
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFFA000), // Amber
    Color(0xFF00695C), // Deep Teal
  ];

  static const List<Color> _quickPalette = [
    Color(0xFFF44336),
    Color(0xFFFF5722),
    Color(0xFFFF9800),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF009688),
    Color(0xFF00BCD4),
    Color(0xFF2196F3),
    Color(0xFF3F51B5),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _isGradient = widget.settingsProv.useGradient;
    _startColor = widget.settingsProv.accentColor;
    _endColor = widget.settingsProv.gradientEndColor ?? _startColor;
    _startController = TextEditingController(text: _colorToHex(_startColor));
    _endController = TextEditingController(text: _colorToHex(_endColor));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  static String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static Color? _tryParseHex(String hex) {
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    if (clean.length == 8) {
      final v = int.tryParse(clean, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }

  void _applyCustom() {
    final start = _tryParseHex(_startController.text);
    if (start == null) {
      setState(() => _errorMessage = widget.l10n.invalidHexColor);
      return;
    }

    if (_isGradient) {
      final end = _tryParseHex(_endController.text);
      if (end == null) {
        setState(() => _errorMessage = widget.l10n.invalidHexColor);
        return;
      }
      widget.settingsProv.setGradientColor(start, end);
    } else {
      widget.settingsProv.setAccentColor(start);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.palette_outlined),
          const SizedBox(width: 8),
          Text(
            l10n.chooseThemeColor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
        child: DefaultTabController(
          length: 3,
          initialIndex: _isGradient ? 0 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.gradientPresets),
                  Tab(text: l10n.solidPresets),
                  Tab(text: l10n.customColors),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGradientTab(),
                    _buildSolidTab(),
                    _buildCustomTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildGradientTab() {
    final currentStart = widget.settingsProv.accentColor.toARGB32();
    final currentEnd =
        (widget.settingsProv.gradientEndColor ??
                widget.settingsProv.accentColor)
            .toARGB32();
    final isGradActive = widget.settingsProv.useGradient;

    return GridView.builder(
      itemCount: _gradientPresets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final (title, start, end) = _gradientPresets[index];
        final isSelected =
            isGradActive &&
            currentStart == start.toARGB32() &&
            currentEnd == end.toARGB32();

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.settingsProv.setGradientColor(start, end);
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: start.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check, color: Colors.white, size: 16),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSolidTab() {
    final currentSolid = widget.settingsProv.accentColor.toARGB32();
    final isSolidActive = !widget.settingsProv.useGradient;

    return Center(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: _solidColors.map((c) {
            final isSelected = isSolidActive && currentSolid == c.toARGB32();
            return GestureDetector(
              onTap: () {
                widget.settingsProv.setAccentColor(c);
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomTab() {
    final l10n = widget.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.enableGradient,
              style: const TextStyle(fontSize: 14),
            ),
            value: _isGradient,
            onChanged: (val) {
              setState(() {
                _isGradient = val;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 8),

          // Start Color Picker
          _buildColorInputRow(
            label: _isGradient ? l10n.startColor : l10n.accentColor,
            color: _startColor,
            controller: _startController,
            onColorChanged: (newColor) {
              setState(() {
                _startColor = newColor;
                _startController.text = _colorToHex(newColor);
                _errorMessage = null;
              });
            },
            onHexChanged: (val) {
              final parsed = _tryParseHex(val);
              if (parsed != null) {
                setState(() {
                  _startColor = parsed;
                  _errorMessage = null;
                });
              }
            },
          ),

          if (_isGradient) ...[
            const SizedBox(height: 12),
            // End Color Picker
            _buildColorInputRow(
              label: l10n.endColor,
              color: _endColor,
              controller: _endController,
              onColorChanged: (newColor) {
                setState(() {
                  _endColor = newColor;
                  _endController.text = _colorToHex(newColor);
                  _errorMessage = null;
                });
              },
              onHexChanged: (val) {
                final parsed = _tryParseHex(val);
                if (parsed != null) {
                  setState(() {
                    _endColor = parsed;
                    _errorMessage = null;
                  });
                }
              },
            ),
          ],

          const SizedBox(height: 14),

          // Live Preview Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.livePreview,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Site Pill preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: _isGradient
                            ? LinearGradient(colors: [_startColor, _endColor])
                            : null,
                        color: _isGradient ? null : _startColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _startColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Flexbooru',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // FAB preview
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: _isGradient
                            ? LinearGradient(colors: [_startColor, _endColor])
                            : null,
                        color: _isGradient ? null : _startColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _startColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _applyCustom,
              child: Text(l10n.applyColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorInputRow({
    required String label,
    required Color color,
    required TextEditingController controller,
    required void Function(Color) onColorChanged,
    required void Function(String) onHexChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: onHexChanged,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _quickPalette.map((c) {
            final isSel = c.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => onColorChanged(c),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSel
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
