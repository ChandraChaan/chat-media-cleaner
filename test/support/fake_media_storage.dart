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

/// An in-memory shared storage that behaves like Android's external storage
/// documents provider: document ids are `primary:<path>`, folders are
/// created on demand, and access is limited to granted trees.
class FakeMediaStorage implements MediaStorage, MediaViewer, FolderAccess {
  FakeMediaStorage({this.sdk = 34});

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
    _nodes[newId] = _nodes.remove(fileId)!;
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
    _nodes[newId] = _nodes.remove(item.fileId)!;
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
  }) async {
    final node = _nodes[fileId];
    if (node == null) throw StorageException(StorageError.notFound, fileId);
    return Uint8List.fromList(utf8.encode(node.content));
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
    if (parent != id && parent.contains(':') && !parent.endsWith(':')) {
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
