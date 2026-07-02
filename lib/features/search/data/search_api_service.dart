import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../product/data/models/product_item.dart';

class SearchApiService {
  static const String _mainApi = 'https://welfogapi.welfog.com/api/v2';
  static const String _secondApi = 'https://welfogapi.welfog.com/api';
  static const String _cdnBase = 'https://d1f02fefkbso7w.cloudfront.net/';

  Future<List<String>> autosuggest(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$_mainApi/autosuggest?search=$q');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic> ? decoded['payload'] : null;
    final list = payload is Map<String, dynamic> ? payload['suggestions'] : null;
    if (list is! List) return const [];
    return list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Future<List<ProductItem>> searchProducts(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getString('latitude') ?? '0';
    final lng = prefs.getString('longitude') ?? '0';

    final params = {
      'search': query.trim(),
      'latitude': lat,
      'longitude': lng,
      'page': '1',
      'limit': '20',
    };
    final uri = Uri.parse('$_mainApi/products/search').replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return const [];
    return data.whereType<Map>().map(_mapProduct).toList();
  }

  Future<List<SearchCategory>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final uri = Uri.parse('$_secondApi/nav_cat_data/');
    final response = await http.get(
      uri,
      headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final decoded = jsonDecode(response.body);
    final raw = decoded is Map<String, dynamic> ? decoded['categories'] : null;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final id = (e['id'] ?? '').toString();
      final name = (e['name'] ?? '').toString();
      final icon = (e['icon_url'] ?? '').toString();
      return SearchCategory(
        id: id,
        name: name,
        iconUrl: _asAbsolute(icon),
      );
    }).where((c) => c.id.isNotEmpty && c.name.isNotEmpty).toList();
  }

  ProductItem _mapProduct(Map item) {
    final id = (item['id'] ?? '').toString();
    final title = (item['name'] ?? '').toString();
    final brand = (item['brand'] ?? item['data']?['brand'] ?? '').toString();
    final imageRaw = (item['thumbnail_img'] ??
            item['thumbnail_image'] ??
            item['img'] ??
            item['image'] ??
            '')
        .toString();
    final priceRaw = item['final_price']?['sellPrice'] ?? item['new_price'] ?? item['price'] ?? 0;
    final slug = (item['slug'] ?? '').toString();
    final duration = int.tryParse((item['duration'] ?? '0').toString()) ?? 0;
    final price = _toDouble(priceRaw);
    return ProductItem(
      id: id,
      title: title,
      subtitle: brand.isEmpty ? 'Fast delivery' : brand,
      price: price,
      rating: 4.3,
      color: const Color(0xFFF1F5F9),
      imageUrl: _asAbsolute(imageRaw),
      slug: slug,
      brand: brand,
      durationMinutes: duration,
    );
  }

  String _asAbsolute(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$_cdnBase$clean';
  }

  double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse((val ?? '0').toString()) ?? 0;
  }
}

class SearchCategory {
  const SearchCategory({
    required this.id,
    required this.name,
    required this.iconUrl,
  });

  final String id;
  final String name;
  final String iconUrl;
}
