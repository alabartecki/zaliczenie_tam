import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artwork.dart';
import '../models/artwork_settings.dart';
import '../services/artwork_api_service.dart';
import '../services/artwork_local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox("artworks_cache");
  await Hive.openBox("favorites");
  await Hive.openBox("descriptions_cache");
  await Hive.openBox("settings");
  await Hive.openBox("trending_cache");

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: ListScreen()),
  );
}

const String favoriteRankKey = 'favorite_rank';
const String artworkSettingsKey = 'artwork_settings';

ArtworkSettings loadArtworkSettings() {
  final savedSettings = Hive.box("settings").get(artworkSettingsKey);
  if (savedSettings == null) {
    return const ArtworkSettings();
  }
  return ArtworkSettings.fromJson(Map<String, dynamic>.from(savedSettings));
}

Future<void> saveArtworkSettings(ArtworkSettings settings) async {
  await Hive.box("settings").put(artworkSettingsKey, settings.toJson());
}

List<dynamic> favoriteKeysInRankOrder(Box box) {
  final entries = box.keys.toList().asMap().entries.map((entry) {
    final value = Map<String, dynamic>.from(box.get(entry.value));
    final rank = value[favoriteRankKey];
    return (
      originalIndex: entry.key,
      key: entry.value,
      rank: rank is num ? rank.toInt() : entry.key,
    );
  }).toList();

  entries.sort((a, b) {
    final rankCompare = a.rank.compareTo(b.rank);
    if (rankCompare != 0) {
      return rankCompare;
    }
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return entries.map((entry) => entry.key).toList();
}

Future<void> addFavoriteAtEnd(
  Box box,
  int key,
  Map<String, dynamic> value,
) async {
  final keys = favoriteKeysInRankOrder(
    box,
  ).where((existingKey) => existingKey != key).toList();
  final favoriteData = Map<String, dynamic>.from(value);
  favoriteData[favoriteRankKey] = keys.length;
  await box.put(key, favoriteData);
}

Future<void> updateFavoriteData(
  Box box,
  int key,
  Map<String, dynamic> value,
) async {
  final currentValue = box.get(key);
  final mergedValue = {
    if (currentValue != null) ...Map<String, dynamic>.from(currentValue),
    ...value,
  };
  await box.put(key, mergedValue);
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

      final List<Artwork> fetchedData = await ArtworkApiService.fetchArtworks(
        settings: loadArtworkSettings(),
      );

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
        await updateFavoriteData(box, art.id, {
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
          IconButton(
            icon: const Icon(Icons.trending_up),
            tooltip: "Museum's Trending",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const TrendingScreen()),
            ).then((_) => setState(() {})),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const SettingsScreen()),
            ),
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
  String _selectedImageUrl = "";

  List<Widget> _additionalInfoWidgets(ArtworkSettings settings) {
    if (!settings.showExtraArtworkInfo) {
      return const [];
    }

    final rows = <String>[];

    if (widget.artwork.culture.isNotEmpty) {
      rows.add("Culture: ${widget.artwork.culture}");
    }
    if (widget.artwork.artistNationality.isNotEmpty) {
      rows.add("Artist nationality: ${widget.artwork.artistNationality}");
    }
    if (widget.artwork.artistGender.isNotEmpty) {
      rows.add("Artist gender: ${widget.artwork.artistGender}");
    }
    if (widget.artwork.city.isNotEmpty) {
      rows.add("City: ${widget.artwork.city}");
    }
    if (widget.artwork.classification.isNotEmpty) {
      rows.add("Classification: ${widget.artwork.classification}");
    }

    return rows
        .map(
          (row) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(row, style: const TextStyle(fontSize: 15)),
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedImageUrl = widget.artwork.imageUrl;
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
        await updateFavoriteData(favBox, widget.artwork.id, {
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
        await updateFavoriteData(favBox, widget.artwork.id, {
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
    final settings = loadArtworkSettings();

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
            if (_selectedImageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: _selectedImageUrl,
                placeholder: (context, url) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (c, e, s) =>
                    const Icon(Icons.broken_image, size: 100),
              ),
            if (settings.showAdditionalImages &&
                settings.showExtraArtworkInfo &&
                widget.artwork.additionalImageUrls.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.artwork.additionalImageUrls.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final url = index == 0
                        ? widget.artwork.imageUrl
                        : widget.artwork.additionalImageUrls[index - 1];
                    final isSelected = url == _selectedImageUrl;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImageUrl = url;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              isSelected ? 3 : 6),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 120,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                  ..._additionalInfoWidgets(settings),
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
// EKRAN 3: USTAWIENIA POBIERANIA
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ArtworkSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = loadArtworkSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _update(ArtworkSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await saveArtworkSettings(settings);
  }

  Future<void> _setExtraInfoEnabled(bool value) async {
    await _update(
      _settings.copyWith(
        showExtraArtworkInfo: value,
        showAdditionalImages: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Download settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Pick what you see. These settings change what gets downloaded on the next refresh.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Number of artworks",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Card(
            child: ListTile(
              title: Slider(
                min: 5,
                max: 50,
                divisions: 45,
                value: _settings.numberOfArtworks.toDouble(),
                label: _settings.numberOfArtworks.toString(),
                onChanged: (value) => _update(
                  _settings.copyWith(numberOfArtworks: value.round()),
                ),
              ),
              trailing: Text(
                _settings.numberOfArtworks.toString(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text("Department", style: Theme.of(context).textTheme.titleMedium),
          Card(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                _settings.departmentIds.isEmpty
                    ? "All departments"
                    : "${_settings.departmentIds.length} selected",
              ),
              children: metDepartments.map((department) {
                final selected = _settings.departmentIds.contains(
                  department.id,
                );
                return CheckboxListTile(
                  title: Text(department.name),
                  value: selected,
                  onChanged: (value) {
                    final departmentIds = [..._settings.departmentIds];
                    if (value == true) {
                      departmentIds.add(department.id);
                    } else {
                      departmentIds.remove(department.id);
                    }
                    _update(_settings.copyWith(departmentIds: departmentIds));
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Additional artwork info",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Show more artwork details"),
            subtitle: const Text(
              "Downloads and shows additional images and extra artwork metadata.",
            ),
            value: _settings.showExtraArtworkInfo,
            onChanged: _setExtraInfoEnabled,
          ),
          const SizedBox(height: 12),
          const Text("Changes apply on the next pull-to-refresh."),
        ],
      ),
    );
  }
}

// ==========================================
// EKRAN 4: ULUBIONE
// ==========================================
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> _favoriteKeys = [];

  @override
  void initState() {
    super.initState();
    _loadFavoriteKeys();
  }

  void _loadFavoriteKeys() {
    _favoriteKeys = favoriteKeysInRankOrder(Hive.box("favorites"));
  }

  Future<void> _deleteFavorite(Box box, dynamic key) async {
    await box.delete(key);
    if (mounted) {
      setState(() {
        _favoriteKeys.remove(key);
      });
    }
  }

  Future<void> _reorderFavorites(Box box, int oldIndex, int newIndex) async {
    setState(() {
      final movedKey = _favoriteKeys.removeAt(oldIndex);
      _favoriteKeys.insert(newIndex, movedKey);
    });

    for (var i = 0; i < _favoriteKeys.length; i++) {
      await updateFavoriteData(box, _favoriteKeys[i] as int, {
        favoriteRankKey: i,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box("favorites");

    return Scaffold(
      appBar: AppBar(title: const Text("Your Favorites Ranking:")),
      body: _favoriteKeys.isEmpty
          ? const Center(child: Text("No favorite artworks."))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              buildDefaultDragHandles: false,
              itemCount: _favoriteKeys.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorderFavorites(box, oldIndex, newIndex),
              itemBuilder: (context, i) {
                final key = _favoriteKeys[i];
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
                              setState(() {
                                _loadFavoriteKeys();
                              });
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

// ==========================================
// EKRAN 5: TOP 20 HIGHLIGHTED
// ==========================================
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});
  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  List<Artwork> _artworks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromCacheOrFetch();
  }


  Future<void> _loadFromCacheOrFetch() async {
    final cacheBox = Hive.box("trending_cache");
    final lastDate = cacheBox.get("last_fetch_date") as String?;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDate == today && !ArtworkLocalDatabase.isTrendingCacheEmpty()) {
      setState(() {
        _artworks = ArtworkLocalDatabase.getCachedTrending();
      });
      return;
    }

    await _fetch(saveDate: true);
  }


  Future<void> _fetch({bool saveDate = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint("START: Fetching today's top trending artworks...");

      final List<Artwork> fetchedData =
          await ArtworkApiService.fetchTrendingArtworks();

      if (!mounted) return;
      setState(() {
        _artworks = fetchedData;
      });

      await ArtworkLocalDatabase.saveTrendingToCache(fetchedData);

      if (saveDate) {
        await Hive.box("trending_cache")
            .put("last_fetch_date", DateTime.now().toIso8601String().substring(0, 10));
      }

      debugPrint("SUCCESS: Trending artworks cached!");
    } catch (e) {
      if (!mounted) return;
      if (!ArtworkLocalDatabase.isTrendingCacheEmpty()) {
        setState(() {
          _artworks = ArtworkLocalDatabase.getCachedTrending();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No network. Offline cache loaded."),
          ),
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
        await updateFavoriteData(box, art.id, {
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
        title: const Text("Museum's Top Trending Artworks"),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? RefreshIndicator(
              onRefresh: () => _fetch(saveDate: true),
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
              onRefresh: () => _fetch(saveDate: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _artworks.length,
                itemBuilder: (context, i) {
                  final item = _artworks[i];
                  final bool isFav = favBox.containsKey(item.id);
                  return ListTile(
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
