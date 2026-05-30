class Artwork {
  final int id;
  final String title;
  final String artistDisplay;
  final String imageUrl;

  Artwork({
    required this.id,
    required this.title,
    required this.artistDisplay,
    required this.imageUrl,
  });

  factory Artwork.fromJson(Map<String, dynamic> json) {
    return Artwork(
      id: json['objectID'] ?? 0,
      title: json['title'] ?? 'Unknown title',
      artistDisplay: json['artistDisplayName'] ?? 'Unknown artist',
      imageUrl: json['primaryImageSmall'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_display': artistDisplay,
      'image_url': imageUrl,
    };
  }
}