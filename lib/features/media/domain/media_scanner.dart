import 'cancel_token.dart';
import 'media_file.dart';
import 'media_source.dart';
import 'media_storage.dart';
import 'media_type.dart';

enum ScanPhase { listing, hashing }

/// How far a scan has got, for the progress screen.
final class ScanProgress {
  const ScanProgress({
    this.phase = ScanPhase.listing,
    this.foldersScanned = 0,
    this.filesFound = 0,
    this.bytesFound = 0,
    this.hashed = 0,
    this.toHash = 0,
  });

  final ScanPhase phase;
  final int foldersScanned;
  final int filesFound;
  final int bytesFound;
  final int hashed;
  final int toHash;

  /// 0 to 1 while hashing; null while listing, when the total is unknown.
  double? get fraction => phase == ScanPhase.hashing && toHash > 0
      ? (hashed / toHash).clamp(0.0, 1.0)
      : null;

  ScanProgress copyWith({
    ScanPhase? phase,
    int? foldersScanned,
    int? filesFound,
    int? bytesFound,
    int? hashed,
    int? toHash,
  }) => ScanProgress(
    phase: phase ?? this.phase,
    foldersScanned: foldersScanned ?? this.foldersScanned,
    filesFound: filesFound ?? this.filesFound,
    bytesFound: bytesFound ?? this.bytesFound,
    hashed: hashed ?? this.hashed,
    toHash: toHash ?? this.toHash,
  );
}

/// What a scan found.
final class ScanOutcome {
  const ScanOutcome({
    required this.files,
    this.skippedFolders = 0,
    this.unavailableSources = const [],
  });

  final List<MediaFile> files;

  /// Sub-folders that could not be read and were left out.
  final int skippedFolders;

  /// Sources whose folder is gone or whose access was taken away.
  final List<MediaSource> unavailableSources;
}

/// Walks the granted media folders and lists every file in them.
final class MediaScanner {
  const MediaScanner(this._storage);

  /// The app's trash folder, created inside each `Media` folder. Never
  /// scanned. Must match `TrashFolder.NAME` in the Android code.
  static const trashFolderName = '.media-cleaner-trash';

  final MediaStorage _storage;

  Future<ScanOutcome> scan(
    List<MediaSource> sources, {
    CancelToken? cancel,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    final files = <MediaFile>[];
    final unavailable = <MediaSource>[];
    var skipped = 0;
    var progress = const ScanProgress();

    for (final source in sources) {
      cancel?.throwIfCancelled();
      final pending = <_Folder>[_Folder(source.rootId, '')];
      var isRoot = true;
      while (pending.isNotEmpty) {
        cancel?.throwIfCancelled();
        final folder = pending.removeLast();
        final List<StorageEntry> children;
        try {
          children = await _storage.listChildren(source.treeUri, folder.id);
        } on StorageException {
          if (isRoot) {
            unavailable.add(source);
          } else {
            skipped++;
          }
          isRoot = false;
          continue;
        }
        isRoot = false;

        var bytes = 0;
        var count = 0;
        for (final entry in children) {
          final path = folder.path.isEmpty
              ? entry.name
              : '${folder.path}/${entry.name}';
          if (entry.isDirectory) {
            if (folder.path.isEmpty && entry.name == trashFolderName) continue;
            pending.add(_Folder(entry.id, path));
            continue;
          }
          if (MediaClassifier.isIgnoredFile(entry.name)) continue;
          files.add(
            MediaFile(
              id: entry.id,
              sourceId: source.id,
              parentId: folder.id,
              name: entry.name,
              relativePath: path,
              size: entry.size,
              modified: DateTime.fromMillisecondsSinceEpoch(
                entry.modifiedMillis,
                isUtc: true,
              ),
              type: MediaClassifier.classify(path, mimeType: entry.mimeType),
              isSent: MediaClassifier.isSent(path),
              mimeType: entry.mimeType,
            ),
          );
          bytes += entry.size;
          count++;
        }
        progress = progress.copyWith(
          foldersScanned: progress.foldersScanned + 1,
          filesFound: progress.filesFound + count,
          bytesFound: progress.bytesFound + bytes,
        );
        onProgress?.call(progress);
      }
    }
    return ScanOutcome(
      files: files,
      skippedFolders: skipped,
      unavailableSources: unavailable,
    );
  }
}

final class _Folder {
  const _Folder(this.id, this.path);

  final String id;
  final String path;
}
