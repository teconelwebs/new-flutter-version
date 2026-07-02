import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the same `x-device-id` key RN uses so share-link cold starts can call the API.
class DeviceIdStore {
  static const _key = 'x-device-id';

  static String? _memory;
  static Future<String>? _inflight;

  /// Fire-and-forget warm-up while the Flutter engine boots.
  static void warm() {
    _inflight ??= getOrCreate();
  }

  /// Immediate id for API headers — never blocks on SharedPreferences.
  static String peekOrGenerate() {
    if (_memory != null && _memory!.isNotEmpty) return _memory!;
    final id = 'device_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
    _memory = id;
    _inflight ??= _persist(id);
    return id;
  }

  static Future<String> getOrCreate() {
    return _inflight ??= _load();
  }

  static Future<String> _load() async {
    if (_memory != null && _memory!.isNotEmpty) return _memory!;

    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_key)?.trim();
      if (id != null && id.isNotEmpty) {
        _memory = id;
        return id;
      }
    } catch (_) {
      // Fall through to generated id.
    }

    final generated = peekOrGenerate();
    await _persist(generated);
    return generated;
  }

  static Future<String> _persist(String id) async {
    _memory = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, id);
    } catch (_) {
      // In-memory id is still valid for this session.
    }
    return id;
  }

  static String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
