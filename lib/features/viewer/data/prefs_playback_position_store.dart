import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/playback_positions.dart';

/// Keeps playback positions as one JSON object in SharedPreferences.
final class PrefsPlaybackPositionStore implements PlaybackPositionStore {
  PrefsPlaybackPositionStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'playback_positions';

  final SharedPreferencesAsync _prefs;

  @override
  Future<Map<String, int>> load() async {
    final json = await _prefs.getString(_key);
    if (json == null) return {};
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      // Damaged: videos simply start from the beginning again.
      return {};
    }
    if (decoded is! Map<String, Object?>) return {};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (value is int) key: value,
    };
  }

  @override
  Future<void> save(Map<String, int> positions) =>
      _prefs.setString(_key, jsonEncode(positions));
}
