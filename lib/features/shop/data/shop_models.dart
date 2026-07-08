class ShopDetail {
  const ShopDetail({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.bannerUrl,
    required this.rating,
    required this.productCount,
  });

  final String id;
  final String name;
  final String logoUrl;
  final String bannerUrl;
  final String rating;
  final int productCount;

  factory ShopDetail.fromJson(
    Map<String, dynamic> json,
    String cdnBase,
    String defaultBanner,
    String defaultLogo,
  ) {
    String resolveUrl(dynamic raw, String fallback) {
      final s = (raw ?? '').toString().trim();
      if (s.isEmpty || s == 'null') return fallback;
      if (s.startsWith('http')) return s;
      final clean = s.startsWith('/') ? s.substring(1) : s;
      return '$cdnBase$clean';
    }

    return ShopDetail(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: resolveUrl(json['logo'], defaultLogo),
      bannerUrl: resolveUrl(json['sliders'], defaultBanner),
      rating: (json['rating'] ?? '0').toString(),
      productCount: int.tryParse((json['product'] ?? '0').toString()) ?? 0,
    );
  }
}

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    required this.newPrice,
    required this.oldPrice,
    required this.durationMinutes,
    required this.brand,
    required this.rating,
  });

  final String id;
  final String name;
  final String slug;
  final String imageUrl;
  final double newPrice;
  final double oldPrice;
  final int durationMinutes;
  final String brand;
  final String rating;

  static double _toDouble(dynamic val) =>
      val is num ? val.toDouble() : double.tryParse((val ?? '0').toString()) ?? 0;

  factory ShopProduct.fromJson(Map raw, String cdnBase, String defaultBanner) {
    String resolveUrl(dynamic rawPath) {
      final s = (rawPath ?? '').toString().trim();
      if (s.isEmpty || s == 'null') return defaultBanner;
      if (s.startsWith('http')) return s;
      final clean = s.startsWith('/') ? s.substring(1) : s;
      return '$cdnBase$clean';
    }

    return ShopProduct(
      id: (raw['id'] ?? '0').toString(),
      name: (raw['name'] ?? '').toString(),
      slug: (raw['slug'] ?? '').toString(),
      imageUrl: resolveUrl(raw['thumbnail_image'] ?? raw['thumbnail_img'] ?? raw['image']),
      newPrice: _toDouble(raw['base_discounted_price'] ?? raw['price']),
      oldPrice: _toDouble(raw['base_price'] ?? raw['mrp'] ?? raw['price']),
      durationMinutes: int.tryParse((raw['duration'] ?? '0').toString()) ?? 0,
      brand: (raw['brand'] ?? '').toString(),
      rating: (raw['rating'] ?? '0').toString(),
    );
  }
}

class ShopProductsResult {
  const ShopProductsResult({required this.products, required this.totalPages});
  final List<ShopProduct> products;
  final int totalPages;
}
