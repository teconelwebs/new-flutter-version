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

  factory HomeProduct.fromJson(Map<String, dynamic> json) => HomeProduct(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        price: (json['price'] ?? 0.0).toDouble(),
        mrp: (json['mrp'] ?? 0.0).toDouble(),
        image: json['image'] ?? '',
        slug: json['slug'] ?? '',
        duration: json['duration'] ?? 0,
        brand: json['brand'] ?? '',
        rating: (json['rating'] ?? 4.3).toDouble(),
      );

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
      };
}

class HomeCategorySection {
  const HomeCategorySection({
    required this.id,
    required this.name,
    required this.products,
  });

  final String id;
  final String name;
  final List<HomeProduct> products;

  factory HomeCategorySection.fromJson(Map<String, dynamic> json) =>
      HomeCategorySection(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        products: (json['products'] as List? ?? [])
            .map((e) => HomeProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'products': products.map((e) => e.toJson()).toList(),
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

  factory HomeBundle.fromJson(Map<String, dynamic> json) => HomeBundle(
        mobileSlider: (json['mobileSlider'] as List? ?? [])
            .map((e) => HomeBanner.fromJson(e as Map<String, dynamic>))
            .toList(),
        banner1: (json['banner1'] as List? ?? [])
            .map((e) => HomeBanner.fromJson(e as Map<String, dynamic>))
            .toList(),
        banner2: (json['banner2'] as List? ?? [])
            .map((e) => HomeBanner.fromJson(e as Map<String, dynamic>))
            .toList(),
        todayDeals: (json['todayDeals'] as List? ?? [])
            .map((e) => HomeProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        sections: (json['sections'] as List? ?? [])
            .map((e) => HomeCategorySection.fromJson(e as Map<String, dynamic>))
            .toList(),
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
