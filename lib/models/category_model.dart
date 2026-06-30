import '../constants/api_constants.dart';

class CategoryModel {
  final int id;
  final String name;
  final String description;
  final String? image;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    this.image,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    String? imgUrl = json['image'];
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (!imgUrl.startsWith('http://') && !imgUrl.startsWith('https://')) {
        imgUrl = imgUrl.startsWith('/')
            ? '${ApiConstants.api}${imgUrl.substring(1)}'
            : '${ApiConstants.api}$imgUrl';
      }
    }
    return CategoryModel(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: imgUrl,
    );
  }
}
