import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/media/data/platform_media_storage.dart';
import '../features/media/domain/media_storage.dart';
import '../features/settings/data/prefs_settings_store.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/trash/data/file_trash_index_store.dart';
import '../features/trash/domain/trash_repository.dart';
import '../features/viewer/data/prefs_playback_position_store.dart';
import '../features/viewer/domain/playback_positions.dart';

/// The one place that picks implementations. Tests override these.
final platformStorageProvider = Provider<PlatformMediaStorage>(
  (ref) => PlatformMediaStorage(),
);

final mediaStorageProvider = Provider<MediaStorage>(
  (ref) => ref.watch(platformStorageProvider),
);

final mediaViewerProvider = Provider<MediaViewer>(
  (ref) => ref.watch(platformStorageProvider),
);

final folderAccessProvider = Provider<FolderAccess>(
  (ref) => ref.watch(platformStorageProvider),
);

final screenControlProvider = Provider<ScreenControl>(
  (ref) => ref.watch(platformStorageProvider),
);

final playbackPositionStoreProvider = Provider<PlaybackPositionStore>(
  (ref) => PrefsPlaybackPositionStore(),
);

final playbackPositionsProvider = Provider<PlaybackPositions>(
  (ref) => PlaybackPositions(ref.watch(playbackPositionStoreProvider)),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => PrefsSettingsStore(),
);

final trashIndexStoreProvider = Provider<TrashIndexStore>(
  (ref) => FileTrashIndexStore(),
);

/// The current time. Tests pin it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepository(
    storage: ref.watch(mediaStorageProvider),
    store: ref.watch(trashIndexStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);
