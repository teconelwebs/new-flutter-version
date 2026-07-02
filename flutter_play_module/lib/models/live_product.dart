import '../utils/cdn_url.dart';

class LiveProduct {
  final String id;
  final String name;
  final String? slug;
  final String thumbnailImg;
  final double mrpPrice;
  final double activePrice;

  LiveProduct({
    required this.id,
    required this.name,
    this.slug,
    required this.thumbnailImg,
    required this.mrpPrice,
    required this.activePrice,
  });

  factory LiveProduct.fromJson(Map<String, dynamic> json) {
    return LiveProduct(
      id: (json['id'] ?? json['pro_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      thumbnailImg: json['thumbnail_img']?.toString() ?? '',
      mrpPrice: _toDouble(json['mrp_price']),
      activePrice: _toDouble(json['active_price']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String get imageUrl => cdnImageUrl(thumbnailImg);
}