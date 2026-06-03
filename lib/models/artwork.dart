class Artwork {
  final int id;
  final String title;
  final String artistDisplay;
  final String imageUrl;
  final List<String> additionalImageUrls;
  final String culture;
  final String artistNationality;
  final String artistGender;
  final String city;
  final String classification;
  final String? cachedDescription;

  Artwork({
    required this.id,
    required this.title,
    required this.artistDisplay,
    required this.imageUrl,
    this.additionalImageUrls = const [],
    this.culture = "",
    this.artistNationality = "",
    this.artistGender = "",
    this.city = "",
    this.classification = "",
    this.cachedDescription,
  });

  factory Artwork.fromJson(Map<String, dynamic> json) {
    return Artwork(
      id: json['objectID'] ?? json['id'] ?? 0,
      title: json['title'] ?? 'Unknown title',
      artistDisplay:
          json['artistDisplayName'] ??
          json['artist_display'] ??
          'Unknown artist',
      imageUrl:
          json['primaryImageSmall'] ??
          json['primaryImage'] ??
          json['image_url'] ??
          '',
      additionalImageUrls:
          (json['additionalImages'] as List? ??
                  json['additional_image_urls'] as List? ??
                  [])
              .whereType<String>()
              .toList(),
      culture: json['culture'] ?? '',
      artistNationality:
          json['artistNationality'] ?? json['artist_nationality'] ?? '',
      artistGender: json['artistGender'] ?? json['artist_gender'] ?? '',
      city: json['city'] ?? '',
      classification: json['classification'] ?? '',
      cachedDescription:
          json['cached_description'] ?? json['cached_desription'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'title': title,
      'artist_display': artistDisplay,
      'image_url': imageUrl,
      'additional_image_urls': additionalImageUrls,
      'culture': culture,
      'artist_nationality': artistNationality,
      'artist_gender': artistGender,
      'city': city,
      'classification': classification,
    };

    if (cachedDescription != null && cachedDescription!.isNotEmpty) {
      json['cached_description'] = cachedDescription!;
    }

    return json;
  }
}
