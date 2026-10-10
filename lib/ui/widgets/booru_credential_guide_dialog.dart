import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_credential_guide.dart';
import '../../models/booru_site.dart';

class BooruCredentialGuideDialog extends StatefulWidget {
  final BooruCredentialGuide initialGuide;

  const BooruCredentialGuideDialog({
    super.key,
    required this.initialGuide,
  });

  static Future<void> show(
    BuildContext context, {
    BooruSite? site,
    String? initialHost,
    int? initialType,
  }) async {
    BooruCredentialGuide guide;
    if (site != null) {
      guide = BooruCredentialGuide.forSite(site);
    } else {
      guide = BooruCredentialGuide.forHostOrType(
        initialHost ?? '',
        initialType ?? BooruType.danbooru,
      );
    }

    await showDialog(
      context: context,
      builder: (_) => BooruCredentialGuideDialog(initialGuide: guide),
    );
  }

  @override
  State<BooruCredentialGuideDialog> createState() =>
      _BooruCredentialGuideDialogState();
}

class _BooruCredentialGuideDialogState
    extends State<BooruCredentialGuideDialog> {
  late BooruCredentialGuide _currentGuide;

  @override
  void initState() {
    super.initState();
    _currentGuide = widget.initialGuide;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isZh = l10n.isZh;

    final presets = BooruCredentialGuide.presetGuides;
    final allGuides = <BooruCredentialGuide>[...presets];
    if (!presets.any((g) => g.id == _currentGuide.id)) {
      allGuides.insert(0, _currentGuide);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.credentialsGuide,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Site Switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Text(
                    '${l10n.selectSiteToViewGuide}:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        isExpanded: true,
                        value: _currentGuide.id,
                        items: allGuides.map((guide) {
                          return DropdownMenuItem(
                            value: guide.id,
                            child: Text(
                              '${guide.name} (${guide.host.isNotEmpty ? guide.host : BooruType.getTypeName(guide.type)})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() {
                            _currentGuide = allGuides.firstWhere((g) => g.id == id);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Site Title & Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentGuide.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentGuide.host.isNotEmpty)
                                Text(
                                  _currentGuide.host,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(theme, l10n),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Requirement Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.authRequirement,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentGuide.getRequirement(isZh),
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Input Mapping Card
                    Text(
                      isZh ? '表单字段填写说明' : 'Form Field Details',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Username field
                          ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.person_outline,
                                size: 18,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              _currentGuide.getUsernameLabel(isZh),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentGuide.getUsernameHint(isZh),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (_currentGuide.getUsernameWarning(isZh) != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentGuide.getUsernameWarning(isZh)!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Token field
                          ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Icon(
                                Icons.key_outlined,
                                size: 18,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            title: Text(
                              _currentGuide.getTokenLabel(isZh),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentGuide.getTokenHint(isZh),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (_currentGuide.getTokenWarning(isZh) != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentGuide.getTokenWarning(isZh)!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step-by-Step Instructions
                    Text(
                      l10n.howToObtain,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ..._currentGuide.getSteps(isZh).asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final stepText = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$idx',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stepText,
                                style: const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Optional Tip
                    if (_currentGuide.getTip(isZh) != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 18,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentGuide.getTip(isZh)!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  if (_currentGuide.directUrl != null) ...[
                    FilledButton.icon(
                      onPressed: () => _openUrl(_currentGuide.directUrl!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.openInBrowser),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: l10n.copyUrl,
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _currentGuide.directUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.copied)),
                        );
                      },
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, AppLocalizations l10n) {
    if (_currentGuide.isNoAuthNeeded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: Text(
          l10n.noAuthNeededBadge,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }

    if (_currentGuide.isAuthRequired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Text(
          l10n.recommendedBadge,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        l10n.optionalBadge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
