import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AccountApiService {
  static const String _mainApi = 'https://welfogapi.welfog.com/api/v2';
  static const String _secondApi = 'https://welfogapi.welfog.com/api';
  static const String _fourthApi = 'https://api.welfog.com/api';

  Future<AccountUser?> fetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final userId = prefs.getString('user_id') ?? '';
    if (token.isEmpty || userId.isEmpty) return null;

    final uri = Uri.parse('$_mainApi/get-user-by-access_token');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': token, 'userId': userId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final ok = decoded['result'] == true;
    if (!ok) return null;
    return AccountUser(
      userId: userId,
      name: (decoded['name'] ?? '').toString(),
      phone: (decoded['phone'] ?? '').toString(),
      email: (decoded['email'] ?? '').toString(),
    );
  }

  Future<List<BlockedUser>> fetchBlockedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return [];

    final uri = Uri.parse('$_fourthApi/userblocks/blocked-users/$userId');
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) return [];
    final list = decoded['blockedUsers'];
    if (list is! List) return [];
    return list.map((json) => BlockedUser.fromJson(json)).toList();
  }

  Future<bool> unblockUser(String targetUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty || targetUserId.isEmpty) return false;

    final uri = Uri.parse('$_fourthApi/userblocks/unblock-user');
    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'unblockerId': userId,
        'targetUserId': targetUserId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final decoded = jsonDecode(response.body);
    return decoded is Map && decoded['success'] == true;
  }

  Future<bool> deleteAccount(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final token = prefs.getString('access_token') ?? '';
    if (userId.isEmpty || token.isEmpty) return false;

    final uri = Uri.parse('$_mainApi/user/delete');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId,
        'delete_reason': reason,
      }),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<bool> reactivateAccount(String phone) async {
    if (phone.isEmpty) return false;

    final uri = Uri.parse('$_mainApi/user/reactivate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<List<WishlistItem>> fetchWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final token = prefs.getString('access_token') ?? '';
    if (userId.isEmpty || token.isEmpty) return [];

    final uri = Uri.parse('$_mainApi/wishlists/$userId');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];
      final list = decoded['data'];
      if (list is! List) return [];
      final items = list.map((json) => WishlistItem.fromJson(json as Map<String, dynamic>)).toList();

      // Cache individual product wishlist states and compare IDs
      final compareMap = <String, String>{};
      // First reset all previous wishlist state flags to false
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('wishlist_state_')) {
          await prefs.setString(key, 'false');
        }
      }
      for (final item in items) {
        compareMap[item.product.id.toString()] = item.compareId.toString();
        await prefs.setString('wishlist_state_${item.product.id}', 'true');
      }
      await prefs.setString('wishlist_compare_map', jsonEncode(compareMap));
      await prefs.setString('wishlist_count', items.length.toString());

      return items;
    } catch (_) {
      return [];
    }
  }

  Future<bool> addWishlistItem(int productId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final token = prefs.getString('access_token') ?? '';
    if (userId.isEmpty || token.isEmpty) return false;

    final uri = Uri.parse('$_mainApi/wishlists-add-product').replace(
      queryParameters: {
        'product_id': productId.toString(),
        'user_id': userId,
        'islogin': 'true',
      },
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.setString('wishlist_state_$productId', 'true');
      // Refresh the list to fetch its new compare ID
      await fetchWishlist();
      return true;
    }
    return false;
  }

  Future<bool> removeWishlistItem(int productId, int compareId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final token = prefs.getString('access_token') ?? '';
    if (userId.isEmpty || token.isEmpty) return false;

    final uri = Uri.parse('$_mainApi/wishlists-remove-product').replace(
      queryParameters: {
        'product_id': productId.toString(),
        'user_id': userId,
        'compare_id': compareId.toString(),
      },
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.setString('wishlist_state_$productId', 'false');
      // Refresh wishlist
      await fetchWishlist();
      return true;
    }
    return false;
  }

  Future<bool> addToCart(int productId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return false;

    final uri = Uri.parse('$_secondApi/crux/addcart');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'delivery_time_minute': '',
        'product_id': productId,
        'quantity': 1,
        'temp_userId': '',
        'stockId': '1',
        'user_id': userId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['result'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFaqs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final uri = Uri.parse('$_mainApi/faqs');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['faqs'] is List) {
        return List<Map<String, dynamic>>.from(decoded['faqs']);
      }
    } catch (_) {}
    return [];
  }

  Future<bool> submitContactForm({
    required String name,
    required String email,
    required String phone,
    required String message,
  }) async {
    final uri = Uri.parse('$_secondApi/contact');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'message': message,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchPolicyPage(String slug) async {
    final uri = Uri.parse('$_mainApi/po_page/$slug?slug=$slug');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['Pagedata'] is Map) {
        return Map<String, dynamic>.from(decoded['Pagedata']);
      }
    } catch (_) {}
    return null;
  }
}

class AccountUser {
  const AccountUser({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String userId;
  final String name;
  final String phone;
  final String email;
}

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.username,
    required this.name,
    required this.profilePicture,
  });

  final String id;
  final String username;
  final String name;
  final String profilePicture;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: (json['_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      profilePicture: (json['profilePicture'] ?? '').toString(),
    );
  }
}

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.compareId,
    required this.product,
  });

  final int id;
  final int compareId;
  final WishlistProduct product;

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      compareId: int.tryParse(json['compare_id']?.toString() ?? '') ?? 0,
      product: WishlistProduct.fromJson(json['product'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class WishlistProduct {
  const WishlistProduct({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.basePrice,
    required this.thumbnailImage,
    required this.rating,
    required this.link,
    this.stock,
    this.quantity,
    this.isOutOfStock,
  });

  final int id;
  final String name;
  final String sellingPrice;
  final String basePrice;
  final String thumbnailImage;
  final String rating;
  final String link;
  final String? stock;
  final String? quantity;
  final bool? isOutOfStock;

  factory WishlistProduct.fromJson(Map<String, dynamic> json) {
    return WishlistProduct(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString(),
      sellingPrice: (json['selling_price'] ?? '').toString(),
      basePrice: (json['base_price'] ?? '').toString(),
      thumbnailImage: (json['thumbnail_image'] ?? '').toString(),
      rating: (json['rating'] ?? '0').toString(),
      link: (json['link'] ?? '').toString(),
      stock: json['stock']?.toString(),
      quantity: json['quantity']?.toString(),
      isOutOfStock: json['isOutOfStock'] as bool?,
    );
  }
}
