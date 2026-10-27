import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../media/domain/media_source.dart';
import '../domain/app_settings.dart';

/// Keeps [AppSettings] in SharedPreferences.
final class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _sources = 'sources';
  static const _trashDays = 'trash_days';
  static const _oldAfterMonths = 'old_after_months';
  static const _freedBytes = 'freed_bytes';

  final SharedPreferencesAsync _prefs;

  @override
  Future<AppSettings> load() async {
    final sourcesJson = await _prefs.getString(_sources);
    final sources = sourcesJson == null
        ? const <MediaSource>[]
        : [
            for (final item in jsonDecode(sourcesJson) as List<Object?>)
              MediaSource.fromJson(item! as Map<String, Object?>),
          ];
    return AppSettings(
      sources: sources,
      trashDays:
          await _prefs.getInt(_trashDays) ?? AppSettings.defaultTrashDays,
      oldAfterMonths:
          await _prefs.getInt(_oldAfterMonths) ??
          AppSettings.defaultOldAfterMonths,
      freedBytes: await _prefs.getInt(_freedBytes) ?? 0,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(
      _sources,
      jsonEncode([for (final s in settings.sources) s.toJson()]),
    );
    await _prefs.setInt(_trashDays, settings.trashDays);
    await _prefs.setInt(_oldAfterMonths, settings.oldAfterMonths);
    await _prefs.setInt(_freedBytes, settings.freedBytes);
  }
}
