import '../../media/domain/cancel_token.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_scanner.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';
import 'browse_entry.dart';

/// Finds files and folders whose name contains some text, in a folder and
/// everything below it.
final class FileSearch {
  const FileSearch(this._storage);

  /// More results than this is a sign the search text is too short.
  static const maxResults = 500;

  final MediaStorage _storage;

  /// Searches below [from]. Paths of the results are relative to the
  /// source's root, like those of a scan. Folders that can't be read are
  /// skipped, as are the app's trash and, unless [showHidden], names that
  /// start with a dot.
  Future<List<MediaFile>> run(
    BrowseLocation from,
    String query, {
    bool showHidden = false,
    CancelToken? cancel,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final treeUri = from.source.treeUri;
    final found = <MediaFile>[];
    final pending = <(String, String)>[(from.dirId, from.relativePath)];
    while (pending.isNotEmpty && found.length < maxResults) {
      cancel?.throwIfCancelled();
      final (dirId, path) = pending.removeLast();
      final List<StorageEntry> children;
      try {
        children = await _storage.listChildren(treeUri, dirId);
      } on StorageException {
        continue;
      }
      for (final entry in children) {
        if (!showHidden && entry.name.startsWith('.')) continue;
        if (entry.name == MediaScanner.trashFolderName) continue;
        if (MediaClassifier.isIgnoredFile(entry.name)) continue;
        final childPath = path.isEmpty ? entry.name : '$path/${entry.name}';
        if (entry.isDirectory) pending.add((entry.id, childPath));
        if (!entry.name.toLowerCase().contains(needle)) continue;
        found.add(
          MediaFile(
            id: entry.id,
            sourceId: from.source.id,
            parentId: dirId,
            name: entry.name,
            relativePath: childPath,
            size: entry.isDirectory ? 0 : entry.size,
            modified: DateTime.fromMillisecondsSinceEpoch(
              entry.modifiedMillis,
              isUtc: true,
            ),
            type: entry.isDirectory
                ? MediaType.other
                : MediaClassifier.classify(childPath, mimeType: entry.mimeType),
            mimeType: entry.isDirectory
                ? MediaFile.folderMimeType
                : entry.mimeType,
          ),
        );
        if (found.length >= maxResults) break;
      }
    }
    found.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return found;
  }
}
