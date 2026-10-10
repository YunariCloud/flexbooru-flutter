import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/blacklist_provider.dart';
import '../../providers/posts_provider.dart';

class TagBlacklistScreen extends StatefulWidget {
  const TagBlacklistScreen({super.key});

  @override
  State<TagBlacklistScreen> createState() => _TagBlacklistScreenState();
}

class _TagBlacklistScreenState extends State<TagBlacklistScreen> {
  final TextEditingController _controller = TextEditingController();

  void _addTag() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      final prov = context.read<BlacklistProvider>();
      prov.addTag(text);
      _controller.clear();
      final postsProv = context.read<PostsProvider>();
      postsProv.setBlacklist(prov.blacklist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blacklistProv = context.watch<BlacklistProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tagBlacklist),
        actions: [
          if (blacklistProv.blacklist.isNotEmpty)
            IconButton(
              tooltip: l10n.clear,
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.clear),
                    content: Text(l10n.clearAllBlacklistConfirm),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.clear)),
                    ],
                  ),
                );
                if (confirm == true) {
                  blacklistProv.clearAll();
                  if (context.mounted) {
                    context.read<PostsProvider>().setBlacklist([]);
                  }
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: l10n.addTagBlacklist,
                      hintText: 'e.g. gore, comic, spoiler',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _addTag,
                  child: Text(l10n.add),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.blacklistExplanation,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: blacklistProv.blacklist.isEmpty
                ? Center(
                    child: Text(l10n.noBlacklistTags, style: const TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: blacklistProv.blacklist.length,
                    itemBuilder: (context, index) {
                      final tag = blacklistProv.blacklist[index];
                      return ListTile(
                        leading: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                        title: Text(tag, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            blacklistProv.removeTag(tag);
                            context.read<PostsProvider>().setBlacklist(blacklistProv.blacklist);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
