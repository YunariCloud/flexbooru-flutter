import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/booru_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/post_grid_item.dart';
import '../../models/browse_session.dart';
import '../../models/booru_site.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favProv = context.watch<FavoritesProvider>();
    final booruProv = context.watch<BooruProvider>();
    final settingsProv = context.watch<SettingsProvider>();

    final screenWidth = MediaQuery.of(context).size.width;
    int columns = settingsProv.gridColumns;
    if (columns <= 0) {
      if (screenWidth > 800) {
        columns = 4;
      } else if (screenWidth > 500) {
        columns = 3;
      } else {
        columns = 2;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoritesCount(favProv.favorites.length)),
      ),
      body: favProv.favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noFavoritesYet,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              crossAxisCount: columns,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              itemCount: favProv.favorites.length,
              itemBuilder: (context, index) {
                final post = favProv.favorites[index];
                final site = booruProv.sites
                    .where((s) => s.id == post.booruId)
                    .firstOrNull;
                final fallback = BooruSite(
                  id: post.booruId,
                  name: l10n.isZh ? '已删除站点' : 'Removed site',
                  host: Uri.tryParse(post.sampleUrl)?.host ?? '',
                  type: -1,
                );
                return PostGridItem(
                  post: post,
                  site: site ?? fallback,
                  sourceBuilder: () => BrowseSource.fixed(
                    favProv.favorites
                        .map(
                          (p) => GalleryEntry(
                            p,
                            booruProv.sites
                                .where((s) => s.id == p.booruId)
                                .firstOrNull,
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
    );
  }
}
