import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';

class ArtworkApiService {
  static const String _baseUrl = "https://collectionapi.metmuseum.org/public/collection/v1";

  static Future<List<Artwork>> fetchArtworks() async {
    final searchUrl = Uri.parse("$_baseUrl/search?q=painting&hasImages=true&isHighlight=true");
    final searchResponse = await http.get(searchUrl).timeout(const Duration(seconds: 10));

    if (searchResponse.statusCode != 200) {
      throw Exception("Failed to retrieve the list of artworks (Code: ${searchResponse.statusCode})");
    }

    final searchData = jsonDecode(searchResponse.body);
    final List<int> ids = (searchData["objectIDs"] as List).cast<int>().take(15).toList();

    final futures = ids.map((id) => _fetchArtwork(id));
    final results = await Future.wait(futures);

    return results.whereType<Artwork>().toList();
  }

  static Future<Artwork?> _fetchArtwork(int id) async {
    try {
      final url = Uri.parse("$_baseUrl/objects/$id");
      final response = await http.get(url).timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final imageUrl = (data["primaryImageSmall"] as String? ?? "").isNotEmpty
          ? data["primaryImageSmall"] as String
          : (data["primaryImage"] as String? ?? "");

      if (imageUrl.isEmpty) return null;

      return Artwork(
        id: data["objectID"] as int,
        title: data["title"] as String? ?? "Unknown title",
        artistDisplay: (data["artistDisplayName"] as String? ?? "").isNotEmpty
            ? data["artistDisplayName"] as String
            : "Unknown artist",
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> fetchArtworkDescription(int artworkId) async {
    final url = Uri.parse("$_baseUrl/objects/$artworkId");
    final response = await http.get(url).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final parts = <String>[];

      final desc = data["objectDescription"] as String? ?? "";
      if (desc.isNotEmpty) parts.add(desc);

      final credit = data["creditLine"] as String? ?? "";
      if (credit.isNotEmpty) parts.add("Collection: $credit");

      final medium = data["medium"] as String? ?? "";
      if (medium.isNotEmpty) parts.add("Technique: $medium");

      final dimensions = data["dimensions"] as String? ?? "";
      if (dimensions.isNotEmpty) parts.add("Dimensions: $dimensions");

      final period = data["period"] as String? ?? "";
      if (period.isNotEmpty) parts.add("Period: $period");

      return parts.isNotEmpty
          ? parts.join("\n\n")
          : "There is no detailed description for this artwork.";
    }

    throw Exception("Could not get the description of the work (Code: ${response.statusCode})");
  }
}
