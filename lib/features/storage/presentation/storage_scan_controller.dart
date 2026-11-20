import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../access/presentation/storage_access_controller.dart';
import '../../media/domain/cancel_token.dart';
import '../../media/domain/duplicate_finder.dart';
import '../../media/domain/media_scanner.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/storage_report.dart';

sealed class StorageScanState {
  const StorageScanState();
}

/// Not scanned yet in this session, or the scan was cancelled.
final class StorageScanIdle extends StorageScanState {
  const StorageScanIdle();
}

final class StorageScanRunning extends StorageScanState {
  const StorageScanRunning(this.progress);

  final ScanProgress progress;
}

final class StorageScanReady extends StorageScanState {
  const StorageScanReady(this.report);

  final StorageReport report;
}

final class StorageScanFailed extends StorageScanState {
  const StorageScanFailed();
}

/// Smaller files are not compared for duplicates in a whole-storage scan:
/// there are many of them and they free little space.
const minDuplicateBytes = 100 * 1000;

/// Where a storage scan looks: whole volumes with all-files access,
/// otherwise the folders the user chose.
final storageRootsProvider = Provider<List<MediaSource>>((ref) {
  final volumes = ref.watch(volumeSourcesProvider);
  if (volumes.isNotEmpty) return volumes;
  return ref.watch(
    settingsControllerProvider.select((s) => s.value?.sources ?? const []),
  );
});

final storageScanControllerProvider =
    NotifierProvider<StorageScanController, StorageScanState>(
      StorageScanController.new,
    );

/// Scans everything the app can read, for the storage screen: space by
/// kind of file, large files and duplicates.
final class StorageScanController extends Notifier<StorageScanState> {
  CancelToken? _cancel;

  @override
  StorageScanState build() {
    ref.onDispose(() => _cancel?.cancel());
    return const StorageScanIdle();
  }

  Future<void> start() async {
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    state = const StorageScanRunning(ScanProgress());
    try {
      await ref.read(settingsControllerProvider.future);
      await ref.read(storageVolumesProvider.future);
      final roots = ref.read(storageRootsProvider);
      final storage = ref.read(mediaStorageProvider);
      final outcome = await MediaScanner(storage).scan(
        roots,
        cancel: token,
        onProgress: (progress) {
          if (ref.mounted && !token.isCancelled) {
            state = StorageScanRunning(progress);
          }
        },
      );
      if (!ref.mounted || token.isCancelled) return;
      var listed = const ScanProgress();
      if (state case StorageScanRunning(:final progress)) listed = progress;
      final report = StorageReport.from(outcome.files);
      final duplicates = await DuplicateFinder(storage).find(
        [
          for (final f in report.files)
            if (f.size >= minDuplicateBytes) f,
        ],
        cancel: token,
        onProgress: (hashed, total) {
          if (ref.mounted && !token.isCancelled) {
            state = StorageScanRunning(
              listed.copyWith(
                phase: ScanPhase.hashing,
                hashed: hashed,
                toHash: total,
              ),
            );
          }
        },
      );
      if (!ref.mounted || token.isCancelled) return;
      state = StorageScanReady(
        StorageReport.from(
          outcome.files,
          duplicates: duplicates,
          skippedFolders:
              outcome.skippedFolders + outcome.unavailableSources.length,
        ),
      );
    } on ScanCancelled {
      // cancel() already set the state.
    } on StorageException catch (e, stack) {
      developer.log('Storage scan failed', error: e, stackTrace: stack);
      if (ref.mounted && !token.isCancelled) {
        state = const StorageScanFailed();
      }
    }
  }

  void cancel() {
    _cancel?.cancel();
    state = const StorageScanIdle();
  }

  /// Takes files out of the report after they were moved to the trash.
  void removeFiles(Set<String> keys) {
    if (state case StorageScanReady(:final report) when keys.isNotEmpty) {
      state = StorageScanReady(report.without(keys));
    }
  }
}

/// The last storage report, or null before a scan.
final storageReportProvider = Provider<StorageReport?>((ref) {
  final state = ref.watch(storageScanControllerProvider);
  return state is StorageScanReady ? state.report : null;
});
