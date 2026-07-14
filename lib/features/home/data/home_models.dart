class HomeBanner {
  const HomeBanner({
    required this.image,
    this.link,
  });

  final String image;
  final String? link;

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        image: json['image'] ?? '',
        link: json['link'],
      );

  Map<String, dynamic> toJson() => {
        'image': image,
        'link': link,
      };
}

class HomeProduct {
  const HomeProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.mrp,
    required this.image,
    required this.slug,
    required this.duration,
    this.brand = '',
    this.rating = 4.3,
    this.videoUrl,
    this.videoLink,
  });

  final int id;
  final String name;
  final double price;
  final double mrp;
  final String image;
  final String slug;
  final int duration;
  final String brand;
  final double rating;
  final String? videoUrl;
  final String? videoLink;

  factory HomeProduct.fromJson(Map<String, dynamic> json) {
    final videoLink = (json['video_link'] ?? '').toString().trim();
    String? resolvedVideoUrl;
    String? resolvedVideoLink;
    if (videoLink.isNotEmpty && videoLink != 'null') {
      resolvedVideoLink = videoLink;
      if (videoLink.startsWith('http')) {
        resolvedVideoUrl = videoLink;
      } else {
        resolvedVideoUrl =
            'https://d2plk5mvjwgdxq.cloudfront.net/videos/reels/$videoLink/master.m3u8';
      }
    }

    return HomeProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      mrp: (json['mrp'] ?? 0.0).toDouble(),
      image: json['image'] ?? '',
      slug: json['slug'] ?? '',
      duration: json['duration'] ?? 0,
      brand: json['brand'] ?? '',
      rating: (json['rating'] ?? 4.3).toDouble(),
      videoUrl: resolvedVideoUrl,
      videoLink: resolvedVideoLink,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'mrp': mrp,
        'image': image,
        'slug': slug,
        'duration': duration,
        'brand': brand,
        'rating': rating,
        'video_link': videoLink,
      };
}

class HomeCategorySection {
  const HomeCategorySection({
    required this.id,
    required this.name,
    required this.products,
    this.bannerData = const [],
  });

  final String id;
  final String name;
  final List<HomeProduct> products;
  final List<HomeBanner> bannerData;

  factory HomeCategorySection.fromJson(Map<String, dynamic> json) {
    final rawBanners = json['bannerData'];
    final List<HomeBanner> parsedBanners = (rawBanners is List)
        ? rawBanners
            .whereType<Map<String, dynamic>>()
            .map((e) => HomeBanner.fromJson(e))
            .toList()
        : const <HomeBanner>[];
    return HomeCategorySection(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      products: (json['products'] is List)
          ? (json['products'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => HomeProduct.fromJson(e))
              .toList()
          : const <HomeProduct>[],
      bannerData: parsedBanners,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'products': products.map((e) => e.toJson()).toList(),
        'bannerData': bannerData.map((e) => e.toJson()).toList(),
      };
}

class HomeBundle {
  const HomeBundle({
    required this.mobileSlider,
    required this.banner1,
    required this.banner2,
    required this.todayDeals,
    required this.sections,
    required this.city,
    required this.pincode,
  });

  final List<HomeBanner> mobileSlider;
  final List<HomeBanner> banner1;
  final List<HomeBanner> banner2;
  final List<HomeProduct> todayDeals;
  final List<HomeCategorySection> sections;
  final String city;
  final String pincode;

  static List<HomeBanner> _parseBanners(dynamic raw) => (raw is List)
      ? raw.whereType<Map<String, dynamic>>().map(HomeBanner.fromJson).toList()
      : const <HomeBanner>[];

  factory HomeBundle.fromJson(Map<String, dynamic> json) => HomeBundle(
        mobileSlider: _parseBanners(json['mobileSlider']),
        banner1: _parseBanners(json['banner1']),
        banner2: _parseBanners(json['banner2']),
        todayDeals: (json['todayDeals'] is List)
            ? (json['todayDeals'] as List)
                .whereType<Map<String, dynamic>>()
                .map(HomeProduct.fromJson)
                .toList()
            : const <HomeProduct>[],
        sections: (json['sections'] is List)
            ? (json['sections'] as List)
                .whereType<Map<String, dynamic>>()
                .map(HomeCategorySection.fromJson)
                .toList()
            : const <HomeCategorySection>[],
        city: json['city'] ?? '',
        pincode: json['pincode'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'mobileSlider': mobileSlider.map((e) => e.toJson()).toList(),
        'banner1': banner1.map((e) => e.toJson()).toList(),
        'banner2': banner2.map((e) => e.toJson()).toList(),
        'todayDeals': todayDeals.map((e) => e.toJson()).toList(),
        'sections': sections.map((e) => e.toJson()).toList(),
        'city': city,
        'pincode': pincode,
      };
}
