import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../home/presentation/scan_controller.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../trash/presentation/trash_controller.dart';
import '../domain/browse_entry.dart';
import '../domain/file_names.dart';

/// Counts changes made to folders from inside the app (a rename), so open
/// listings load again.
final folderRevisionProvider = NotifierProvider<FolderRevision, int>(
  FolderRevision.new,
);

final class FolderRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// What is inside a folder, as it is on the phone right now.
final folderListingProvider = FutureProvider.autoDispose
    .family<FolderListing, BrowseLocation>((ref, location) async {
      ref
        ..watch(folderRevisionProvider)
        // Moving files to the trash or restoring them changes folders.
        ..watch(trashControllerProvider.select((t) => t.value?.length ?? 0));
      final entries = await ref
          .watch(mediaStorageProvider)
          .listChildren(location.source.treeUri, location.dirId);
      return FolderListing.fromEntries(location, entries);
    });

final browseSortProvider = NotifierProvider<BrowseSortController, BrowseSort>(
  BrowseSortController.new,
);

final class BrowseSortController extends Notifier<BrowseSort> {
  @override
  BrowseSort build() => BrowseSort.name;

  void set(BrowseSort sort) => state = sort;
}

/// Whether folders are shown as a grid of pictures rather than a list.
final browseGridProvider = NotifierProvider<BrowseGridController, bool>(
  BrowseGridController.new,
);

final class BrowseGridController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

typedef ShownListingRef = ({BrowseLocation location, String query});

/// A folder's listing in the chosen order, limited to names that contain
/// the search text.
final shownListingProvider = Provider.autoDispose
    .family<AsyncValue<FolderListing>, ShownListingRef>((ref, shown) {
      final sort = ref.watch(browseSortProvider);
      return ref
          .watch(folderListingProvider(shown.location))
          .whenData(
            (listing) =>
                BrowseOrder.apply(listing, sort: sort, query: shown.query),
          );
    });

/// File count and size of every folder, from the last scan. Empty before a
/// scan.
final folderStatsProvider = Provider<Map<String, FolderStats>>((ref) {
  final report = ref.watch(mediaReportProvider);
  return report == null ? const {} : FolderStats.of(report.files);
});

/// What happened when the user renamed a file.
sealed class RenameResult {
  const RenameResult();
}

final class Renamed extends RenameResult {
  const Renamed(this.file);

  final MediaFile file;
}

final class RenameRejected extends RenameResult {
  const RenameRejected(this.problem);

  final NameProblem problem;
}

final class RenameNameTaken extends RenameResult {
  const RenameNameTaken();
}

final class RenameFailed extends RenameResult {
  const RenameFailed();
}

final fileOpsProvider = Provider<FileOps>(FileOps.new);

/// Changes to single files that are not about the trash.
final class FileOps {
  const FileOps(this._ref);

  final Ref _ref;

  Future<RenameResult> rename(MediaFile file, String input) async {
    final problem = FileNames.check(input);
    if (problem != null) return RenameRejected(problem);
    final name = FileNames.clean(input);
    if (name == file.name) return Renamed(file);
    final String newId;
    try {
      newId = await _ref
          .read(mediaStorageProvider)
          .rename(
            file.sourceId,
            fileId: file.id,
            parentId: file.parentId,
            newName: name,
          );
    } on StorageException catch (e, stack) {
      if (e.error == StorageError.nameTaken) return const RenameNameTaken();
      developer.log('Rename failed', error: e, stackTrace: stack);
      return const RenameFailed();
    }
    final folder = file.folder;
    final renamed = file.copyWith(
      id: newId,
      name: name,
      relativePath: folder.isEmpty ? name : '$folder/$name',
    );
    _ref.read(scanControllerProvider.notifier).replaceFile(file.key, renamed);
    _ref.read(folderRevisionProvider.notifier).bump();
    return Renamed(renamed);
  }

  /// Saves the picture [video] shows at [position] as a photo next to it.
  /// Returns the photo's name, or null when it could not be saved.
  Future<String?> saveFrame(MediaFile video, Duration position) async {
    final stem = video.name.substring(0, FileNames.stemLength(video.name));
    final at = position.inSeconds;
    final stamp = '${at ~/ 60}m${(at % 60).toString().padLeft(2, '0')}s';
    try {
      final name = await _ref
          .read(mediaStorageProvider)
          .saveVideoFrame(
            video.sourceId,
            fileId: video.id,
            parentId: video.parentId,
            position: position,
            name: '$stem $stamp.jpg',
          );
      _ref.read(folderRevisionProvider.notifier).bump();
      return name;
    } on StorageException catch (e, stack) {
      developer.log('Saving a frame failed', error: e, stackTrace: stack);
      return null;
    }
  }
}
