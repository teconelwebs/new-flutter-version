import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the same `x-device-id` key RN uses so share-link cold starts can call the API.
///
/// IMPORTANT: never persist a brand-new id before SharedPreferences has been
/// read — that used to overwrite a stable id on every early [peekOrGenerate]
/// call and registered multiple FCM tokens per user (iOS then showed N pushes).
class DeviceIdStore {
  static const _key = 'x-device-id';

  static String? _memory;
  /// In-process only — never written to prefs until [_load] confirms prefs empty.
  static String? _ephemeral;
  static Future<String>? _inflight;

  /// Fire-and-forget warm-up while the Flutter engine boots.
  static void warm() {
    _inflight ??= getOrCreate();
  }

  /// Immediate id for API headers — never blocks on SharedPreferences.
  /// Does **not** overwrite a persisted id.
  static String peekOrGenerate() {
    if (_memory != null && _memory!.isNotEmpty) return _memory!;
    if (_ephemeral != null && _ephemeral!.isNotEmpty) {
      _inflight ??= _load();
      return _ephemeral!;
    }
    _ephemeral =
        'device_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
    _inflight ??= _load();
    return _ephemeral!;
  }

  static Future<String> getOrCreate() {
    return _inflight ??= _load();
  }

  static Future<String> _load() async {
    if (_memory != null && _memory!.isNotEmpty) return _memory!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_key)?.trim();
      if (id != null && id.isNotEmpty) {
        _memory = id;
        _ephemeral = null;
        return id;
      }
    } catch (_) {
      // Fall through to generated id.
    }

    final generated = (_ephemeral != null && _ephemeral!.isNotEmpty)
        ? _ephemeral!
        : 'device_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
    _ephemeral = null;
    return _persist(generated);
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
