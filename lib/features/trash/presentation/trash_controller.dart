import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../home/presentation/scan_controller.dart';
import '../../media/domain/media_file.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/trash_entry.dart';
import '../domain/trash_repository.dart';

final trashControllerProvider =
    AsyncNotifierProvider<TrashController, List<TrashEntry>>(
      TrashController.new,
    );

/// The trash list. Opening the app deletes what has been in the trash
/// longer than the user's restore window.
final class TrashController extends AsyncNotifier<List<TrashEntry>> {
  Future<void> _queue = Future.value();

  TrashRepository get _repo => ref.read(trashRepositoryProvider);

  @override
  Future<List<TrashEntry>> build() async {
    await _deleteExpired();
    return _repo.entries();
  }

  Future<TrashOpResult<TrashEntry, MediaFile>> moveToTrash(
    List<MediaFile> files, {
    void Function(int done, int total)? onProgress,
  }) => _serial(() async {
    final settings = await ref.read(settingsControllerProvider.future);
    final result = await _repo.moveToTrash(files, {
      for (final s in settings.sources) s.id: s,
    }, onProgress: onProgress);
    ref.read(scanControllerProvider.notifier).removeFiles({
      for (final e in result.done) e.originalKey,
    });
    await _refresh();
    return result;
  });

  Future<TrashOpResult<MediaFile, TrashEntry>> restore(
    List<TrashEntry> entries,
  ) => _serial(() async {
    final result = await _repo.restore(entries);
    ref.read(scanControllerProvider.notifier).addFiles(result.done);
    await _refresh();
    return result;
  });

  Future<TrashOpResult<TrashEntry, TrashEntry>> deleteForever(
    List<TrashEntry> entries,
  ) => _serial(() async {
    final result = await _repo.deleteForever(entries);
    await _freed(result.bytes);
    await _refresh();
    return result;
  });

  Future<TrashOpResult<TrashEntry, TrashEntry>> deleteAll() =>
      _serial(() async {
        final result = await _repo.deleteAll();
        await _freed(result.bytes);
        await _refresh();
        return result;
      });

  /// Deletes the trashed files of one folder, before access to it is
  /// given up (afterwards they could not be reached any more).
  Future<TrashOpResult<TrashEntry, TrashEntry>> deleteForSource(
    String sourceId,
  ) => _serial(() async {
    final entries = (await _repo.entries())
        .where((e) => e.sourceId == sourceId)
        .toList();
    final result = await _repo.deleteForever(entries);
    await _freed(result.bytes);
    await _refresh();
    return result;
  });

  /// Applies a shorter restore window right away.
  Future<void> deleteExpired() => _serial(() async {
    await _deleteExpired();
    await _refresh();
  });

  Future<void> _deleteExpired() async {
    final settings = await ref.read(settingsControllerProvider.future);
    final result = await _repo.deleteExpired(settings.retention);
    await _freed(result.bytes);
  }

  Future<void> _freed(int bytes) =>
      ref.read(settingsControllerProvider.notifier).addFreedBytes(bytes);

  Future<void> _refresh() async {
    final entries = await _repo.entries();
    if (ref.mounted) state = AsyncData(entries);
  }

  /// Runs trash operations one after another, never at the same time.
  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
