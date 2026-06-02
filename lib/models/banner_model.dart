class BannerModel {
  final int id;
  final String image;
  final String title;
  final String description;

  BannerModel({
    required this.id,
    required this.image,
    required this.title,
    required this.description,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: int.parse(json['id'].toString()),
      image: json['image']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}