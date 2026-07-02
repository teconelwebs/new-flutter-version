class HomeBanner {
  const HomeBanner({
    required this.image,
    this.link,
  });

  final String image;
  final String? link;
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
}
