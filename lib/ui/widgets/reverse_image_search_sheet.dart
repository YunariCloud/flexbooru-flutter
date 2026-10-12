import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../models/post.dart';
import '../../services/reverse_image_search.dart';
import '../../services/search_store.dart';
import '../screens/reverse_search_settings_screen.dart';

Future<void> showReverseImageSearch(BuildContext context, Post post) async {
  final zh = context.l10n.isZh;
  final image = reverseImageUrl(post);
  if (image == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(zh ? '没有可用于搜图的图片网址' : 'No image URL available')),
    );
    return;
  }
  final store = SearchStore();
  final failure = ValueNotifier<(String, Uri)?>(null);
  try {
    await store.ready;
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([store, failure]),
          builder: (context, _) {
            final engines = store.engineIds
                .map((id) => reverseImageEngines.firstWhere((e) => e.id == id))
                .toList();
            Future<void> open(ReverseImageEngine engine) async {
              final url = engine.searchUrl(image);
              try {
                if (await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                )) {
                  return;
                }
              } catch (_) {
                /* Offer a usable link. */
              }
              if (!sheetContext.mounted) return;
              failure.value = (engine.name, url);
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      zh ? '以图搜图' : 'Reverse image search',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(
                      zh
                          ? '向所选引擎发送图片网址。需要登录的图片可能无法检索。'
                          : 'Send the image URL to the selected service. Private images may be inaccessible.',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () async {
                        await Navigator.of(sheetContext).push(
                          MaterialPageRoute(
                            builder: (_) => const ReverseSearchSettingsScreen(),
                          ),
                        );
                        await store.reload();
                      },
                    ),
                  ),
                  if (failure.value != null)
                    ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(
                        zh
                            ? '无法打开 ${failure.value!.$1}'
                            : 'Cannot open ${failure.value!.$1}',
                      ),
                      trailing: TextButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: failure.value!.$2.toString()),
                        ),
                        child: Text(zh ? '复制链接' : 'Copy link'),
                      ),
                    ),
                  ...engines.map(
                    (engine) => ListTile(
                      leading: const Icon(Icons.travel_explore),
                      title: Text(engine.name),
                      onTap: () => open(engine),
                      trailing: IconButton(
                        tooltip: zh ? '复制搜索链接' : 'Copy search link',
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: engine.searchUrl(image).toString(),
                            ),
                          );
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(context.l10n.copied)),
                          );
                        },
                      ),
                    ),
                  ),
                  if (engines.length > 1)
                    ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: Text(
                        zh ? '使用全部已启用引擎' : 'Open all enabled engines',
                      ),
                      onTap: () async {
                        for (final engine in engines) {
                          await open(engine);
                          if (!sheetContext.mounted) break;
                        }
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  } finally {
    store.dispose();
    failure.dispose();
  }
}
