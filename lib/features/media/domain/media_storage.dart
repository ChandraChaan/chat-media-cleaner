import 'dart:typed_data';

/// A file or folder returned by [MediaStorage.listChildren].
final class StorageEntry {
  const StorageEntry({
    required this.id,
    required this.name,
    required this.isDirectory,
    this.size = 0,
    this.modifiedMillis = 0,
    this.mimeType,
  });

  final String id;
  final String name;
  final bool isDirectory;
  final int size;

  /// Milliseconds since the epoch (UTC).
  final int modifiedMillis;
  final String? mimeType;
}

/// Where a file went when it was moved to the trash.
final class TrashedItem {
  const TrashedItem({required this.itemDirId, required this.fileId});

  /// The per-item folder inside the trash that holds the file.
  final String itemDirId;

  /// The file's id inside [itemDirId].
  final String fileId;
}

/// A file put back by [MediaStorage.restoreFromTrash].
final class RestoredFile {
  const RestoredFile({required this.fileId, required this.name});

  final String fileId;

  /// Usually the original name; numbered when that name was taken.
  final String name;
}

/// A folder the user picked in the system folder picker.
final class PickedFolder {
  const PickedFolder({required this.treeUri, required this.treeDocId});

  /// The persisted grant; also the id of the source.
  final String treeUri;

  /// The document id of the picked folder, `volume:path` on Android.
  final String treeDocId;
}

/// File operations on the folders the user granted access to.
///
/// On Android this is the Storage Access Framework; tests use an in-memory
/// fake. Every id is opaque except where a method says otherwise.
abstract interface class MediaStorage {
  /// Files and folders directly inside [dirId].
  Future<List<StorageEntry>> listChildren(String treeUri, String dirId);

  /// Moves a file into the app's trash folder below [rootId], in a new
  /// folder named [itemKey] so names never clash.
  Future<TrashedItem> moveToTrash(
    String treeUri, {
    required String rootId,
    required String fileId,
    required String parentId,
    required String itemKey,
  });

  /// Moves a trashed file back into [targetParentId] and removes its item
  /// folder. If a file with the same name exists there, the restored file
  /// gets a numbered name instead of replacing it.
  Future<RestoredFile> restoreFromTrash(
    String treeUri, {
    required TrashedItem item,
    required String targetParentId,
  });

  /// Permanently deletes a trash item folder and the file inside it.
  Future<void> deleteTrashItem(String treeUri, String itemDirId);
}

/// Showing files: thumbnails, previews and opening in another app.
abstract interface class MediaViewer {
  Future<Uint8List?> thumbnail(String treeUri, String fileId, {int size});

  /// The file's bytes, for showing a photo full screen. Throws
  /// [StorageException] when it is larger than [maxBytes].
  Future<Uint8List> readBytes(String treeUri, String fileId, {int maxBytes});

  Future<void> openExternally(String treeUri, String fileId, String? mimeType);
}

/// Asking for, listing and giving up folder access.
abstract interface class FolderAccess {
  /// The Android SDK level, to choose where the picker starts.
  Future<int> sdkInt();

  /// Opens the system folder picker, starting at [initialDocId] when the
  /// system supports it. Returns null when the user backs out.
  Future<PickedFolder?> pickFolder({String? initialDocId});

  /// Tree URIs the app still holds read and write access to.
  Future<List<String>> grantedFolders();

  Future<void> releaseFolder(String treeUri);
}

/// Why a storage call failed.
enum StorageError {
  /// The file or folder no longer exists.
  notFound,

  /// The folder a file should go back to no longer exists.
  targetMissing,

  /// Access to the folder was taken away (for example in system settings).
  permissionLost,

  /// No installed app can open the file.
  noApp,

  /// The file is too large for the requested operation.
  tooLarge,

  /// Anything else.
  failed,
}

final class StorageException implements Exception {
  const StorageException(this.error, [this.detail]);

  final StorageError error;

  /// Technical detail for logs; never shown to users.
  final String? detail;

  @override
  String toString() => 'StorageException(${error.name}: $detail)';
}
