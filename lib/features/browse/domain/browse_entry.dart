import '../../media/domain/media_file.dart';
import '../../media/domain/media_scanner.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';

/// A folder being looked at: [dirId] inside [source], [path] segments below
/// the source's root (empty at the root itself).
final class BrowseLocation {
  const BrowseLocation({
    required this.source,
    required this.dirId,
    this.path = const [],
  });

  BrowseLocation.root(this.source) : dirId = source.rootId, path = const [];

  final MediaSource source;
  final String dirId;
  final List<String> path;

  bool get isRoot => path.isEmpty;

  /// The path below the source's root, for example `WhatsApp Images/Sent`.
  String get relativePath => path.join('/');

  BrowseLocation child(BrowseFolder folder) => BrowseLocation(
    source: source,
    dirId: folder.id,
    path: [...path, folder.name],
  );

  @override
  bool operator ==(Object other) =>
      other is BrowseLocation && other.source == source && other.dirId == dirId;

  @override
  int get hashCode => Object.hash(source, dirId);
}

/// A sub-folder in a listing.
final class BrowseFolder {
  const BrowseFolder({
    required this.id,
    required this.name,
    required this.modified,
  });

  final String id;
  final String name;

  /// Last modified time, in UTC.
  final DateTime modified;
}

/// What is directly inside a folder.
final class FolderListing {
  const FolderListing({required this.folders, required this.files});

  static const empty = FolderListing(folders: [], files: []);

  final List<BrowseFolder> folders;
  final List<MediaFile> files;

  bool get isEmpty => folders.isEmpty && files.isEmpty;

  /// Turns raw storage entries into a listing, leaving out the app's own
  /// trash folder and housekeeping files.
  static FolderListing fromEntries(
    BrowseLocation location,
    List<StorageEntry> entries,
  ) {
    final folders = <BrowseFolder>[];
    final files = <MediaFile>[];
    final prefix = location.isRoot ? '' : '${location.relativePath}/';
    for (final entry in entries) {
      final modified = DateTime.fromMillisecondsSinceEpoch(
        entry.modifiedMillis,
        isUtc: true,
      );
      if (entry.isDirectory) {
        if (location.isRoot && entry.name == MediaScanner.trashFolderName) {
          continue;
        }
        folders.add(
          BrowseFolder(id: entry.id, name: entry.name, modified: modified),
        );
        continue;
      }
      if (MediaClassifier.isIgnoredFile(entry.name)) continue;
      final path = '$prefix${entry.name}';
      files.add(
        MediaFile(
          id: entry.id,
          sourceId: location.source.id,
          parentId: location.dirId,
          name: entry.name,
          relativePath: path,
          size: entry.size,
          modified: modified,
          type: MediaClassifier.classify(path, mimeType: entry.mimeType),
          isSent: MediaClassifier.isSent(path),
          mimeType: entry.mimeType,
        ),
      );
    }
    return FolderListing(folders: folders, files: files);
  }
}

enum BrowseSort { name, newest, oldest, largest, smallest }

/// Ordering and filtering of a listing. Folders always come first and are
/// never ordered by size, which they do not have.
abstract final class BrowseOrder {
  static FolderListing apply(
    FolderListing listing, {
    required BrowseSort sort,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    bool matches(String name) =>
        needle.isEmpty || name.toLowerCase().contains(needle);

    final folders = listing.folders.where((f) => matches(f.name)).toList()
      ..sort(switch (sort) {
        BrowseSort.newest => (a, b) => _then(
          b.modified.compareTo(a.modified),
          a.name,
          b.name,
        ),
        BrowseSort.oldest => (a, b) => _then(
          a.modified.compareTo(b.modified),
          a.name,
          b.name,
        ),
        BrowseSort.name ||
        BrowseSort.largest ||
        BrowseSort.smallest => (a, b) => _byName(a.name, b.name),
      });
    final files = listing.files.where((f) => matches(f.name)).toList()
      ..sort(switch (sort) {
        BrowseSort.name => (a, b) => _byName(a.name, b.name),
        BrowseSort.newest => (a, b) => _then(
          b.modified.compareTo(a.modified),
          a.name,
          b.name,
        ),
        BrowseSort.oldest => (a, b) => _then(
          a.modified.compareTo(b.modified),
          a.name,
          b.name,
        ),
        BrowseSort.largest => (a, b) => _then(
          b.size.compareTo(a.size),
          a.name,
          b.name,
        ),
        BrowseSort.smallest => (a, b) => _then(
          a.size.compareTo(b.size),
          a.name,
          b.name,
        ),
      });
    return FolderListing(folders: folders, files: files);
  }

  static int _then(int first, String a, String b) =>
      first != 0 ? first : _byName(a, b);

  /// Case-insensitive, with the exact name as the tie-break so the order is
  /// always the same.
  static int _byName(String a, String b) {
    final byLower = a.toLowerCase().compareTo(b.toLowerCase());
    return byLower != 0 ? byLower : a.compareTo(b);
  }
}

/// How much a folder holds, counting everything below it.
final class FolderStats {
  const FolderStats({this.count = 0, this.bytes = 0});

  final int count;
  final int bytes;

  /// Totals for every folder that holds one of [files], keyed by
  /// [keyOf]`(sourceId, folder path)`. The source's root has the path ''.
  static Map<String, FolderStats> of(Iterable<MediaFile> files) {
    final counts = <String, int>{};
    final bytes = <String, int>{};
    for (final file in files) {
      var folder = file.folder;
      while (true) {
        final key = keyOf(file.sourceId, folder);
        counts[key] = (counts[key] ?? 0) + 1;
        bytes[key] = (bytes[key] ?? 0) + file.size;
        if (folder.isEmpty) break;
        final slash = folder.lastIndexOf('/');
        folder = slash < 0 ? '' : folder.substring(0, slash);
      }
    }
    return {
      for (final key in counts.keys)
        key: FolderStats(count: counts[key]!, bytes: bytes[key]!),
    };
  }

  static String keyOf(String sourceId, String folderPath) =>
      '$sourceId|$folderPath';
}
