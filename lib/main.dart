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

  runApp(const MaterialApp(home: ListScreen()));
}

// ==========================================
// EKRAN 1: LISTA ELEMENTÓW
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
      final List<Artwork> fetchedData = await ArtworkApiService.fetchArtworks();

      setState(() {
        _artworks = fetchedData;
      });

      await ArtworkLocalDatabase.saveArtworksToCache(fetchedData);

    } catch (e) {
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Metropolitan Museum of Art")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
        itemCount: _artworks.length,
        itemBuilder: (context, i) {
          final item = _artworks[i];

          return ListTile(
            leading: SizedBox(
              width: 50,
              height: 50,
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                errorWidget: (context, url, error) => const Icon(Icons.broken_image),
              )
                  : const Icon(Icons.image_not_supported),
            ),
            title: Text(item.title),
            subtitle: Text(item.artistDisplay),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (c) => DetailScreen(artwork: item),
            )),
          );
        },
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
    try {
      final String description = await ArtworkApiService.fetchArtworkDescription(widget.artwork.id);

      setState(() { _desc = description; });

      await box.put(widget.artwork.id, description);

    } catch (e) {
      final String? cachedDesc = box.get(widget.artwork.id);
      setState(() {
        if (cachedDesc != null) {
          _desc = "$cachedDesc\n\n(Data loaded from device cache)";
        } else {
          _desc = "Detailed information is not available offline for this object (has not been previously displayed).";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.artwork.title)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (widget.artwork.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.artwork.imageUrl,
                placeholder: (context, url) => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                errorWidget: (c, e, s) => const Icon(Icons.broken_image, size: 100),
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