import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../services/search_store.dart';
import '../../services/reverse_image_search.dart';

class ReverseSearchSettingsScreen extends StatefulWidget {
  const ReverseSearchSettingsScreen({super.key});
  @override
  State<ReverseSearchSettingsScreen> createState() =>
      _ReverseSearchSettingsScreenState();
}

class _ReverseSearchSettingsScreenState
    extends State<ReverseSearchSettingsScreen> {
  final store = SearchStore();
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zh = context.l10n.isZh;
    return Scaffold(
      appBar: AppBar(title: Text(zh ? '搜图引擎' : 'Image search engines')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final enabled = store.engineIds;
          final all = store.engineOrder;
          return ReorderableListView.builder(
            header: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                zh
                    ? '拖动调整顺序，至少启用一个引擎。'
                    : 'Drag to reorder. Keep at least one engine enabled.',
              ),
            ),
            itemCount: all.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final item = all.removeAt(oldIndex);
              all.insert(newIndex, item);
              await store.setEngines(
                all.where(enabled.contains).toList(),
                order: all,
              );
            },
            itemBuilder: (context, index) {
              final id = all[index];
              final engine = reverseImageEngines.firstWhere((e) => e.id == id);
              return SwitchListTile(
                key: ValueKey(id),
                title: Text(engine.name),
                value: enabled.contains(id),
                onChanged: (value) async {
                  if (!value && enabled.length == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          zh ? '至少启用一个引擎' : 'Keep at least one engine enabled',
                        ),
                      ),
                    );
                    return;
                  }
                  await store.setEngines(
                    all
                        .where(
                          (e) => value
                              ? enabled.contains(e) || e == id
                              : enabled.contains(e) && e != id,
                        )
                        .toList(),
                    order: all,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
