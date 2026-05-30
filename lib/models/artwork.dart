class Artwork {
  final int id;
  final String title;
  final String artistDisplay;
  final String imageId;

  Artwork({
    required this.id,
    required this.title,
    required this.artistDisplay,
    required this.imageId,
  });

  factory Artwork.fromJson(Map<String, dynamic> json) {
    return Artwork(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Nieznany tytuł',
      artistDisplay: json['artist_display'] ?? 'Nieznany artysta',
      imageId: json['image_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist_display': artistDisplay,
      'image_id': imageId,
    };
  }
}