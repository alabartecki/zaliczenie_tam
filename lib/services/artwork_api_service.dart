import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import '../models/artwork_settings.dart';

class ArtworkApiService {
  static const String _baseUrl =
      "https://collectionapi.metmuseum.org/public/collection/v1";

  static Future<List<Artwork>> fetchArtworks({
    ArtworkSettings settings = const ArtworkSettings(),
  }) async {
    final ids = await _fetchSearchIds(settings);
    final artworks = <Artwork>[];

    for (final id in ids) {
      final artwork = await _fetchArtwork(id, settings);
      if (artwork == null) {
        continue;
      }
      artworks.add(artwork);
      if (artworks.length >= settings.numberOfArtworks) {
        break;
      }
    }

    return artworks;
  }

  static Future<List<int>> _fetchSearchIds(ArtworkSettings settings) async {
    final departments = settings.departmentIds.isEmpty
        ? <int?>[null]
        : settings.departmentIds.map<int?>((id) => id).toList();
    final ids = <int>[];

    for (final departmentId in departments) {
      final url = _buildSearchUrl(settings, departmentId);
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to retrieve the list of artworks (Code: ${response.statusCode})",
        );
      }

      final data = jsonDecode(response.body);
      final objectIds = (data["objectIDs"] as List? ?? []).cast<int>();
      ids.addAll(objectIds);
    }

    return ids.toSet().take(settings.numberOfArtworks * 8).toList();
  }

  static Uri _buildSearchUrl(ArtworkSettings settings, int? departmentId) {
    final params = <String, String>{"q": "painting", "hasImages": "true"};

    if (departmentId != null) {
      params["departmentId"] = departmentId.toString();
    }

    return Uri.parse("$_baseUrl/search").replace(queryParameters: params);
  }

  static Future<Artwork?> _fetchArtwork(
    int id,
    ArtworkSettings settings,
  ) async {
    try {
      final url = Uri.parse("$_baseUrl/objects/$id");
      final response = await http.get(url).timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final imageUrl = (data["primaryImageSmall"] as String? ?? "").isNotEmpty
          ? data["primaryImageSmall"] as String
          : (data["primaryImage"] as String? ?? "");

      if (imageUrl.isEmpty) return null;

      final additionalImages =
          (settings.showExtraArtworkInfo || settings.showAdditionalImages)
          ? (data["additionalImages"] as List? ?? [])
                .whereType<String>()
                .toList()
          : <String>[];

      return Artwork(
        id: data["objectID"] as int,
        title: data["title"] as String? ?? "Unknown title",
        artistDisplay: (data["artistDisplayName"] as String? ?? "").isNotEmpty
            ? data["artistDisplayName"] as String
            : "Unknown artist",
        imageUrl: imageUrl,
        additionalImageUrls: additionalImages,
        culture: data["culture"] as String? ?? "",
        artistNationality: data["artistNationality"] as String? ?? "",
        artistGender: data["artistGender"] as String? ?? "",
        city: data["city"] as String? ?? "",
        classification: data["classification"] as String? ?? "",
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Artwork>> fetchTrendingArtworks({int limit = 20}) async {
    final url = Uri.parse("$_baseUrl/search").replace(queryParameters: {
      "q": "painting",
      "hasImages": "true",
      "isHighlight": "true",
    });

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to retrieve trending artworks (Code: ${response.statusCode})",
      );
    }

    final data = jsonDecode(response.body);
    final objectIds = (data["objectIDs"] as List? ?? []).cast<int>();
    final artworks = <Artwork>[];

    for (final id in objectIds) {
      final artwork = await _fetchArtwork(id, const ArtworkSettings());
      if (artwork == null) continue;
      artworks.add(artwork);
      if (artworks.length >= limit) break;
    }

    return artworks;
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

    throw Exception(
      "Could not get the description of the work (Code: ${response.statusCode})",
    );
  }
}
