class Artwork {
  final int id;
  final String title;
  final String artistDisplay;
  final String imageUrl;
  final String? cachedDescription;

  Artwork({
    required this.id,
    required this.title,
    required this.artistDisplay,
    required this.imageUrl,
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
    };

    if (cachedDescription != null && cachedDescription!.isNotEmpty) {
      json['cached_description'] = cachedDescription!;
    }

    return json;
  }
}
