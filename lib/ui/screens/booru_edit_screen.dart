import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_credential_guide.dart';
import '../../models/booru_site.dart';
import '../../providers/booru_provider.dart';
import '../widgets/booru_credential_guide_dialog.dart';

class BooruEditScreen extends StatefulWidget {
  final BooruSite? existingSite;

  const BooruEditScreen({super.key, this.existingSite});

  @override
  State<BooruEditScreen> createState() => _BooruEditScreenState();
}

class _BooruEditScreenState extends State<BooruEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _pathController;
  late TextEditingController _hashSaltController;
  late TextEditingController _userController;
  late TextEditingController _tokenController;

  String _scheme = 'https';
  int _type = BooruType.moebooru;

  @override
  void initState() {
    super.initState();
    final s = widget.existingSite;
    _nameController = TextEditingController(text: s?.name ?? '');
    _hostController = TextEditingController(text: s?.host ?? '');
    _pathController = TextEditingController(text: s?.path ?? '');
    _hashSaltController = TextEditingController(text: s?.hashSalt ?? '');
    _userController = TextEditingController(text: s?.username ?? '');
    _tokenController = TextEditingController(text: s?.token ?? '');
    _scheme = s?.scheme ?? 'https';
    _type = s?.type ?? BooruType.moebooru;

    _hostController.addListener(_onHostChanged);
  }

  void _onHostChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hostController.removeListener(_onHostChanged);
    _nameController.dispose();
    _hostController.dispose();
    _pathController.dispose();
    _hashSaltController.dispose();
    _userController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    var host = _hostController.text.trim();
    if (host.startsWith('https://')) {
      _scheme = 'https';
      host = host.replaceFirst('https://', '');
    } else if (host.startsWith('http://')) {
      _scheme = 'http';
      host = host.replaceFirst('http://', '');
    }
    if (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }

    final booruProv = context.read<BooruProvider>();

    if (widget.existingSite != null) {
      final updated = widget.existingSite!.copyWith(
        name: _nameController.text.trim(),
        scheme: _scheme,
        host: host,
        type: _type,
        path: _pathController.text.trim().isNotEmpty
            ? _pathController.text.trim()
            : null,
        hashSalt: _hashSaltController.text.trim(),
        username: _userController.text.trim(),
        token: _tokenController.text.trim(),
      );
      booruProv.updateSite(updated, original: widget.existingSite);
    } else {
      final newSite = BooruSite(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        scheme: _scheme,
        host: host,
        type: _type,
        path: _pathController.text.trim().isNotEmpty
            ? _pathController.text.trim()
            : null,
        hashSalt: _hashSaltController.text.trim(),
        username: _userController.text.trim().isNotEmpty
            ? _userController.text.trim()
            : null,
        token: _tokenController.text.trim().isNotEmpty
            ? _tokenController.text.trim()
            : null,
      );
      booruProv.addSite(newSite);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.existingSite != null;
    final guide = BooruCredentialGuide.forHostOrType(
      _hostController.text,
      _type,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editBooruTitle : l10n.addBooruTitle),
        actions: [
          IconButton(
            tooltip: l10n.credentialsGuide,
            icon: const Icon(Icons.help_outline),
            onPressed: () => BooruCredentialGuideDialog.show(
              context,
              initialHost: _hostController.text,
              initialType: _type,
            ),
          ),
          IconButton(
            tooltip: l10n.save,
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.booruName,
                hintText: 'e.g. My Anime Booru',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.booruName : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                DropdownButton<String>(
                  value: _scheme,
                  items: const [
                    DropdownMenuItem(value: 'https', child: Text('https://')),
                    DropdownMenuItem(value: 'http', child: Text('http://')),
                  ],
                  onChanged: (v) => setState(() => _scheme = v ?? 'https'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: l10n.hostDomain,
                      hintText: 'e.g. danbooru.donmai.us',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.hostDomain : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.booruEngineType,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: BooruType.danbooru,
                  child: Text(BooruType.getTypeName(BooruType.danbooru)),
                ),
                DropdownMenuItem(
                  value: BooruType.moebooru,
                  child: Text(BooruType.getTypeName(BooruType.moebooru)),
                ),
                DropdownMenuItem(
                  value: BooruType.gelbooru,
                  child: Text(BooruType.getTypeName(BooruType.gelbooru)),
                ),
                DropdownMenuItem(
                  value: BooruType.sankaku,
                  child: Text(BooruType.getTypeName(BooruType.sankaku)),
                ),
                DropdownMenuItem(
                  value: BooruType.shimmie,
                  child: Text(BooruType.getTypeName(BooruType.shimmie)),
                ),
                DropdownMenuItem(
                  value: BooruType.danbooru1,
                  child: Text(BooruType.getTypeName(BooruType.danbooru1)),
                ),
              ],
              onChanged: (v) => setState(() => _type = v ?? BooruType.moebooru),
            ),
            const SizedBox(height: 16),

            if (_type == BooruType.shimmie) ...[
              TextFormField(
                controller: _pathController,
                decoration: InputDecoration(
                  labelText: l10n.apiPathShimmie,
                  hintText: 'e.g. shimmie',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_type == BooruType.danbooru1) ...[
              TextFormField(
                controller: _hashSaltController,
                decoration: InputDecoration(
                  labelText: l10n.hashSalt,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.authOptional,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: Text(l10n.viewCredentialsGuide),
                  onPressed: () => BooruCredentialGuideDialog.show(
                    context,
                    initialHost: _hostController.text,
                    initialType: _type,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            _buildCredentialBanner(context, guide),
            const SizedBox(height: 16),

            TextFormField(
              controller: _userController,
              decoration: InputDecoration(
                labelText: guide.getUsernameLabel(l10n.isZh),
                hintText: guide.getUsernameHint(l10n.isZh),
                helperText: guide.getUsernameWarning(l10n.isZh),
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _tokenController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: guide.getTokenLabel(l10n.isZh),
                hintText: guide.getTokenHint(l10n.isZh),
                helperText: guide.getTokenWarning(l10n.isZh),
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.key_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? l10n.saveChanges : l10n.addBooru),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialBanner(
    BuildContext context,
    BooruCredentialGuide guide,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isZh = l10n.isZh;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${guide.name} ${l10n.credentialsGuide}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              _buildBadge(theme, l10n, guide),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            guide.getRequirement(isZh),
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 14),
                label: Text(l10n.viewCredentialsGuide),
                onPressed: () => BooruCredentialGuideDialog.show(
                  context,
                  initialHost: _hostController.text,
                  initialType: _type,
                ),
              ),
              if (guide.directUrl != null)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(l10n.openWebsiteCredentialsPage),
                  onPressed: () async {
                    final uri = Uri.tryParse(guide.directUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    ThemeData theme,
    AppLocalizations l10n,
    BooruCredentialGuide guide,
  ) {
    if (guide.isNoAuthNeeded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l10n.noAuthNeededBadge,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }
    if (guide.isAuthRequired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l10n.recommendedBadge,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        l10n.optionalBadge,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
