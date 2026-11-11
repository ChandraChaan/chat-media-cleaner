import 'package:chat_media_cleaner/features/settings/domain/app_settings.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_entry.dart';
import 'package:chat_media_cleaner/features/trash/domain/trash_repository.dart';
import 'package:chat_media_cleaner/features/viewer/domain/playback_positions.dart';

final class MemoryTrashIndexStore implements TrashIndexStore {
  MemoryTrashIndexStore([List<TrashEntry> initial = const []])
    : _entries = [...initial];

  List<TrashEntry> _entries;

  /// A copy of the list at every save, oldest first.
  final saved = <List<TrashEntry>>[];

  @override
  Future<List<TrashEntry>> load() async => [..._entries];

  @override
  Future<void> save(List<TrashEntry> entries) async {
    _entries = [...entries];
    saved.add([...entries]);
  }
}

final class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.settings = const AppSettings()]);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async => this.settings = settings;
}

final class MemoryPlaybackPositionStore implements PlaybackPositionStore {
  MemoryPlaybackPositionStore([Map<String, int> initial = const {}])
    : positions = {...initial};

  Map<String, int> positions;

  @override
  Future<Map<String, int>> load() async => {...positions};

  @override
  Future<void> save(Map<String, int> positions) async =>
      this.positions = {...positions};
}
