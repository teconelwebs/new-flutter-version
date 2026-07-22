import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../product/data/models/product_item.dart';

class SearchApiService {
  static const String _mainApi = 'https://welfogapi.welfog.com/api/v2';
  static const String _secondApi = 'https://welfogapi.welfog.com/api';
  static const String _cdnBase = 'https://d1f02fefkbso7w.cloudfront.net/';

  static final http.Client _client = http.Client();
  static String? _cachedLat;
  static String? _cachedLng;

  Future<List<String>> autosuggest(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$_mainApi/autosuggest?search=$q');
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic> ? decoded['payload'] : null;
    final list = payload is Map<String, dynamic> ? payload['suggestions'] : null;
    if (list is! List) return const [];
    return list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  Future<SearchResultPayload> searchProducts(
    String query, {
    String? categoryId,
    String? color,
    String? sortBy,
    int page = 1,
  }) async {
    if (_cachedLat == null || _cachedLng == null) {
      final prefs = await SharedPreferences.getInstance();
      _cachedLat = prefs.getString('latitude') ?? '0';
      _cachedLng = prefs.getString('longitude') ?? '0';
    }
    final lat = _cachedLat!;
    final lng = _cachedLng!;
    final trimmedQuery = query.trim();

    final params = <String, String>{
      if (categoryId != null && categoryId.trim().isNotEmpty && RegExp(r'^\d+$').hasMatch(categoryId.trim()))
        'categories': categoryId.trim()
      else if (trimmedQuery.isNotEmpty)
        'name': trimmedQuery,
      'latitude': lat,
      'longitude': lng,
      'page': page.toString(),
      'limit': '20',
    };

    if (color != null && color.trim().isNotEmpty) {
      var colorVal = color.trim();
      if (colorVal.startsWith('#')) {
        colorVal = colorVal.substring(1);
      }
      params['color'] = colorVal;
    }

    if (sortBy != null && sortBy.trim().isNotEmpty) {
      params['sort_key'] = sortBy.trim();
    }

    final uri = Uri.parse('$_mainApi/products/search').replace(queryParameters: params);
    final response = await _client.get(uri);
    
    List data = [];
    List colorsList = [];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawData = decoded['data'];
        if (rawData is List) {
          data = rawData;
        }
        final rawColors = decoded['colors'] ?? decoded['payload']?['colors'];
        if (rawColors is List) {
          colorsList = rawColors;
        }
      }
    }

    // Fallback: If 0 products found and we have a search query (not category), fetch general products
    final isCategorySearch = categoryId != null && categoryId.trim().isNotEmpty && RegExp(r'^\d+$').hasMatch(categoryId.trim());
    if (data.isEmpty && page == 1 && trimmedQuery.isNotEmpty && !isCategorySearch) {
      try {
        final fallbackParams = {
          'latitude': lat,
          'longitude': lng,
          'page': '1',
          'limit': '20',
        };
        final fallbackUri = Uri.parse('$_mainApi/products/search').replace(queryParameters: fallbackParams);
        final fallbackRes = await _client.get(fallbackUri);
        if (fallbackRes.statusCode >= 200 && fallbackRes.statusCode < 300) {
          final decoded = jsonDecode(fallbackRes.body);
          if (decoded is Map<String, dynamic>) {
            final rawData = decoded['data'];
            if (rawData is List) {
              data = rawData;
            }
            final rawColors = decoded['colors'] ?? decoded['payload']?['colors'];
            if (rawColors is List && colorsList.isEmpty) {
              colorsList = rawColors;
            }
          }
        }
      } catch (_) {}
    }

    if (data.isEmpty) {
      return SearchResultPayload(products: const [], colors: colorsList);
    }

    // Map to ProductItem
    final mappedProducts = data.whereType<Map>().map(_mapProduct).toList();

    // Perform sorting if specified
    if (sortBy != null && sortBy.trim().isNotEmpty) {
      mappedProducts.sort((a, b) {
        if (sortBy == 'price-asc') return a.price.compareTo(b.price);
        if (sortBy == 'price-desc') return b.price.compareTo(a.price);
        if (sortBy == 'newest') {
          final idA = int.tryParse(a.id) ?? 0;
          final idB = int.tryParse(b.id) ?? 0;
          return idB.compareTo(idA);
        }
        if (sortBy == 'oldest') {
          final idA = int.tryParse(a.id) ?? 0;
          final idB = int.tryParse(b.id) ?? 0;
          return idA.compareTo(idB);
        }
        return 0;
      });
    } else if (trimmedQuery.isNotEmpty && !isCategorySearch) {
      // Prioritize products containing search query
      final lowerQuery = trimmedQuery.toLowerCase();
      final matching = <ProductItem>[];
      final nonMatching = <ProductItem>[];

      for (var p in mappedProducts) {
        if (p.title.toLowerCase().contains(lowerQuery) || p.brand.toLowerCase().contains(lowerQuery)) {
          matching.add(p);
        } else {
          nonMatching.add(p);
        }
      }
      return SearchResultPayload(
        products: [...matching, ...nonMatching],
        colors: colorsList,
      );
    }

    return SearchResultPayload(products: mappedProducts, colors: colorsList);
  }

  Future<List<SearchCategory>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final uri = Uri.parse('$_secondApi/nav_cat_data/');
    final response = await _client.get(
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
    final priceRaw = item['main_price'] ??
        item['final_price']?['sellPrice'] ??
        item['new_price'] ??
        item['unit_price'] ??
        item['discount_price'] ??
        item['base_price'] ??
        item['price'] ??
        0;
    final slug = (item['slug'] ?? '').toString();
    final duration = int.tryParse((item['duration'] ?? '0').toString()) ?? 0;
    final price = _toDouble(priceRaw);

    final videoLink = (item['video_link'] ?? '').toString().trim();
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
      videoUrl: resolvedVideoUrl,
      videoLink: resolvedVideoLink,
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

class SearchResultPayload {
  const SearchResultPayload({
    required this.products,
    required this.colors,
  });

  final List<ProductItem> products;
  final List<dynamic> colors;
}

