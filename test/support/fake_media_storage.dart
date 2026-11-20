import 'dart:convert';
import 'dart:typed_data';

import 'package:chat_media_cleaner/features/media/domain/media_scanner.dart';
import 'package:chat_media_cleaner/features/media/domain/media_source.dart';
import 'package:chat_media_cleaner/features/media/domain/media_storage.dart';

/// Where WhatsApp keeps media on Android 11 and newer, as a document id.
const waMediaId = 'primary:Android/media/com.whatsapp/WhatsApp/Media';
const waTree =
    'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia';
const waSource = MediaSource(
  treeUri: waTree,
  rootId: waMediaId,
  app: ChatApp.whatsapp,
);

const wabMediaId =
    'primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media';
const wabTree =
    'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp.w4b';
const wabSource = MediaSource(
  treeUri: wabTree,
  rootId: wabMediaId,
  app: ChatApp.whatsappBusiness,
);

/// The smallest valid PNG: one transparent pixel.
final onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// An in-memory shared storage that behaves like Android's external storage
/// documents provider: document ids are `primary:<path>`, folders are
/// created on demand, and access is limited to granted trees.
class FakeMediaStorage
    implements
        MediaStorage,
        MediaViewer,
        FolderAccess,
        AllFilesAccess,
        ScreenControl {
  FakeMediaStorage({this.sdk = 34});

  /// Whether the app has all-files access: file trees ([fileTreeUri]) can
  /// then reach any absolute path.
  bool allFilesGranted = false;

  /// What [requestAllFilesAccess] does to [allFilesGranted].
  bool grantOnRequest = true;
  int accessRequests = 0;

  /// Volumes [storageVolumes] reports while access is granted.
  final volumes = <StorageVolume>[];

  /// Adds a storage volume at [path] (an absolute path) and its folder.
  void addVolume(
    String path, {
    String label = 'Internal shared storage',
    int totalBytes = 128 * 1000 * 1000 * 1000,
    int freeBytes = 40 * 1000 * 1000 * 1000,
  }) {
    _ensureDir(path);
    volumes.add(
      StorageVolume(
        path: path,
        label: label,
        isPrimary: volumes.isEmpty,
        isRemovable: volumes.isNotEmpty,
        totalBytes: totalBytes,
        freeBytes: freeBytes,
      ),
    );
  }

  int sdk;
  final _nodes = <String, _Node>{};
  final _grants = <String, String>{};

  /// Folders the next [pickFolder] calls return, in order. Null = cancelled.
  final pickQueue = <PickedFolder?>[];
  final released = <String>[];
  final opened = <String>[];
  final initialDocIds = <String?>[];

  /// File ids whose move to the trash fails.
  final failMoves = <String>{};

  /// Folder ids whose listing fails.
  final failLists = <String>{};

  /// Completed listChildren calls, for checking that work stopped.
  int listCalls = 0;

  /// Gives [treeUri] access to everything below [rootId].
  void grant(String treeUri, String rootId) {
    _grants[treeUri] = rootId;
    _ensureDir(rootId);
  }

  void revoke(String treeUri) => _grants.remove(treeUri);

  /// Adds a file at [path] below [rootId] (a `Media` folder by default).
  /// Missing folders are created.
  String addFile(
    String path, {
    int size = 1000,
    DateTime? modified,
    String? mime,
    String? content,
    String rootId = waMediaId,
  }) {
    final id = '$rootId/$path';
    _ensureDir(_parentOf(id));
    _nodes[id] = _Node(
      isDir: false,
      size: size,
      modified: (modified ?? DateTime.utc(2024)).millisecondsSinceEpoch,
      mime: mime ?? _mimeFor(path),
      content: content ?? 'content of $path',
    );
    return id;
  }

  void addDir(String path, {String rootId = waMediaId}) =>
      _ensureDir('$rootId/$path');

  void delete(String id) =>
      _nodes.removeWhere((key, _) => key == id || key.startsWith('$id/'));

  bool exists(String id) => _nodes.containsKey(id);

  /// Ids of all files (not folders) below [rootId].
  List<String> filesBelow(String rootId) => [
    for (final MapEntry(:key, :value) in _nodes.entries)
      if (!value.isDir && key.startsWith('$rootId/')) key,
  ]..sort();

  /// Ids of files in the app's trash below [rootId].
  List<String> trashedFiles([String rootId = waMediaId]) => [
    for (final id in filesBelow('$rootId/${MediaScanner.trashFolderName}'))
      if (!id.endsWith('/.nomedia')) id,
  ];

  @override
  Future<List<StorageEntry>> listChildren(String treeUri, String dirId) async {
    _checkAccess(treeUri, dirId);
    if (failLists.contains(dirId)) {
      throw const StorageException(StorageError.failed, 'listing failed');
    }
    final node = _nodes[dirId];
    if (node == null || !node.isDir) {
      throw StorageException(StorageError.notFound, dirId);
    }
    listCalls++;
    return [
      for (final id in _childrenOf(dirId))
        StorageEntry(
          id: id,
          name: _nameOf(id),
          isDirectory: _nodes[id]!.isDir,
          size: _nodes[id]!.size,
          modifiedMillis: _nodes[id]!.modified,
          mimeType: _nodes[id]!.isDir
              ? 'vnd.android.document/directory'
              : _nodes[id]!.mime,
        ),
    ];
  }

  /// Files whose hashing fails.
  final failHashes = <String>{};

  /// Number of hashFile calls, to check that only candidates are hashed.
  int hashCalls = 0;

  @override
  Future<String> hashFile(String treeUri, String fileId) async {
    _checkAccess(treeUri, fileId);
    hashCalls++;
    final node = _nodes[fileId];
    if (node == null || node.isDir) {
      throw StorageException(StorageError.notFound, fileId);
    }
    if (failHashes.contains(fileId)) {
      throw const StorageException(StorageError.failed, 'read failed');
    }
    // Stands in for SHA-256: equal content gives an equal "hash".
    return 'hash:${node.content}';
  }

  @override
  Future<TrashedItem> moveToTrash(
    String treeUri, {
    required String rootId,
    required String fileId,
    required String parentId,
    required String itemKey,
  }) async {
    _checkAccess(treeUri, fileId);
    if (!_nodes.containsKey(fileId)) {
      throw StorageException(StorageError.notFound, fileId);
    }
    if (failMoves.contains(fileId)) {
      throw const StorageException(StorageError.failed, 'move failed');
    }
    final trash = '$rootId/${MediaScanner.trashFolderName}';
    if (!_nodes.containsKey(trash)) {
      _ensureDir(trash);
      _nodes['$trash/.nomedia'] = const _Node(isDir: false);
    }
    final itemDir = '$trash/$itemKey';
    _ensureDir(itemDir);
    final newId = '$itemDir/${_nameOf(fileId)}';
    _moveTree(fileId, newId);
    return TrashedItem(itemDirId: itemDir, fileId: newId);
  }

  @override
  Future<RestoredFile> restoreFromTrash(
    String treeUri, {
    required TrashedItem item,
    required String targetParentId,
  }) async {
    _checkAccess(treeUri, item.fileId);
    if (!_nodes.containsKey(item.fileId)) {
      throw StorageException(StorageError.notFound, item.fileId);
    }
    if (!_nodes.containsKey(targetParentId)) {
      throw StorageException(StorageError.targetMissing, targetParentId);
    }
    final taken = {for (final id in _childrenOf(targetParentId)) _nameOf(id)};
    final name = _firstFree(_nameOf(item.fileId), taken);
    final newId = '$targetParentId/$name';
    _moveTree(item.fileId, newId);
    delete(item.itemDirId);
    return RestoredFile(fileId: newId, name: name);
  }

  @override
  Future<void> deleteTrashItem(String treeUri, String itemDirId) async {
    _checkAccess(treeUri, itemDirId);
    if (!_nodes.containsKey(itemDirId)) {
      throw StorageException(StorageError.notFound, itemDirId);
    }
    delete(itemDirId);
  }

  @override
  Future<StoredItem> createFolder(
    String treeUri, {
    required String parentId,
    required String name,
  }) async {
    _checkAccess(treeUri, parentId);
    final id = '$parentId/$name';
    if (_nodes.containsKey(id)) {
      throw StorageException(StorageError.nameTaken, name);
    }
    _nodes[id] = const _Node(isDir: true);
    return StoredItem(id: id, name: name);
  }

  /// Item ids whose copy or move fails.
  final failCopies = <String>{};

  @override
  Future<StoredItem> copy(
    String treeUri, {
    required String id,
    required String targetTreeUri,
    required String targetParentId,
  }) async {
    _checkAccess(treeUri, id);
    _checkAccess(targetTreeUri, targetParentId);
    _checkTransfer(id, targetParentId);
    final name = _freeNameIn(targetParentId, _nameOf(id));
    final newId = '$targetParentId/$name';
    for (final entry in [..._nodes.entries]) {
      if (entry.key == id || entry.key.startsWith('$id/')) {
        _nodes['$newId${entry.key.substring(id.length)}'] = entry.value;
      }
    }
    return StoredItem(id: newId, name: name);
  }

  @override
  Future<StoredItem> move(
    String treeUri, {
    required String id,
    required String parentId,
    required String targetTreeUri,
    required String targetParentId,
  }) async {
    _checkAccess(treeUri, id);
    _checkAccess(targetTreeUri, targetParentId);
    if (parentId == targetParentId) {
      return StoredItem(id: id, name: _nameOf(id));
    }
    _checkTransfer(id, targetParentId);
    final name = _freeNameIn(targetParentId, _nameOf(id));
    final newId = '$targetParentId/$name';
    _moveTree(id, newId);
    return StoredItem(id: newId, name: name);
  }

  @override
  Future<void> deletePermanently(String treeUri, String id) async {
    _checkAccess(treeUri, id);
    if (!_nodes.containsKey(id)) {
      throw StorageException(StorageError.notFound, id);
    }
    delete(id);
  }

  @override
  Future<FolderSize> folderSize(String treeUri, String id) async {
    _checkAccess(treeUri, id);
    if (!_nodes.containsKey(id)) {
      throw StorageException(StorageError.notFound, id);
    }
    var bytes = 0;
    var files = 0;
    var folders = 0;
    for (final entry in _nodes.entries) {
      if (entry.key != id && !entry.key.startsWith('$id/')) continue;
      if (entry.value.isDir) {
        if (entry.key != id) folders++;
      } else {
        files++;
        bytes += entry.value.size;
      }
    }
    return FolderSize(bytes: bytes, files: files, folders: folders);
  }

  @override
  Future<StoredItem> zip(
    String treeUri, {
    required List<String> ids,
    required String parentId,
    required String name,
  }) async {
    _checkAccess(treeUri, parentId);
    final entries = <String, String>{};
    for (final id in ids) {
      _checkAccess(treeUri, id);
      final base = _parentOf(id);
      for (final entry in _nodes.entries) {
        if (entry.value.isDir) continue;
        if (entry.key == id || entry.key.startsWith('$id/')) {
          entries[entry.key.substring(base.length + 1)] = entry.value.content;
        }
      }
    }
    final free = _freeNameIn(parentId, name);
    final content = 'zip:${jsonEncode(entries)}';
    _nodes['$parentId/$free'] = _Node(
      isDir: false,
      size: content.length,
      mime: 'application/zip',
      content: content,
    );
    return StoredItem(id: '$parentId/$free', name: free);
  }

  @override
  Future<StoredItem> unzip(
    String treeUri, {
    required String id,
    required String parentId,
  }) async {
    _checkAccess(treeUri, id);
    final node = _nodes[id];
    if (node == null) throw StorageException(StorageError.notFound, id);
    if (!node.content.startsWith('zip:')) {
      throw StorageException(StorageError.unreadable, id);
    }
    final entries =
        (jsonDecode(node.content.substring(4)) as Map<String, Object?>)
            .cast<String, String>();
    final stem = _nameOf(id).replaceFirst(RegExp(r'\.zip$'), '');
    final folder = _freeNameIn(parentId, stem);
    final folderId = '$parentId/$folder';
    _ensureDir(folderId);
    for (final MapEntry(:key, :value) in entries.entries) {
      final fileId = '$folderId/$key';
      _ensureDir(_parentOf(fileId));
      _nodes[fileId] = _Node(
        isDir: false,
        size: value.length,
        mime: _mimeFor(key),
        content: value,
      );
    }
    return StoredItem(id: folderId, name: folder);
  }

  @override
  Future<bool> hasAllFilesAccess() async => allFilesGranted;

  @override
  Future<bool> requestAllFilesAccess() async {
    accessRequests++;
    if (grantOnRequest) allFilesGranted = true;
    return allFilesGranted;
  }

  @override
  Future<List<StorageVolume>> storageVolumes() async =>
      allFilesGranted ? [...volumes] : const [];

  void _checkTransfer(String id, String targetParentId) {
    if (!_nodes.containsKey(id)) {
      throw StorageException(StorageError.notFound, id);
    }
    if (failCopies.contains(id)) {
      throw const StorageException(StorageError.failed, 'copy failed');
    }
    if (targetParentId == id || targetParentId.startsWith('$id/')) {
      throw StorageException(StorageError.invalidTarget, id);
    }
  }

  String _freeNameIn(String parentId, String name) =>
      _firstFree(name, {for (final c in _childrenOf(parentId)) _nameOf(c)});

  /// Moves a file, or a folder with everything in it, to [to].
  void _moveTree(String from, String to) {
    for (final key in [..._nodes.keys]) {
      if (key == from || key.startsWith('$from/')) {
        _nodes['$to${key.substring(from.length)}'] = _nodes.remove(key)!;
      }
    }
  }

  @override
  Future<Uint8List?> thumbnail(
    String treeUri,
    String fileId, {
    int size = 256,
  }) async => null;

  @override
  Future<Uint8List> readBytes(
    String treeUri,
    String fileId, {
    int maxBytes = 30 * 1024 * 1024,
    bool truncate = false,
  }) async {
    final node = _nodes[fileId];
    if (node == null) throw StorageException(StorageError.notFound, fileId);
    final bytes = Uint8List.fromList(utf8.encode(node.content));
    if (bytes.length <= maxBytes) return bytes;
    if (!truncate) throw StorageException(StorageError.tooLarge, fileId);
    return Uint8List.sublistView(bytes, 0, maxBytes);
  }

  /// Files whose rename fails for a reason other than a name clash.
  final failRenames = <String>{};

  @override
  Future<String> rename(
    String treeUri, {
    required String fileId,
    required String parentId,
    required String newName,
  }) async {
    _checkAccess(treeUri, fileId);
    if (!_nodes.containsKey(fileId)) {
      throw StorageException(StorageError.notFound, fileId);
    }
    if (failRenames.contains(fileId)) {
      throw const StorageException(StorageError.failed, 'rename failed');
    }
    final newId = '$parentId/$newName';
    if (_nodes.containsKey(newId)) {
      throw StorageException(StorageError.nameTaken, newName);
    }
    _moveTree(fileId, newId);
    return newId;
  }

  @override
  Future<String> contentUri(String treeUri, String fileId) async =>
      'content://fake/${Uri.encodeComponent(fileId)}';

  /// What [mediaInfo] reports, by file id.
  final infos = <String, MediaInfo>{};

  @override
  Future<MediaInfo> mediaInfo(String treeUri, String fileId) async =>
      infos[fileId] ?? MediaInfo.none;

  /// Page counts of PDFs, by file id. A PDF that is not listed is damaged.
  final pdfPages = <String, int>{};

  /// PDFs that need a password.
  final lockedPdfs = <String>{};

  /// Pages drawn so far, as `fileId#index`.
  final drawnPdfPages = <String>[];
  int pdfCloses = 0;

  @override
  Future<int> pdfPageCount(String treeUri, String fileId) async {
    if (lockedPdfs.contains(fileId)) {
      throw StorageException(StorageError.locked, fileId);
    }
    final pages = pdfPages[fileId];
    if (pages == null) throw StorageException(StorageError.unreadable, fileId);
    return pages;
  }

  @override
  Future<PdfPageImage> pdfPage(
    String treeUri,
    String fileId,
    int index, {
    required int width,
  }) async {
    drawnPdfPages.add('$fileId#$index');
    return PdfPageImage(bytes: onePixelPng, width: 595, height: 842);
  }

  @override
  Future<void> closePdf() async => pdfCloses++;

  /// Every [keepScreenOn] call, in order.
  final screenOn = <bool>[];

  @override
  Future<void> keepScreenOn({required bool on}) async => screenOn.add(on);

  double? screenBrightness;
  int mediaVolume = 5;
  int maxVolume = 15;

  @override
  Future<double?> brightness() async => screenBrightness;

  @override
  Future<void> setBrightness(double? value) async => screenBrightness = value;

  @override
  Future<({int current, int max})> volume() async =>
      (current: mediaVolume, max: maxVolume);

  @override
  Future<void> setVolume(int value) async => mediaVolume = value;

  /// Videos no frame can be taken from.
  final failFrames = <String>{};

  @override
  Future<String> saveVideoFrame(
    String treeUri, {
    required String fileId,
    required String parentId,
    required Duration position,
    required String name,
  }) async {
    _checkAccess(treeUri, fileId);
    if (failFrames.contains(fileId)) {
      throw StorageException(StorageError.unreadable, fileId);
    }
    final taken = {for (final id in _childrenOf(parentId)) _nameOf(id)};
    final free = _firstFree(name, taken);
    _nodes['$parentId/$free'] = _Node(
      isDir: false,
      size: 1000,
      mime: 'image/jpeg',
      content: 'frame of $fileId at ${position.inSeconds}s',
    );
    return free;
  }

  /// Every [share] call: the file ids and the MIME type.
  final shared = <({List<String> ids, String? mimeType})>[];

  @override
  Future<void> share(
    List<({String treeUri, String fileId})> files, {
    String? mimeType,
  }) async {
    shared.add((ids: [for (final f in files) f.fileId], mimeType: mimeType));
  }

  @override
  Future<void> openExternally(
    String treeUri,
    String fileId,
    String? mimeType,
  ) async => opened.add(fileId);

  @override
  Future<int> sdkInt() async => sdk;

  @override
  Future<PickedFolder?> pickFolder({String? initialDocId}) async {
    initialDocIds.add(initialDocId);
    final picked = pickQueue.removeAt(0);
    if (picked != null) grant(picked.treeUri, picked.treeDocId);
    return picked;
  }

  @override
  Future<List<String>> grantedFolders() async => [..._grants.keys];

  @override
  Future<void> releaseFolder(String treeUri) async {
    released.add(treeUri);
    _grants.remove(treeUri);
  }

  String contentOf(String id) => _nodes[id]!.content;

  void _checkAccess(String treeUri, String id) {
    if (isFileTree(treeUri)) {
      if (!allFilesGranted || !id.startsWith('/')) {
        throw StorageException(StorageError.permissionLost, treeUri);
      }
      return;
    }
    final root = _grants[treeUri];
    final below =
        root != null &&
        (root.endsWith(':') ? id.startsWith(root) : id.startsWith('$root/'));
    if (root == null || !(id == root || below)) {
      throw StorageException(StorageError.permissionLost, treeUri);
    }
  }

  void _ensureDir(String id) {
    if (_nodes[id]?.isDir ?? false) return;
    final parent = _parentOf(id);
    final inVolume = parent.contains(':') && !parent.endsWith(':');
    final inFileTree = parent.startsWith('/') && parent.length > 1;
    if (parent != id && (inVolume || inFileTree)) {
      _ensureDir(parent);
    }
    _nodes[id] = const _Node(isDir: true);
  }

  Iterable<String> _childrenOf(String dirId) =>
      _nodes.keys.where((id) => _parentOf(id) == dirId).toList()..sort();

  static String _parentOf(String id) {
    final slash = id.lastIndexOf('/');
    if (slash >= 0) return id.substring(0, slash);
    // `primary:Android` is a child of the volume root `primary:`.
    final colon = id.indexOf(':');
    return colon >= 0 && colon < id.length - 1
        ? id.substring(0, colon + 1)
        : id;
  }

  static String _nameOf(String id) {
    final slash = id.lastIndexOf('/');
    if (slash >= 0) return id.substring(slash + 1);
    final colon = id.indexOf(':');
    return colon < 0 ? id : id.substring(colon + 1);
  }

  static String _firstFree(String name, Set<String> taken) {
    if (!taken.contains(name)) return name;
    final dot = name.lastIndexOf('.');
    String numbered(int n) => dot > 0
        ? '${name.substring(0, dot)} ($n)${name.substring(dot)}'
        : '$name ($n)';
    var n = 1;
    while (taken.contains(numbered(n))) {
      n++;
    }
    return numbered(n);
  }

  static String? _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }
}

final class _Node {
  const _Node({
    required this.isDir,
    this.size = 0,
    this.modified = 0,
    this.mime,
    this.content = '',
  });

  final bool isDir;
  final int size;
  final int modified;
  final String? mime;
  final String content;
}
