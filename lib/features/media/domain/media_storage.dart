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

/// What is known about a picture, video or sound beyond its size and date.
final class MediaInfo {
  const MediaInfo({this.width, this.height, this.duration});

  static const none = MediaInfo();

  /// Pixel size of a picture or video, as it is shown (rotation applied).
  final int? width;
  final int? height;

  /// How long a video or sound lasts.
  final Duration? duration;

  bool get hasDimensions => width != null && height != null;
}

/// One page of a PDF drawn as a picture.
final class PdfPageImage {
  const PdfPageImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// An encoded image (JPEG).
  final Uint8List bytes;
  final int width;
  final int height;
}

/// A file or folder made by [MediaStorage.createFolder], a copy, a move or
/// an archive operation.
final class StoredItem {
  const StoredItem({required this.id, required this.name});

  final String id;

  /// The name it got; numbered when the wanted name was taken.
  final String name;
}

/// How much a folder holds, counting everything below it.
final class FolderSize {
  const FolderSize({this.bytes = 0, this.files = 0, this.folders = 0});

  final int bytes;
  final int files;
  final int folders;
}

/// Internal storage or a memory card, as seen with all-files access.
final class StorageVolume {
  const StorageVolume({
    required this.path,
    required this.label,
    required this.isPrimary,
    required this.isRemovable,
    required this.totalBytes,
    required this.freeBytes,
  });

  /// Absolute path of the volume's top folder, for example
  /// `/storage/emulated/0`.
  final String path;

  /// The name Android gives it, for example "Internal shared storage".
  final String label;
  final bool isPrimary;
  final bool isRemovable;
  final int totalBytes;
  final int freeBytes;

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);

  /// 0 to 1.
  double get usedFraction => totalBytes <= 0 ? 0 : usedBytes / totalBytes;

  @override
  bool operator ==(Object other) =>
      other is StorageVolume &&
      other.path == path &&
      other.label == label &&
      other.isPrimary == isPrimary &&
      other.isRemovable == isRemovable &&
      other.totalBytes == totalBytes &&
      other.freeBytes == freeBytes;

  @override
  int get hashCode =>
      Object.hash(path, label, isPrimary, isRemovable, totalBytes, freeBytes);
}

/// Tree URIs that start with this are file-system trees: their ids are
/// absolute paths, readable while the app has all-files access. Every
/// other tree URI is a Storage Access Framework grant.
const fileTreeScheme = 'file://';

/// The tree URI of the file-system tree rooted at [path].
String fileTreeUri(String path) => '$fileTreeScheme$path';

/// Whether [treeUri] is a file-system tree rather than a folder grant.
bool isFileTree(String treeUri) => treeUri.startsWith(fileTreeScheme);

/// File operations on the folders the user granted access to.
///
/// On Android this is the Storage Access Framework for folders picked in
/// the system picker, and plain files for [fileTreeUri] trees while the app
/// has all-files access; tests use an in-memory fake. Every id is opaque
/// except where a method says otherwise. Folders and files share one id
/// space, and the operations below work on both unless a method says
/// otherwise.
abstract interface class MediaStorage {
  /// Files and folders directly inside [dirId].
  Future<List<StorageEntry>> listChildren(String treeUri, String dirId);

  /// SHA-256 of the file's content, as lowercase hex.
  Future<String> hashFile(String treeUri, String fileId);

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

  /// Gives the file in [parentId] a new name and returns its new id. Throws
  /// [StorageError.nameTaken] when the folder already has a [newName].
  Future<String> rename(
    String treeUri, {
    required String fileId,
    required String parentId,
    required String newName,
  });

  /// Makes a new empty folder [name] in [parentId]. Throws
  /// [StorageError.nameTaken] when something there already has that name.
  Future<StoredItem> createFolder(
    String treeUri, {
    required String parentId,
    required String name,
  });

  /// Copies a file or a whole folder into [targetParentId], which may be
  /// in another tree. The copy gets a numbered name when its name is taken.
  /// Throws [StorageError.invalidTarget] when a folder would be copied into
  /// itself.
  Future<StoredItem> copy(
    String treeUri, {
    required String id,
    required String targetTreeUri,
    required String targetParentId,
  });

  /// Moves a file or a whole folder from [parentId] into [targetParentId],
  /// numbering its name when taken. Throws [StorageError.invalidTarget]
  /// when a folder would be moved into itself.
  Future<StoredItem> move(
    String treeUri, {
    required String id,
    required String parentId,
    required String targetTreeUri,
    required String targetParentId,
  });

  /// Deletes a file or folder for good, without the trash.
  Future<void> deletePermanently(String treeUri, String id);

  /// Size and number of files of a folder and everything below it.
  Future<FolderSize> folderSize(String treeUri, String id);

  /// Packs [ids] (files and folders) into a ZIP archive called [name] in
  /// [parentId].
  Future<StoredItem> zip(
    String treeUri, {
    required List<String> ids,
    required String parentId,
    required String name,
  });

  /// Unpacks the ZIP archive [id] into a new folder next to it, named
  /// after the archive. Throws [StorageError.unreadable] for a damaged
  /// archive.
  Future<StoredItem> unzip(
    String treeUri, {
    required String id,
    required String parentId,
  });

  /// Saves the picture a video shows at [position] as a JPEG called [name]
  /// (numbered when taken) in the same folder. Returns the name it got.
  Future<String> saveVideoFrame(
    String treeUri, {
    required String fileId,
    required String parentId,
    required Duration position,
    required String name,
  });
}

/// Showing files: thumbnails, previews and opening in another app.
abstract interface class MediaViewer {
  Future<Uint8List?> thumbnail(String treeUri, String fileId, {int size});

  /// The file's bytes, for showing a photo full screen. Throws
  /// [StorageException] when it is larger than [maxBytes], unless
  /// [truncate] is set: then only the first [maxBytes] bytes are returned.
  Future<Uint8List> readBytes(
    String treeUri,
    String fileId, {
    int maxBytes,
    bool truncate,
  });

  Future<void> openExternally(String treeUri, String fileId, String? mimeType);

  /// An address the video and audio player can read the file from.
  Future<String> contentUri(String treeUri, String fileId);

  /// Pixel size and duration, where the file has them.
  Future<MediaInfo> mediaInfo(String treeUri, String fileId);

  /// Throws [StorageError.locked] for a password-protected PDF and
  /// [StorageError.unreadable] for a damaged one.
  Future<int> pdfPageCount(String treeUri, String fileId);

  /// Page [index] (from 0) drawn about [width] pixels wide.
  Future<PdfPageImage> pdfPage(
    String treeUri,
    String fileId,
    int index, {
    required int width,
  });

  /// Frees what [pdfPageCount] and [pdfPage] keep open.
  Future<void> closePdf();

  /// Opens the system share sheet for [files].
  Future<void> share(
    List<({String treeUri, String fileId})> files, {
    String? mimeType,
  });
}

/// The phone's screen and sound, as the video player changes them.
abstract interface class ScreenControl {
  /// Keeps the screen from dimming and locking, while a video plays.
  Future<void> keepScreenOn({required bool on});

  /// The app's own screen brightness from 0 to 1, or null while the screen
  /// follows the system setting.
  Future<double?> brightness();

  /// Sets the brightness for this app only; null gives it back to the
  /// system setting.
  Future<void> setBrightness(double? value);

  /// The media volume in the phone's own steps.
  Future<({int current, int max})> volume();

  Future<void> setVolume(int value);
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

/// Access to every file on the phone: "All files access" on Android 11 and
/// newer, the storage permission on older versions.
abstract interface class AllFilesAccess {
  Future<bool> hasAllFilesAccess();

  /// Opens Android's screen (or dialog) for the permission and reports
  /// whether it is granted afterwards.
  Future<bool> requestAllFilesAccess();

  /// Internal storage and any memory cards that are mounted.
  Future<List<StorageVolume>> storageVolumes();
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

  /// Another file in the folder already has that name.
  nameTaken,

  /// The file needs a password.
  locked,

  /// The file is damaged or not what its name says.
  unreadable,

  /// A folder can't be copied or moved into itself.
  invalidTarget,

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
