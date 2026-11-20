import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import '../../settings/presentation/settings_controller.dart';

/// Whether the app may read and change every file ("All files access").
/// Without it the app still works in the folders the user picked.
final allFilesAccessControllerProvider =
    AsyncNotifierProvider<AllFilesAccessController, bool>(
      AllFilesAccessController.new,
    );

final class AllFilesAccessController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => _check();

  /// Asks Android for the permission. Returns whether it was granted.
  Future<bool> request() async {
    bool granted;
    try {
      granted = await ref.read(allFilesAccessProvider).requestAllFilesAccess();
    } on StorageException catch (e, stack) {
      developer.log(
        'Asking for all files access failed',
        error: e,
        stackTrace: stack,
      );
      granted = await _check();
    }
    if (ref.mounted) state = AsyncData(granted);
    return granted;
  }

  /// Checks again, for example when the user comes back from system
  /// settings, where the permission can also be changed.
  Future<void> refresh() async {
    final granted = await _check();
    if (ref.mounted && state.value != granted) state = AsyncData(granted);
  }

  Future<bool> _check() async {
    try {
      return await ref.read(allFilesAccessProvider).hasAllFilesAccess();
    } on StorageException catch (e, stack) {
      developer.log(
        'Checking all files access failed',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }
}

/// Internal storage and memory cards, while the app has all-files access.
final storageVolumesProvider = FutureProvider<List<StorageVolume>>((ref) async {
  final granted = await ref.watch(allFilesAccessControllerProvider.future);
  if (!granted) return const [];
  return ref.watch(allFilesAccessProvider).storageVolumes();
});

/// Each storage volume as a place to browse.
final volumeSourcesProvider = Provider<List<MediaSource>>(
  (ref) => [
    for (final volume
        in ref.watch(storageVolumesProvider).value ?? const <StorageVolume>[])
      MediaSource.volume(volume),
  ],
);

/// Every place files can come from: the folders in settings and, with
/// all-files access, whole volumes. Trash and file operations look sources
/// up here by [MediaSource.id].
final knownSourcesProvider = Provider<List<MediaSource>>(
  (ref) => [
    ...ref.watch(
      settingsControllerProvider.select((s) => s.value?.sources ?? const []),
    ),
    ...ref.watch(volumeSourcesProvider),
  ],
);
