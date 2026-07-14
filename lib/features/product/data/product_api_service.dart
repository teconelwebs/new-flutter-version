import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/product_item.dart';

class ProductApiService {
  static const String _mainApi = 'https://welfogapi.welfog.com/api/v2';
  static const String _secondApi = 'https://welfogapi.welfog.com/api';
  static const String _cdnBase = 'https://d1f02fefkbso7w.cloudfront.net/';

  Future<ProductDetailData> fetchProductDetail({
    required String slugOrId,
    required String productId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getString('latitude') ?? '0';
    final lng = prefs.getString('longitude') ?? '0';

    final uri = Uri.parse('$_secondApi/product_details/$slugOrId').replace(
      queryParameters: {'pro_id': productId, 'latitude': lat, 'longitude': lng},
    );

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load product detail');
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! Map<String, dynamic>) {
      throw Exception('Product detail not found');
    }
    return ProductDetailData.fromJson(data, cdnBase: _cdnBase);
  }

  Future<ProductReviewBundle> fetchReviews(String productId) async {
    final uri = Uri.parse('$_mainApi/reviews/product_review/$productId');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return ProductReviewBundle.empty();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return ProductReviewBundle.empty();
    return ProductReviewBundle.fromJson(decoded);
  }

  Future<List<ProductItem>> fetchRelatedProducts(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getString('latitude') ?? '0';
    final lng = prefs.getString('longitude') ?? '0';
    final token = prefs.getString('access_token') ?? '';

    final uri = Uri.parse('$_mainApi/products/related/$productId').replace(
      queryParameters: {'id': productId, 'latitude': lat, 'longitude': lng},
    );

    final response = await http.get(
      uri,
      headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300)
      // ignore: curly_braces_in_flow_control_structures
      return const [];
    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((raw) {
          final id = (raw['id'] ?? '').toString();
          final name = (raw['name'] ?? '').toString();
          final brand = (raw['brand'] ?? raw['data']?['brand'] ?? '')
              .toString();
          final price = _toDouble(
            raw['main_price'] ??
                raw['final_price']?['sellPrice'] ??
                raw['new_price'] ??
                raw['unit_price'] ??
                raw['discount_price'] ??
                raw['base_price'] ??
                raw['price'] ??
                0,
          );
          final image = _asAbsolute(
            (raw['thumbnail_image'] ??
                    raw['thumbnail_img'] ??
                    raw['image'] ??
                    '')
                .toString(),
          );

          final videoLink = (raw['video_link'] ?? '').toString().trim();
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
            title: name,
            subtitle: brand.isEmpty ? 'Fast delivery' : brand,
            price: price,
            rating: _toDouble(raw['rating'] ?? 0),
            color: const Color(0xFFF8FAFC),
            imageUrl: image,
            slug: (raw['slug'] ?? '').toString(),
            brand: brand,
            durationMinutes:
                int.tryParse((raw['duration'] ?? '0').toString()) ?? 0,
            videoUrl: resolvedVideoUrl,
            videoLink: resolvedVideoLink,
          );
        })
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();
  }

  String _asAbsolute(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return '$_cdnBase$clean';
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse((val ?? '0').toString()) ?? 0;
  }
}

class ProductDetailData {
  const ProductDetailData({
    required this.id,
    required this.name,
    required this.slug,
    required this.brand,
    required this.sellPrice,
    required this.mrpPrice,
    required this.discountPercent,
    required this.rating,
    required this.description,
    required this.shortDescription,
    required this.images,
    required this.features,
    required this.stock,
    this.rawJson = const {},
    this.videoUrl,
    this.videoLink,
  });

  final String id;
  final String name;
  final String slug;
  final String brand;
  final double sellPrice;
  final double mrpPrice;
  final int discountPercent;
  final double rating;
  final String description;
  final String shortDescription;
  final List<String> images;
  final Map<String, String> features;
  final int stock;
  final Map<String, dynamic> rawJson;
  final String? videoUrl;
  final String? videoLink;

  factory ProductDetailData.fromJson(
    Map<String, dynamic> json, {
    required String cdnBase,
  }) {
    final fp = json['final_price'] is Map<String, dynamic>
        ? json['final_price'] as Map<String, dynamic>
        : <String, dynamic>{};

    final photosRaw = json['photos'];
    final images = <String>[];
    if (photosRaw is List) {
      for (final p in photosRaw) {
        final v = p is String ? p : (p is Map ? (p['url'] ?? p['uri']) : null);
        final path = (v ?? '').toString();
        if (path.isEmpty) continue;
        if (path.startsWith('http://') || path.startsWith('https://')) {
          images.add(path);
        } else {
          final clean = path.startsWith('/') ? path.substring(1) : path;
          images.add('$cdnBase$clean');
        }
      }
    }

    final featureMap = <String, String>{};
    final rawFeatures = json['pro_features'];
    if (rawFeatures is String && rawFeatures.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawFeatures);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            featureMap[entry.key.toString()] = entry.value.toString();
          }
        }
      } catch (_) {}
    } else if (rawFeatures is Map) {
      for (final entry in rawFeatures.entries) {
        featureMap[entry.key.toString()] = entry.value.toString();
      }
    }

    final rating = ProductApiService._toDouble(json['rating']);
    final sell = ProductApiService._toDouble(fp['sellPrice'] ?? json['price']);
    final mrp = ProductApiService._toDouble(fp['mrpPrice'] ?? sell);
    final discount = fp['discountPercentage'] is num
        ? (fp['discountPercentage'] as num).round()
        : (mrp > 0 ? (((mrp - sell) / mrp) * 100).round() : 0);

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

    return ProductDetailData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      brand:
          (json['brand_name'] ??
                  json['brandName'] ??
                  json['brand'] ??
                  json['product']?['brand'] ??
                  '')
              .toString(),
      sellPrice: sell,
      mrpPrice: mrp <= 0 ? sell : mrp,
      discountPercent: discount < 0 ? 0 : discount,
      rating: rating <= 0 ? 4.0 : rating,
      description: (json['description'] ?? '').toString(),
      shortDescription: (json['sdescription'] ?? '').toString(),
      images: images,
      features: featureMap,
      stock:
          int.tryParse(
            (json['stock'] ?? json['stocks']?[0]?['qty'] ?? '0').toString(),
          ) ??
          0,
      rawJson: json,
      videoUrl: resolvedVideoUrl,
      videoLink: resolvedVideoLink,
    );
  }
}

class ProductReviewBundle {
  const ProductReviewBundle({
    required this.totalReviews,
    required this.averageRating,
    required this.percentages,
    required this.reviews,
  });

  final int totalReviews;
  final double averageRating;
  final Map<int, int> percentages;
  final List<ProductReview> reviews;

  factory ProductReviewBundle.empty() => const ProductReviewBundle(
    totalReviews: 0,
    averageRating: 0,
    percentages: <int, int>{},
    reviews: <ProductReview>[],
  );

  factory ProductReviewBundle.fromJson(Map<String, dynamic> json) {
    final rp = json['review_percentages'] is Map<String, dynamic>
        ? json['review_percentages'] as Map<String, dynamic>
        : <String, dynamic>{};

    final percentages = <int, int>{
      5: (rp['five_star_percentage'] as num?)?.round() ?? 0,
      4: (rp['four_star_percentage'] as num?)?.round() ?? 0,
      3: (rp['three_star_percentage'] as num?)?.round() ?? 0,
      2: (rp['two_star_percentage'] as num?)?.round() ?? 0,
      1: (rp['one_star_percentage'] as num?)?.round() ?? 0,
    };

    final reviewsRaw = json['reviews'];
    final reviews = reviewsRaw is List
        ? reviewsRaw
              .whereType<Map>()
              .map((e) => ProductReview.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ProductReview>[];

    return ProductReviewBundle(
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? reviews.length,
      averageRating: ProductApiService._toDouble(json['rating'] ?? 0),
      percentages: percentages,
      reviews: reviews,
    );
  }
}

class ProductReview {
  const ProductReview({
    required this.userName,
    required this.comment,
    required this.rating,
    required this.dateText,
  });

  final String userName;
  final String comment;
  final int rating;
  final String dateText;

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    final createdAt = (json['created_at'] ?? '').toString();
    return ProductReview(
      userName: (json['user_name'] ?? 'User').toString(),
      comment: (json['comment'] ?? '').toString(),
      rating: ((json['rating'] as num?)?.round() ?? 0).clamp(0, 5),
      dateText: createdAt.isEmpty ? '' : createdAt.split('T').first,
    );
  }
}
