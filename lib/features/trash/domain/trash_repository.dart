import '../../media/domain/media_file.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import 'trash_entry.dart';

/// Saves and loads the list of trashed files.
abstract interface class TrashIndexStore {
  Future<List<TrashEntry>> load();
  Future<void> save(List<TrashEntry> entries);
}

/// The result of a trash operation on several items: what worked ([D]) and
/// what did not ([F]) and why.
final class TrashOpResult<D, F> {
  const TrashOpResult({
    required this.done,
    required this.failed,
    required this.bytes,
  });

  final List<D> done;
  final List<(F, StorageError)> failed;

  /// Size of the items in [done].
  final int bytes;
}

/// Keeps track of what is in the trash: moving files in, putting them back,
/// and deleting them for good when the restore window ends.
final class TrashRepository {
  TrashRepository({
    required this._storage,
    required this._store,
    required this._clock,
    String Function()? newId,
  }) : _newId = newId ?? _timeBasedIds(_clock);

  /// Save the index at least this often while moving many files, so little
  /// is lost if the app is closed half way.
  static const _saveEvery = 20;

  final MediaStorage _storage;
  final TrashIndexStore _store;
  final DateTime Function() _clock;
  final String Function() _newId;
  List<TrashEntry>? _entries;

  /// Everything in the trash, newest first.
  Future<List<TrashEntry>> entries() async {
    final sorted = [...await _load()]
      ..sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
    return List.unmodifiable(sorted);
  }

  /// Moves [files] into the trash. Files whose source is missing from
  /// [sources] fail with [StorageError.permissionLost].
  Future<TrashOpResult<TrashEntry, MediaFile>> moveToTrash(
    List<MediaFile> files,
    Map<String, MediaSource> sources, {
    void Function(int done, int total)? onProgress,
  }) async {
    final entries = await _load();
    final done = <TrashEntry>[];
    final failed = <(MediaFile, StorageError)>[];
    var bytes = 0;
    var unsaved = 0;
    for (final (i, file) in files.indexed) {
      final source = sources[file.sourceId];
      if (source == null) {
        failed.add((file, StorageError.permissionLost));
      } else {
        final id = _newId();
        try {
          final item = await _storage.moveToTrash(
            source.treeUri,
            rootId: source.rootId,
            fileId: file.id,
            parentId: file.parentId,
            itemKey: id,
          );
          final entry = TrashEntry.fromFile(
            file,
            id: id,
            trashedAt: _clock(),
            item: item,
          );
          entries.add(entry);
          done.add(entry);
          bytes += file.size;
          if (++unsaved >= _saveEvery) {
            await _store.save(entries);
            unsaved = 0;
          }
        } on StorageException catch (e) {
          failed.add((file, e.error));
        }
      }
      onProgress?.call(i + 1, files.length);
    }
    if (unsaved > 0) await _store.save(entries);
    return TrashOpResult(done: done, failed: failed, bytes: bytes);
  }

  /// Puts [toRestore] back where they were. Returns the restored files as
  /// they are now (a file may get a numbered name if its name was taken).
  /// Entries whose file has disappeared from the trash are dropped.
  Future<TrashOpResult<MediaFile, TrashEntry>> restore(
    List<TrashEntry> toRestore,
  ) async {
    final entries = await _load();
    final done = <MediaFile>[];
    final failed = <(TrashEntry, StorageError)>[];
    var bytes = 0;
    for (final entry in toRestore) {
      try {
        final restored = await _storage.restoreFromTrash(
          entry.sourceId,
          item: entry.item,
          targetParentId: entry.originalParentId,
        );
        entries.removeWhere((e) => e.id == entry.id);
        done.add(entry.toRestoredFile(restored));
        bytes += entry.size;
      } on StorageException catch (e) {
        if (e.error == StorageError.notFound) {
          entries.removeWhere((e) => e.id == entry.id);
        }
        failed.add((entry, e.error));
      }
    }
    await _store.save(entries);
    return TrashOpResult(done: done, failed: failed, bytes: bytes);
  }

  /// Deletes [toDelete] for good. Returns how much space was freed.
  Future<TrashOpResult<TrashEntry, TrashEntry>> deleteForever(
    List<TrashEntry> toDelete,
  ) async {
    final entries = await _load();
    final done = <TrashEntry>[];
    final failed = <(TrashEntry, StorageError)>[];
    var bytes = 0;
    for (final entry in toDelete) {
      try {
        await _storage.deleteTrashItem(entry.sourceId, entry.item.itemDirId);
        done.add(entry);
        bytes += entry.size;
      } on StorageException catch (e) {
        if (e.error == StorageError.notFound) {
          // Already gone, so nothing is left to free; just forget it.
          done.add(entry);
        } else {
          failed.add((entry, e.error));
          continue;
        }
      }
      entries.removeWhere((e) => e.id == entry.id);
    }
    await _store.save(entries);
    return TrashOpResult(done: done, failed: failed, bytes: bytes);
  }

  /// Deletes everything that has been in the trash for [retention] or
  /// longer.
  Future<TrashOpResult<TrashEntry, TrashEntry>> deleteExpired(
    Duration retention,
  ) async {
    final now = _clock();
    final expired = (await _load())
        .where((e) => e.isExpired(now, retention))
        .toList();
    if (expired.isEmpty) {
      return const TrashOpResult(done: [], failed: [], bytes: 0);
    }
    return deleteForever(expired);
  }

  Future<TrashOpResult<TrashEntry, TrashEntry>> deleteAll() async =>
      deleteForever(List.of(await _load()));

  Future<List<TrashEntry>> _load() async =>
      _entries ??= [...await _store.load()];

  static String Function() _timeBasedIds(DateTime Function() clock) {
    var counter = 0;
    return () {
      final time = clock().microsecondsSinceEpoch.toRadixString(36);
      return '$time-${(counter++).toRadixString(36)}';
    };
  }
}
