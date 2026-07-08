import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'home_models.dart';

class HomeApiService {
  static const String _mainApi = 'https://welfogapi.welfog.com/api/v2';
  static const String _secondApi = 'https://welfogapi.welfog.com/api';
  static const String _cdnBase = 'https://d1f02fefkbso7w.cloudfront.net/';

  Future<HomeBundle> fetchHomeBundle() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getString('latitude') ?? '0';
    final lng = prefs.getString('longitude') ?? '0';
    final city = prefs.getString('city_name') ?? 'Jaipur';
    final pincode = prefs.getString('postal_code') ?? '302001';

    // Fetch all three endpoints in parallel
    final results = await Future.wait([
      _getJson('$_mainApi/bannerdata/'),
      _getJson('https://welfogapi.welfog.com/api/cat_wise_product_show?latitude=$lat&longitude=$lng&page=1'),
      _getJson('$_secondApi/today_deal?latitude=$lat&longitude=$lng&page=1&limit=10'),
    ]);

    final bannerRes = results[0];
    final catRes = results[1];
    final dealRes = results[2];

    final mobileSlider = _mapBannerList(bannerRes['mobile_slider']);
    final banner1 = _mapBannerList(bannerRes['banner1']);
    final banner2 = _mapBannerList(bannerRes['banner2']);

    final sections = _mapSections(catRes['data']);
    final todayDeals = _mapDealProducts(dealRes['products']);

    final bundle = HomeBundle(
      mobileSlider: mobileSlider,
      banner1: banner1,
      banner2: banner2,
      todayDeals: todayDeals,
      sections: sections,
      city: city,
      pincode: pincode,
    );

    try {
      await prefs.setString('cached_home_bundle_v2', jsonEncode(bundle.toJson()));
    } catch (e) {
      debugPrint("Failed to cache home bundle: $e");
    }

    return bundle;
  }

  Future<List<HomeProduct>> fetchTodayDealsPaged(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getString('latitude') ?? '0';
    final lng = prefs.getString('longitude') ?? '0';

    final response = await _getJson('$_secondApi/today_deal?latitude=$lat&longitude=$lng&page=$page&limit=10');
    return _mapDealProducts(response['products']);
  }

  Future<HomeBundle?> getCachedHomeBundle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_home_bundle_v2');
      if (cachedStr != null) {
        final decoded = jsonDecode(cachedStr);
        return HomeBundle.fromJson(decoded);
      }
    } catch (e) {
      debugPrint("Failed to load cached home bundle: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed: $url');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  List<HomeBanner> _mapBannerList(dynamic rawList) {
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((e) {
          final imageRaw =
              (e['image'] ?? e['banner_img'] ?? e['img'] ?? '').toString();
          if (imageRaw.isEmpty) return null;
          return HomeBanner(
            image: _asAbsoluteImage(imageRaw),
            link: (e['link'] ?? '').toString().trim().isEmpty
                ? null
                : (e['link']).toString(),
          );
        })
        .whereType<HomeBanner>()
        .toList();
  }

  List<HomeCategorySection> _mapSections(dynamic rawRows) {
    if (rawRows is! List) return const [];
    return rawRows.whereType<Map>().map((row) {
      final category = row['category'];
      final id = category is Map ? (category['id'] ?? '').toString() : '';
      final name =
          category is Map ? (category['name'] ?? 'Category').toString() : 'Category';
      final products = _mapCategoryProducts(row['products']);
      return HomeCategorySection(id: id, name: name, products: products);
    }).where((s) => s.products.isNotEmpty).toList();
  }

  List<HomeProduct> _mapCategoryProducts(dynamic rawList) {
    if (rawList is! List) return const [];
    return rawList.whereType<Map>().map((p) {
      final id = int.tryParse((p['id'] ?? '0').toString()) ?? 0;
      final name = (p['name'] ?? '').toString();
      final slug = (p['link'] ?? p['slug'] ?? '').toString();
      final image = _asAbsoluteImage((p['image'] ?? p['thumbnail_img'] ?? '').toString());
      final price = _toDouble(p['price']);
      final duration = int.tryParse((p['duration'] ?? '0').toString()) ?? 0;
      final brand = (p['brand'] ?? '').toString();
      return HomeProduct(
        id: id,
        name: name,
        price: price,
        mrp: price,
        image: image,
        slug: slug,
        duration: duration,
        brand: brand,
      );
    }).where((p) => p.id > 0 && p.name.isNotEmpty).toList();
  }

  List<HomeProduct> _mapDealProducts(dynamic rawList) {
    if (rawList is! List) return const [];
    return rawList.whereType<Map>().map((p) {
      final id = int.tryParse((p['id'] ?? '0').toString()) ?? 0;
      final name = (p['name'] ?? p['productname'] ?? '').toString();
      final slug = (p['slug'] ?? '').toString();
      final image = _asAbsoluteImage(
        (p['thumbnail_image'] ?? p['thumbnail_img'] ?? p['image'] ?? '').toString(),
      );
      final price = _toDouble(p['new_price'] ?? p['price']);
      final mrp = _toDouble(p['old_price'] ?? p['mrp'] ?? price);
      final duration = int.tryParse((p['duration'] ?? '0').toString()) ?? 0;
      final brand = (p['brand'] ?? '').toString();
      return HomeProduct(
        id: id,
        name: name,
        price: price,
        mrp: mrp,
        image: image,
        slug: slug,
        duration: duration,
        brand: brand,
      );
    }).where((p) => p.id > 0 && p.name.isNotEmpty).toList();
  }

  String _asAbsoluteImage(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$_cdnBase$clean';
  }

  double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse((val ?? '0').toString()) ?? 0;
  }
}
