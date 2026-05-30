import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artwork.dart';
import '../services/artwork_api_service.dart';
import '../services/artwork_local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox("artworks_cache");
  await Hive.openBox("favorites");
  await Hive.openBox("descriptions_cache");

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: ListScreen()),
  );
}

Future<void> addFavoriteAtEnd(
  Box box,
  int key,
  Map<String, dynamic> value,
) async {
  final entries = box.keys
      .where((existingKey) => existingKey != key)
      .map(
        (existingKey) =>
            MapEntry<dynamic, dynamic>(existingKey, box.get(existingKey)),
      )
      .toList();

  await box.clear();
  for (final entry in entries) {
    await box.put(entry.key, entry.value);
  }
  await box.put(key, value);
}

// ==========================================
// EKRAN 1: LISTA ELEMENTÓW + REFRESH
// ==========================================
class ListScreen extends StatefulWidget {
  const ListScreen({super.key});
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<Artwork> _artworks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint(
        "START: Downloading fresh data from the Metropolitan Museum API...",
      );

      final List<Artwork> fetchedData = await ArtworkApiService.fetchArtworks();

      if (!mounted) return;
      setState(() {
        _artworks = fetchedData;
      });

      await ArtworkLocalDatabase.saveArtworksToCache(fetchedData);

      debugPrint("SUCCESS: Data refreshed and saved in Hive!");
    } catch (e) {
      if (!mounted) return;
      if (!ArtworkLocalDatabase.isCacheEmpty()) {
        setState(() {
          _artworks = ArtworkLocalDatabase.getCachedArtworks();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No network. Offline cache loaded.")),
        );
      } else {
        setState(() {
          _error = "Error downloading data. No connection and cache.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // funkcja pomocnicza do przełączania ulubionych
  void _toggleFav(Artwork art) async {
    final box = Hive.box("favorites");
    final descBox = Hive.box("descriptions_cache");

    if (box.containsKey(art.id)) {
      box.delete(art.id);
    } else {
      final favoriteData = art.toJson();
      await addFavoriteAtEnd(box, art.id, favoriteData);

      try {
        final String description =
            descBox.get(art.id) ??
            await ArtworkApiService.fetchArtworkDescription(art.id);
        await descBox.put(art.id, description);
        await box.put(art.id, {
          ...favoriteData,
          'cached_description': description,
        });
      } catch (_) {}
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final favBox = Hive.box("favorites");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Metropolitan Museum of Art"),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const FavoritesScreen()),
            ).then((_) => setState(() {})),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height:
                        MediaQuery.sizeOf(context).height -
                        kToolbarHeight -
                        MediaQuery.paddingOf(context).top,
                    child: Center(child: Text(_error!)),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _artworks.length,
                itemBuilder: (context, i) {
                  final item = _artworks[i];
                  final bool isFav = favBox.containsKey(item.id);
                  return ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: item.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.broken_image),
                              )
                            : const Icon(Icons.image_not_supported, size: 35),
                      ),
                    ),

                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    trailing: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => _toggleFav(item),
                    ),

                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => DetailScreen(artwork: item),
                      ),
                    ).then((_) => setState(() {})),
                  );
                },
              ),
            ),
    );
  }
}

// ==========================================
// EKRAN 2: SZCZEGÓŁY ELEMENTU
// ==========================================
class DetailScreen extends StatefulWidget {
  final Artwork artwork;
  const DetailScreen({super.key, required this.artwork});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String _desc = "Loading details...";

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final box = Hive.box("descriptions_cache");
    final favBox = Hive.box("favorites");
    final String? cachedDesc =
        box.get(widget.artwork.id) ?? widget.artwork.cachedDescription;

    if (cachedDesc != null && cachedDesc.isNotEmpty) {
      setState(() {
        _desc = cachedDesc;
      });
      await box.put(widget.artwork.id, cachedDesc);
      if (favBox.containsKey(widget.artwork.id)) {
        await favBox.put(widget.artwork.id, {
          ...widget.artwork.toJson(),
          'cached_description': cachedDesc,
        });
      }
      return;
    }

    try {
      final String description =
          await ArtworkApiService.fetchArtworkDescription(widget.artwork.id);

      setState(() {
        _desc = description;
      });

      await box.put(widget.artwork.id, description);
      if (favBox.containsKey(widget.artwork.id)) {
        await favBox.put(widget.artwork.id, {
          ...widget.artwork.toJson(),
          'cached_description': description,
        });
      }
    } catch (e) {
      setState(() {
        _desc =
            "Detailed information is not available offline for this object (has not been previously displayed).";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final favBox = Hive.box("favorites");
    final bool isFav = favBox.containsKey(widget.artwork.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Details"),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : null,
            ),
            onPressed: () async {
              if (isFav) {
                await favBox.delete(widget.artwork.id);
              } else {
                final favoriteData = widget.artwork.toJson();
                if (_desc.isNotEmpty && _desc != "Loading details...") {
                  favoriteData['cached_description'] = _desc;
                }
                await addFavoriteAtEnd(favBox, widget.artwork.id, favoriteData);
              }
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.artwork.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.artwork.imageUrl,
                placeholder: (context, url) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (c, e, s) =>
                    const Icon(Icons.broken_image, size: 100),
              ),

            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.artwork.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Artist: ${widget.artwork.artistDisplay}",
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_desc, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// EKRAN 3: ULUBIONE
// ==========================================
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<void> _deleteFavorite(Box box, dynamic key) async {
    await box.delete(key);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reorderFavorites(Box box, int oldIndex, int newIndex) async {
    final entries = box.keys
        .map((key) => MapEntry<dynamic, dynamic>(key, box.get(key)))
        .toList();
    final movedEntry = entries.removeAt(oldIndex);
    entries.insert(newIndex, movedEntry);

    await box.clear();
    for (final entry in entries) {
      await box.put(entry.key, entry.value);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box("favorites");

    final favKeys = box.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Your Favorites Ranking:")),
      body: favKeys.isEmpty
          ? const Center(child: Text("No favorite artworks."))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favKeys.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorderFavorites(box, oldIndex, newIndex),
              itemBuilder: (context, i) {
                final key = favKeys[i];
                final item = Artwork.fromJson(
                  Map<String, dynamic>.from(box.get(key)),
                );
                return ReorderableDragStartListener(
                  key: ValueKey(key),
                  index: i,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              "${i + 1}.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: item.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.broken_image),
                                    )
                                  : const Icon(
                                      Icons.image_not_supported,
                                      size: 35,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () => _deleteFavorite(box, key),
                      ),
                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => DetailScreen(artwork: item),
                            ),
                          ).then((_) {
                            if (mounted) {
                              setState(() {});
                            }
                          }),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
