import 'dart:convert';

import 'package:http/http.dart' as http;

class CategoryApiService {
  static const String _secondApi = 'https://welfogapi.welfog.com/api';
  static const String _cdnBase = 'https://d1f02fefkbso7w.cloudfront.net/';

  Future<CategoryBundle> fetchMainCategories() async {
    final uri = Uri.parse('$_secondApi/nav_cat_data/');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed nav_cat_data');
    }
    final decoded = jsonDecode(response.body);
    final raw = decoded is Map<String, dynamic> ? decoded['categories'] : null;
    final bannerImg = decoded is Map<String, dynamic>
        ? (decoded['banner_img'] ?? '').toString()
        : '';
    final bannerUrl = decoded is Map<String, dynamic>
        ? (decoded['banner_url'] ?? '').toString()
        : '';
    final categories = (raw is List)
        ? raw
            .whereType<Map>()
            .map(
              (e) => MainCategory(
                id: (e['id'] ?? '').toString(),
                name: (e['name'] ?? '').toString(),
                iconUrl: _asAbsolute((e['icon_url'] ?? '').toString()),
              ),
            )
            .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
            .toList()
        : <MainCategory>[];

    return CategoryBundle(
      categories: categories,
      bannerImage: _asAbsolute(bannerImg),
      bannerUrl: bannerUrl,
    );
  }

  Future<List<InnerSection>> fetchInnerSections(String mainCategoryId) async {
    final uri = Uri.parse(
      '$_secondApi/inner_categories?main_category_id=$mainCategoryId',
    );
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed inner_categories');
    }
    final decoded = jsonDecode(response.body);
    final raw = decoded is Map<String, dynamic> ? decoded['categories'] : null;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((sec) {
      final childrenRaw = sec['children'];
      final children = (childrenRaw is List)
          ? childrenRaw.whereType<Map>().map((c) {
              return InnerChild(
                id: (c['id'] ?? '').toString(),
                name: (c['name'] ?? '').toString(),
                imageUrl: _asAbsolute((c['img'] ?? '').toString()),
              );
            }).where((c) => c.id.isNotEmpty).toList()
          : <InnerChild>[];

      return InnerSection(
        id: (sec['id'] ?? '').toString(),
        name: (sec['name'] ?? '').toString(),
        children: children,
      );
    }).where((s) => s.children.isNotEmpty).toList();
  }

  String _asAbsolute(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$_cdnBase$clean';
  }
}

class CategoryBundle {
  const CategoryBundle({
    required this.categories,
    required this.bannerImage,
    required this.bannerUrl,
  });

  final List<MainCategory> categories;
  final String bannerImage;
  final String bannerUrl;
}

class MainCategory {
  const MainCategory({
    required this.id,
    required this.name,
    required this.iconUrl,
  });

  final String id;
  final String name;
  final String iconUrl;
}

class InnerSection {
  const InnerSection({
    required this.id,
    required this.name,
    required this.children,
  });

  final String id;
  final String name;
  final List<InnerChild> children;
}

class InnerChild {
  const InnerChild({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;
}
