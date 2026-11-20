import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../home/presentation/scan_controller.dart';
import '../../media/domain/cancel_token.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';
import '../../places/presentation/places_controller.dart';
import '../../storage/domain/file_category.dart';
import '../../trash/presentation/trash_controller.dart';
import '../domain/browse_entry.dart';
import '../domain/file_clipboard.dart';
import '../domain/file_names.dart';
import '../domain/file_search.dart';

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

/// Whether names starting with a dot are shown. Chat apps' folders always
/// show them, because WhatsApp keeps statuses in `.Statuses`.
final showHiddenProvider = NotifierProvider<ShowHiddenController, bool>(
  ShowHiddenController.new,
);

final class ShowHiddenController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Only files of this kind are listed; null lists everything.
final typeFilterProvider =
    NotifierProvider<TypeFilterController, FileCategory?>(
      TypeFilterController.new,
    );

final class TypeFilterController extends Notifier<FileCategory?> {
  @override
  FileCategory? build() => null;

  void set(FileCategory? category) => state = category;
}

/// Whether hidden names are shown in [source].
bool showsHiddenIn(MediaSource source, {required bool showHidden}) =>
    showHidden || source.app != ChatApp.other;

typedef ShownListingRef = ({BrowseLocation location, String query});

/// A folder's listing in the chosen order, limited to names that contain
/// the search text and to the chosen kind of file.
final shownListingProvider = Provider.autoDispose
    .family<AsyncValue<FolderListing>, ShownListingRef>((ref, shown) {
      final sort = ref.watch(browseSortProvider);
      final category = ref.watch(typeFilterProvider);
      final hidden = showsHiddenIn(
        shown.location.source,
        showHidden: ref.watch(showHiddenProvider),
      );
      return ref
          .watch(folderListingProvider(shown.location))
          .whenData(
            (listing) => BrowseOrder.apply(
              listing,
              sort: sort,
              query: shown.query,
              category: category,
              showHidden: hidden,
            ),
          );
    });

/// Files and folders whose name contains the search text, anywhere below
/// a folder.
final deepSearchProvider = FutureProvider.autoDispose
    .family<List<MediaFile>, ShownListingRef>((ref, shown) async {
      ref.watch(folderRevisionProvider);
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      final category = ref.watch(typeFilterProvider);
      final found = await FileSearch(ref.watch(mediaStorageProvider)).run(
        shown.location,
        shown.query,
        showHidden: showsHiddenIn(
          shown.location.source,
          showHidden: ref.watch(showHiddenProvider),
        ),
        cancel: cancel,
      );
      if (category == null) return found;
      return [
        for (final f in found)
          if (f.isFolder ||
              FileCategories.of(f.name, mimeType: f.mimeType) == category)
            f,
      ];
    });

/// What the user chose to copy or move, until it is pasted.
final clipboardProvider = NotifierProvider<ClipboardController, FileClipboard?>(
  ClipboardController.new,
);

final class ClipboardController extends Notifier<FileClipboard?> {
  @override
  FileClipboard? build() => null;

  void set(ClipboardMode mode, List<MediaFile> items) =>
      state = items.isEmpty ? null : FileClipboard(mode: mode, items: items);

  void clear() => state = null;
}

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

/// Changes to files and folders that are not about the trash.
final class FileOps {
  const FileOps(this._ref);

  final Ref _ref;

  MediaStorage get _storage => _ref.read(mediaStorageProvider);

  /// Makes a new folder in [location]. A [Renamed] result holds the new
  /// folder.
  Future<RenameResult> createFolder(
    BrowseLocation location,
    String input,
  ) async {
    final problem = FileNames.check(input);
    if (problem != null) return RenameRejected(problem);
    final name = FileNames.clean(input);
    try {
      final item = await _storage.createFolder(
        location.source.treeUri,
        parentId: location.dirId,
        name: name,
      );
      _changed();
      return Renamed(
        BrowseFolder(
          id: item.id,
          name: item.name,
          modified: _ref.read(clockProvider)().toUtc(),
        ).asItem(location),
      );
    } on StorageException catch (e, stack) {
      if (e.error == StorageError.nameTaken) return const RenameNameTaken();
      developer.log('Creating a folder failed', error: e, stackTrace: stack);
      return const RenameFailed();
    }
  }

  /// Copies or moves the clipboard's items into [target], one at a time,
  /// reporting progress. The clipboard is empty afterwards.
  Future<BatchResult> paste(
    FileClipboard clipboard,
    BrowseLocation target, {
    void Function(int done, int total)? onProgress,
  }) async {
    final done = <MediaFile>[];
    var failed = 0;
    final moved = <String>{};
    for (final (i, item) in clipboard.items.indexed) {
      try {
        final StoredItem stored;
        if (clipboard.mode == ClipboardMode.copy) {
          stored = await _storage.copy(
            item.sourceId,
            id: item.id,
            targetTreeUri: target.source.treeUri,
            targetParentId: target.dirId,
          );
        } else {
          stored = await _storage.move(
            item.sourceId,
            id: item.id,
            parentId: item.parentId,
            targetTreeUri: target.source.treeUri,
            targetParentId: target.dirId,
          );
          moved.add(item.key);
        }
        final placed = _placed(item, stored, target);
        done.add(placed);
        if (clipboard.mode == ClipboardMode.move) {
          await _ref
              .read(placesControllerProvider.notifier)
              .replace(item.key, placed);
        }
      } on StorageException catch (e, stack) {
        developer.log('Paste failed', error: e, stackTrace: stack);
        failed++;
      }
      onProgress?.call(i + 1, clipboard.count);
    }
    if (clipboard.mode == ClipboardMode.move) {
      _ref.read(scanControllerProvider.notifier).removeFiles(moved);
    }
    _ref.read(clipboardProvider.notifier).clear();
    _changed();
    return BatchResult(done: done, failed: failed);
  }

  /// Packs [items] (all in [location]) into a ZIP archive there.
  Future<RenameResult> compress(
    BrowseLocation location,
    List<MediaFile> items,
    String input,
  ) async {
    var name = FileNames.clean(input);
    if (!FileCategories.isZip(name)) name = '$name.zip';
    final problem = FileNames.check(name);
    if (problem != null) return RenameRejected(problem);
    try {
      final stored = await _storage.zip(
        location.source.treeUri,
        ids: [for (final item in items) item.id],
        parentId: location.dirId,
        name: name,
      );
      _changed();
      return Renamed(_placed(null, stored, location, isFolder: false));
    } on StorageException catch (e, stack) {
      developer.log('Compressing failed', error: e, stackTrace: stack);
      return const RenameFailed();
    }
  }

  /// Unpacks the ZIP archive [file] into a new folder next to it. Returns
  /// the folder, or null when the archive could not be read.
  Future<MediaFile?> extract(MediaFile file) async {
    try {
      final stored = await _storage.unzip(
        file.sourceId,
        id: file.id,
        parentId: file.parentId,
      );
      _changed();
      final folder = file.folder;
      return MediaFile(
        id: stored.id,
        sourceId: file.sourceId,
        parentId: file.parentId,
        name: stored.name,
        relativePath: folder.isEmpty ? stored.name : '$folder/${stored.name}',
        size: 0,
        modified: _ref.read(clockProvider)().toUtc(),
        type: MediaType.other,
        mimeType: MediaFile.folderMimeType,
      );
    } on StorageException catch (e, stack) {
      developer.log('Extracting failed', error: e, stackTrace: stack);
      return null;
    }
  }

  /// How much a folder holds, or null when it can't be measured.
  Future<FolderSize?> measure(MediaFile folder) async {
    try {
      return await _storage.folderSize(folder.sourceId, folder.id);
    } on StorageException catch (e, stack) {
      developer.log('Measuring a folder failed', error: e, stackTrace: stack);
      return null;
    }
  }

  /// [items] with the size of each folder filled in, so the trash can say
  /// how much space they take.
  Future<List<MediaFile>> withFolderSizes(List<MediaFile> items) async => [
    for (final item in items)
      if (item.isFolder)
        item.copyWith(size: (await measure(item))?.bytes ?? 0)
      else
        item,
  ];

  MediaFile _placed(
    MediaFile? original,
    StoredItem stored,
    BrowseLocation target, {
    bool? isFolder,
  }) {
    final path = target.isRoot
        ? stored.name
        : '${target.relativePath}/${stored.name}';
    final folder = isFolder ?? original?.isFolder ?? false;
    return MediaFile(
      id: stored.id,
      sourceId: target.source.id,
      parentId: target.dirId,
      name: stored.name,
      relativePath: path,
      size: original?.size ?? 0,
      modified: original?.modified ?? _ref.read(clockProvider)().toUtc(),
      type: original?.type ?? MediaType.other,
      isSent: original?.isSent ?? false,
      mimeType: folder ? MediaFile.folderMimeType : original?.mimeType,
    );
  }

  void _changed() => _ref.read(folderRevisionProvider.notifier).bump();

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
    await _ref
        .read(placesControllerProvider.notifier)
        .replace(file.key, renamed);
    _changed();
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
