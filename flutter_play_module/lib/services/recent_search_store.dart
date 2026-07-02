import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/search_result.dart';

const _storageKey = 'recentUsernameSearch';

class RecentSearchStore {
  static Future<List<SearchUserHit>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => SearchUserHit.fromRecentJson(Map<String, dynamic>.from(e)))
          .where((u) => u.username.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<SearchUserHit> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items.map((e) => e.toRecentJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }

  static Future<void> addUser(SearchUserHit user) async {
    if (user.username.isEmpty) return;
    final current = await load();
    final updated = [
      user,
      ...current.where((u) => u.username != user.username),
    ].take(15).toList();
    await save(updated);
  }

  static Future<void> removeUsername(String username) async {
    final current = await load();
    await save(current.where((u) => u.username != username).toList());
  }

  static Future<void> clear() async {
    await save([]);
  }
}
