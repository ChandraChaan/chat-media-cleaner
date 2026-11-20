import '../../media/domain/media_file.dart';

enum ClipboardMode { copy, move }

/// Files and folders the user chose to copy or move, waiting for a
/// destination.
final class FileClipboard {
  const FileClipboard({required this.mode, required this.items});

  final ClipboardMode mode;

  /// Files, and folders as [MediaFile.isFolder] items.
  final List<MediaFile> items;

  int get count => items.length;

  /// Whether pasting into the folder [dirId] of the source [sourceId] would
  /// put a folder inside itself.
  bool wouldNestInto(String sourceId, String dirId) => items.any(
    (item) =>
        item.isFolder &&
        item.sourceId == sourceId &&
        (item.id == dirId || _isBelow(dirId, item.id)),
  );

  /// Ids of file trees are paths (`/a/b`) and folder-grant ids are
  /// `volume:path`; in both, a child's id starts with its parent's id and
  /// a slash.
  static bool _isBelow(String id, String folderId) =>
      id.startsWith('$folderId/');
}

/// One step's outcome when pasting or compressing several items.
final class BatchResult {
  const BatchResult({required this.done, required this.failed});

  /// The new items.
  final List<MediaFile> done;

  /// How many items could not be handled.
  final int failed;
}
