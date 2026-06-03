class MetDepartment {
  final int id;
  final String name;

  const MetDepartment(this.id, this.name);
}

const metDepartments = [
  MetDepartment(1, "American Decorative Arts"),
  MetDepartment(3, "Ancient Near Eastern Art"),
  MetDepartment(4, "Arms and Armor"),
  MetDepartment(5, "Arts of Africa, Oceania, and the Americas"),
  MetDepartment(6, "Asian Art"),
  MetDepartment(7, "The Cloisters"),
  MetDepartment(8, "The Costume Institute"),
  MetDepartment(9, "Drawings and Prints"),
  MetDepartment(10, "Egyptian Art"),
  MetDepartment(11, "European Paintings"),
  MetDepartment(12, "European Sculpture and Decorative Arts"),
  MetDepartment(13, "Greek and Roman Art"),
  MetDepartment(14, "Islamic Art"),
  MetDepartment(15, "The Robert Lehman Collection"),
  MetDepartment(16, "The Libraries"),
  MetDepartment(17, "Medieval Art"),
  MetDepartment(18, "Musical Instruments"),
  MetDepartment(19, "Photographs"),
  MetDepartment(21, "Modern and Contemporary Art"),
];

class ArtworkSettings {
  final int numberOfArtworks;
  final List<int> departmentIds;
  final bool showAdditionalImages;
  final bool showExtraArtworkInfo;

  const ArtworkSettings({
    this.numberOfArtworks = 15,
    this.departmentIds = const [],
    this.showAdditionalImages = false,
    this.showExtraArtworkInfo = false,
  });

  factory ArtworkSettings.fromJson(Map<String, dynamic> json) {
    return ArtworkSettings(
      numberOfArtworks: json['number_of_artworks'] ?? 15,
      departmentIds: (json['department_ids'] as List? ?? [])
          .map((id) => id as int)
          .toList(),
      showAdditionalImages: json['show_additional_images'] ?? false,
      showExtraArtworkInfo: json['show_extra_artwork_info'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number_of_artworks': numberOfArtworks,
      'department_ids': departmentIds,
      'show_additional_images': showAdditionalImages,
      'show_extra_artwork_info': showExtraArtworkInfo,
    };
  }

  ArtworkSettings copyWith({
    int? numberOfArtworks,
    List<int>? departmentIds,
    bool? showAdditionalImages,
    bool? showExtraArtworkInfo,
  }) {
    return ArtworkSettings(
      numberOfArtworks: numberOfArtworks ?? this.numberOfArtworks,
      departmentIds: departmentIds ?? this.departmentIds,
      showAdditionalImages: showAdditionalImages ?? this.showAdditionalImages,
      showExtraArtworkInfo: showExtraArtworkInfo ?? this.showExtraArtworkInfo,
    );
  }
}
