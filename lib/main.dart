import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/artwork.dart';
import '../services/artwork_api_service.dart';
import '../services/artwork_local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Hive.openBox("artworks_cache");
  await Hive.openBox("favorites");

  runApp(const MaterialApp(home: ListScreen()));
}

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
          const SnackBar(content: Text("Brak sieci. Załadowano cache offline.")),
        );
      } else {
        setState(() {
          _error = "Błąd pobierania danych. Brak połączenia i pamięci podręcznej.";
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Muzeum")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
        itemCount: _artworks.length,
        itemBuilder: (context, i) {
          final item = _artworks[i];
          return ListTile(
            title: Text(item.title),
            subtitle: Text(item.artistDisplay),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (c) => DetailScreen(id: item.id, title: item.title),
            )),
          );
        },
      ),
    );
  }
}

class DetailScreen extends StatefulWidget {
  final int id;
  final String title;
  const DetailScreen({super.key, required this.id, required this.title});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  String _desc = "Ładowanie opisu...";
  bool _isDetailLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final String description = await ArtworkApiService.fetchArtworkDescription(widget.id);
      setState(() {
        _desc = description;
      });
    } catch (e) {
      setState(() {
        _desc = "Opis niedostępny w trybie offline.";
      });
    } finally {
      setState(() => _isDetailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isDetailLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(child: Text(_desc, style: const TextStyle(fontSize: 16))),
      ),
    );
  }
}