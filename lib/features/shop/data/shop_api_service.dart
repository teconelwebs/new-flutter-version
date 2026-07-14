import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'shop_models.dart';

class ShopApiService {
  static const _baseUrl = 'https://welfogapi.welfog.com/api/v2';
  static const _cdnBase = 'https://d1f02fefkbso7w.cloudfront.net/';

  /// Local defaults — remote `_nuxt/img/nobanner.*.png` URLs are dead (404).
  static const defaultBannerAsset = 'assets/images/shop_default_banner.png';
  static const defaultLogoAsset = 'assets/images/shop_default_logo.png';
  static const defaultProductImageAsset = 'assets/images/shop_default_banner.png';

  Future<ShopDetail?> fetchShopDetails({
    required String shopId,
    required String slug,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final uri = Uri.parse('$_baseUrl/shops/details/$shopId')
          .replace(queryParameters: {'slug': slug, 'id': shopId});

      debugPrint('🟢 [API REQ DETAILS] URL: $uri');
      debugPrint('🟢 [API REQ DETAILS] TOKEN EXIST: ${token.isNotEmpty}');

      final response = await http.get(uri, headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      debugPrint('🔵 [API RES DETAILS] STATUS CODE: ${response.statusCode}');
      debugPrint('🔵 [API RES DETAILS] BODY: ${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data is! List || data.isEmpty) return null;

      final detail = ShopDetail.fromJson(
        data[0] as Map<String, dynamic>,
        _cdnBase,
        defaultBannerAsset,
        defaultLogoAsset,
      );
      debugPrint('🎯 [PARSED DETAILS] BANNER URL: ${detail.bannerUrl}');
      return detail;
    } catch (e) {
      debugPrint('ShopApiService.fetchShopDetails error: $e');
      return null;
    }
  }

  Future<ShopProductsResult> fetchShopProducts({
    required String shopId,
    required String slug,
    int page = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final lat = prefs.getString('latitude') ?? '0';
      final lng = prefs.getString('longitude') ?? '0';

      final uri = Uri.parse('$_baseUrl/shops/products/all/$shopId').replace(
        queryParameters: {
          'slug': slug,
          'id': shopId,
          'latitude': lat,
          'longitude': lng,
          'page': '$page',
        },
      );

      debugPrint('🟢 [API REQ] URL: $uri');
      debugPrint('🟢 [API REQ] TOKEN EXIST: ${token.isNotEmpty}');

      final response = await http.get(uri, headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      debugPrint('🔵 [API RES] STATUS CODE: ${response.statusCode}');
      debugPrint('🔵 [API RES] BODY: ${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // ignore: prefer_const_constructors
        return ShopProductsResult(products: [], totalPages: 1);
      }

      final decoded = jsonDecode(response.body);
      final rawData = decoded['data'];
      final meta = decoded['meta'];

      final dynamic rawLastPage =
          (meta is Map ? meta['last_page'] : null) ?? decoded['last_page'];
      final totalPages = int.tryParse((rawLastPage ?? 1).toString()) ?? 1;

      dynamic resolvedList = rawData;
      if (rawData is Map) {
        if (rawData['data'] is List) {
          resolvedList = rawData['data'];
        } else if (rawData['products'] is List) {
          resolvedList = rawData['products'];
        }
      }

      final products = resolvedList is List
          ? resolvedList
              .whereType<Map>()
              .map((p) =>
                  ShopProduct.fromJson(p, _cdnBase, defaultProductImageAsset))
              .toList()
          : <ShopProduct>[];

      debugPrint(
          '🎯 [PARSED] PRODUCTS COUNT: ${products.length}, TOTAL PAGES: $totalPages');

      return ShopProductsResult(products: products, totalPages: totalPages);
    } catch (e) {
      debugPrint('ShopApiService.fetchShopProducts error: $e');
      // ignore: prefer_const_constructors
      return ShopProductsResult(products: [], totalPages: 1);
    }
  }
}
