import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/booru_site.dart';
import '../../providers/booru_provider.dart';
import '../../providers/posts_provider.dart';
import 'booru_edit_screen.dart';

class BooruManageScreen extends StatelessWidget {
  const BooruManageScreen({super.key});

  void _showAddDialog(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(l10n.addBooru, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: Text(l10n.addFromPresets),
                subtitle: Text(l10n.addFromPresetsSub),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetsPicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(l10n.addManually),
                subtitle: Text(l10n.addManuallySub),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BooruEditScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_paste),
                title: Text(l10n.importFromClipboard),
                subtitle: Text(l10n.importFromClipboardSub),
                onTap: () {
                  Navigator.pop(ctx);
                  _importFromClipboard(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPresetsPicker(BuildContext context) {
    final l10n = context.l10n;
    final booruProv = context.read<BooruProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(l10n.addFromPresets, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: BooruSite.defaultPresets.length,
                    itemBuilder: (context, index) {
                      final preset = BooruSite.defaultPresets[index];
                      final alreadyAdded = booruProv.sites.any((s) => s.host == preset.host);
                      return ListTile(
                        title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${preset.host} • ${preset.typeName}'),
                        trailing: alreadyAdded
                            ? Chip(label: Text(l10n.activeSite, style: const TextStyle(fontSize: 11)))
                            : IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  booruProv.addSite(preset.copyWith(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  ));
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${l10n.add} ${preset.name}')),
                                  );
                                },
                              ),
                        onTap: alreadyAdded
                            ? null
                            : () {
                                booruProv.addSite(preset.copyWith(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                ));
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${l10n.add} ${preset.name}')),
                                );
                              },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _importFromClipboard(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final booruProv = context.read<BooruProvider>();
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    bool success = false;
    if (text.startsWith('booru://')) {
      success = await booruProv.importFromBooruUri(text);
    } else if (text.startsWith('[') || text.startsWith('{')) {
      success = await booruProv.importFromJson(text);
    }

    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importSuccess)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final booruProv = context.watch<BooruProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageBoorus),
        actions: [
          IconButton(
            tooltip: l10n.exportAllJson,
            icon: const Icon(Icons.share),
            onPressed: () {
              final json = booruProv.exportToJson();
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.copied)),
              );
            },
          ),
          IconButton(
            tooltip: l10n.resetPresets,
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.resetPresets),
                  content: Text(l10n.resetPresetsConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
                  ],
                ),
              );
              if (ok == true) {
                await booruProv.resetToPresets();
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: booruProv.sites.length,
        itemBuilder: (context, index) {
          final site = booruProv.sites[index];
          final isActive = site.id == booruProv.activeSite?.id;

          return Dismissible(
            key: Key(site.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.redAccent,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (booruProv.sites.length <= 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.cannotDeleteLastSite)),
                );
                return false;
              }
              return true;
            },
            onDismissed: (direction) {
              booruProv.deleteSite(site.id);
            },
            child: ListTile(
              leading: Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(site.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('${site.scheme}://${site.host} • ${site.typeName}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    tooltip: l10n.copyBooruUri,
                    onPressed: () {
                      final uri = site.toBooruUri();
                      Clipboard.setData(ClipboardData(text: uri));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.copied)),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.edit,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BooruEditScreen(existingSite: site),
                        ),
                      );
                    },
                  ),
                ],
              ),
              onTap: () {
                booruProv.setActiveSite(site);
                final postsProv = context.read<PostsProvider>();
                postsProv.fetchPosts(site: site, refresh: true);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addBooru,
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
