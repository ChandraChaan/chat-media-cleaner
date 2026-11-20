import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../media/domain/media_file.dart';
import '../../media/domain/media_type.dart';
import '../domain/places.dart';

/// Keeps favourites and recent files in SharedPreferences.
final class PrefsPlacesStore implements PlacesStore {
  PrefsPlacesStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _favourites = 'favourites';
  static const _recent = 'recent_files';

  final SharedPreferencesAsync _prefs;

  @override
  Future<Places> load() async {
    final favourites = await _prefs.getString(_favourites);
    final recent = await _prefs.getString(_recent);
    return Places(
      favourites: [
        if (favourites != null)
          for (final item in jsonDecode(favourites) as List<Object?>)
            fileFromJson(item! as Map<String, Object?>),
      ],
      recent: [
        if (recent != null)
          for (final item in jsonDecode(recent) as List<Object?>)
            if (item case final Map<String, Object?> map)
              RecentFile(
                file: fileFromJson(map['file']! as Map<String, Object?>),
                openedAt: DateTime.fromMillisecondsSinceEpoch(
                  map['openedAt']! as int,
                  isUtc: true,
                ),
              ),
      ],
    );
  }

  @override
  Future<void> save(Places places) async {
    await _prefs.setString(
      _favourites,
      jsonEncode([for (final f in places.favourites) fileToJson(f)]),
    );
    await _prefs.setString(
      _recent,
      jsonEncode([
        for (final r in places.recent)
          {
            'file': fileToJson(r.file),
            'openedAt': r.openedAt.millisecondsSinceEpoch,
          },
      ]),
    );
  }

  static Map<String, Object?> fileToJson(MediaFile f) => {
    'id': f.id,
    'sourceId': f.sourceId,
    'parentId': f.parentId,
    'name': f.name,
    'relativePath': f.relativePath,
    'size': f.size,
    'modified': f.modified.millisecondsSinceEpoch,
    'type': f.type.name,
    'isSent': f.isSent,
    'mimeType': f.mimeType,
  };

  static MediaFile fileFromJson(Map<String, Object?> json) => MediaFile(
    id: json['id']! as String,
    sourceId: json['sourceId']! as String,
    parentId: json['parentId']! as String,
    name: json['name']! as String,
    relativePath: json['relativePath']! as String,
    size: json['size']! as int,
    modified: DateTime.fromMillisecondsSinceEpoch(
      json['modified']! as int,
      isUtc: true,
    ),
    type: MediaType.values.asNameMap()[json['type']] ?? MediaType.other,
    isSent: json['isSent'] as bool? ?? false,
    mimeType: json['mimeType'] as String?,
  );
}
