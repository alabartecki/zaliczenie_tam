import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';

class ArtworkApiService {
  static const String baseUrl = "https://api.artic.edu/api/v1";

  /// pobranie listy dzieł sztuki- glowny ekran
  static Future<List<Artwork>> fetchArtworks() async {
    //filtrowanie
    final url = Uri.parse("$baseUrl/artworks?fields=id,title,artist_display,image_id&limit=15");

    final response = await http.get(url).timeout(const Duration(seconds: 7));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List artworksList = data["data"];

      return artworksList.map((item) => Artwork.fromJson(item)).toList();
    } else {
      throw Exception("Nie udało się pobrać listy dzieł sztuki (Kod: ${response.statusCode})");
    }
  }

  /// pobranie szczegółowego opisu na żądanie- ekran szczegółów
  static Future<String> fetchArtworkDescription(int artworkId) async {
    final url = Uri.parse("$baseUrl/artworks/$artworkId?fields=description");

    final response = await http.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final artworkData = data["data"];

      if (artworkData != null && artworkData["description"] != null) {
        final String rawDescription = artworkData["description"];

        return rawDescription.replaceAll(RegExp(r'<[^>]*>'), '');
      }

      return "Brak szczegółowego opisu dla tego dzieła w bazie muzeum.";
    } else {
      throw Exception("Nie udało się pobrać opisu dzieła (Kod: ${response.statusCode})");
    }
  }
}