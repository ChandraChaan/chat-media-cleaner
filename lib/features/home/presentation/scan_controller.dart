import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../media/domain/cancel_token.dart';
import '../../media/domain/duplicate_finder.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_report.dart';
import '../../media/domain/media_scanner.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';

sealed class ScanState {
  const ScanState();
}

/// No scan yet, or the last one was cancelled.
final class ScanIdle extends ScanState {
  const ScanIdle();
}

final class ScanRunning extends ScanState {
  const ScanRunning(this.progress);

  final ScanProgress progress;
}

final class ScanReady extends ScanState {
  const ScanReady({
    required this.files,
    this.duplicates = const [],
    this.skippedFolders = 0,
    this.unavailable = const [],
  });

  final List<MediaFile> files;

  /// Identical files as found by the scan; the report re-checks them
  /// against [files].
  final List<DuplicateSet> duplicates;
  final int skippedFolders;
  final List<MediaSource> unavailable;

  ScanReady withFiles(List<MediaFile> files) => ScanReady(
    files: files,
    duplicates: duplicates,
    skippedFolders: skippedFolders,
    unavailable: unavailable,
  );
}

enum ScanFailure {
  /// None of the folders could be opened.
  noAccess,
  failed,
}

final class ScanFailed extends ScanState {
  const ScanFailed(this.reason);

  final ScanFailure reason;
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);

final class ScanController extends Notifier<ScanState> {
  CancelToken? _cancel;

  @override
  ScanState build() {
    ref.onDispose(() => _cancel?.cancel());
    ref.listen(
      settingsControllerProvider.select((s) => s.value?.sources),
      (previous, next) => _onSourcesChanged(previous ?? const [], next ?? []),
    );
    return const ScanIdle();
  }

  Future<void> start() async {
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    state = const ScanRunning(ScanProgress());
    final List<MediaSource> sources;
    try {
      sources = (await ref.read(settingsControllerProvider.future)).sources;
    } on Object catch (e, stack) {
      developer.log('Settings failed to load', error: e, stackTrace: stack);
      if (ref.mounted && !token.isCancelled) {
        state = const ScanFailed(ScanFailure.failed);
      }
      return;
    }
    try {
      final storage = ref.read(mediaStorageProvider);
      final outcome = await MediaScanner(storage).scan(
        sources,
        cancel: token,
        onProgress: (progress) {
          if (ref.mounted && !token.isCancelled) {
            state = ScanRunning(progress);
          }
        },
      );
      if (!ref.mounted || token.isCancelled) return;
      if (sources.isNotEmpty &&
          outcome.unavailableSources.length == sources.length) {
        state = const ScanFailed(ScanFailure.noAccess);
        return;
      }
      var progress = const ScanProgress();
      if (state case ScanRunning(progress: final listed)) progress = listed;
      final duplicates = await DuplicateFinder(storage).find(
        outcome.files,
        cancel: token,
        onProgress: (hashed, total) {
          if (ref.mounted && !token.isCancelled) {
            state = ScanRunning(
              progress.copyWith(
                phase: ScanPhase.hashing,
                hashed: hashed,
                toHash: total,
              ),
            );
          }
        },
      );
      if (!ref.mounted || token.isCancelled) return;
      state = ScanReady(
        files: outcome.files,
        duplicates: duplicates,
        skippedFolders: outcome.skippedFolders,
        unavailable: outcome.unavailableSources,
      );
    } on ScanCancelled {
      // cancel() already set the state.
    } on StorageException catch (e, stack) {
      developer.log('Scan failed', error: e, stackTrace: stack);
      if (ref.mounted && !token.isCancelled) {
        state = const ScanFailed(ScanFailure.failed);
      }
    }
  }

  void cancel() {
    _cancel?.cancel();
    state = const ScanIdle();
  }

  /// Takes files out of the results, after they were moved to the trash.
  void removeFiles(Set<String> keys) {
    if (state case final ScanReady ready when keys.isNotEmpty) {
      state = ready.withFiles(
        ready.files.where((f) => !keys.contains(f.key)).toList(),
      );
    }
  }

  /// Puts files back into the results, after they were restored.
  void addFiles(List<MediaFile> files) {
    if (state case final ScanReady ready when files.isNotEmpty) {
      final added = {for (final f in files) f.key};
      state = ready.withFiles([
        ...ready.files.where((f) => !added.contains(f.key)),
        ...files,
      ]);
    }
  }

  void _onSourcesChanged(List<MediaSource> previous, List<MediaSource> next) {
    final before = {for (final s in previous) s.id};
    final after = {for (final s in next) s.id};
    if (after.difference(before).isNotEmpty) {
      // A new folder: old results are incomplete.
      cancel();
    } else if (state case final ScanReady ready) {
      state = ready.withFiles(
        ready.files.where((f) => after.contains(f.sourceId)).toList(),
      );
    }
  }
}

/// Totals and smart groups for the current scan, or null before a scan.
final mediaReportProvider = Provider<MediaReport?>((ref) {
  final scan = ref.watch(scanControllerProvider);
  if (scan is! ScanReady) return null;
  final months = ref.watch(
    settingsControllerProvider.select(
      (s) => s.value?.oldAfterMonths ?? AppSettings.defaultOldAfterMonths,
    ),
  );
  return MediaAnalyzer.analyze(
    scan.files,
    rules: AnalysisRules(oldAfterMonths: months),
    now: ref.read(clockProvider)(),
    duplicates: scan.duplicates,
  );
});
