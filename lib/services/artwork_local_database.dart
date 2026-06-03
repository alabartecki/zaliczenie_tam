import 'package:hive_flutter/hive_flutter.dart';
import '../models/artwork.dart';

class ArtworkLocalDatabase {

  static Box get _cacheBox => Hive.box("artworks_cache");

  static Box get _favoritesBox => Hive.box("favorites");

  /// zwraca listę artworków zapisaną w pamięci podręcznej
  static List<Artwork> getCachedArtworks() {
    return _cacheBox.values.map((item) {
      return Artwork.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  /// czyści stary cache i zapisuje nową pobraną listę z API
  static Future<void> saveArtworksToCache(List<Artwork> artworks) async {
    await _cacheBox.clear();
    for (final art in artworks) {
      await _cacheBox.put(art.id, art.toJson());
    }
  }

  /// sprawdza, czy cache jest pusty- pierwsze uruchomienie bez sieci
  static bool isCacheEmpty() {
    return _cacheBox.isEmpty;
  }

  // TRENDING

  /// zwraca listę trending artworków zapisaną w pamięci podręcznej
  static List<Artwork> getCachedTrending() {
    final box = Hive.box("trending_cache");
    return box.values.whereType<Map>().map((item) {
      return Artwork.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  /// czyści stary cache trending i zapisuje nową pobraną listę z API
  static Future<void> saveTrendingToCache(List<Artwork> artworks) async {
    final box = Hive.box("trending_cache");
    await box.clear();
    for (final art in artworks) {
      await box.put(art.id, art.toJson());
    }
  }

  /// sprawdza, czy cache trending jest pusty (pomija klucz daty)
  static bool isTrendingCacheEmpty() {
    return Hive.box("trending_cache")
        .values
        .whereType<Map>()
        .isEmpty;
  }

  /// czyszczenie pamięci podręcznej- z poziomu ekranu ustawień
  static Future<void> clearCache() async {
    await _cacheBox.clear();
  }

//ULUBIONE

  /// pobiera listę wszystkich ulubionych dzieł sztuki
  static List<Artwork> getFavoriteArtworks() {
    return _favoritesBox.values.map((item) {
      return Artwork.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  /// dodaje dzieło sztuki do ulubionych
  static Future<void> toggleFavorite(Artwork artwork) async {
    if (_favoritesBox.containsKey(artwork.id)) {
      await _favoritesBox.delete(artwork.id);
    } else {
      await _favoritesBox.put(artwork.id, artwork.toJson());
    }
  }

  /// sprawdza, czy konkretny artwork jest polubiony- dla ikony serca
  static bool isFavorite(int id) {
    return _favoritesBox.containsKey(id);
  }
}