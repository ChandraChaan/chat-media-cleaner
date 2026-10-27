import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../domain/media_storage.dart';

/// [MediaStorage], [MediaViewer] and [FolderAccess] backed by the Android
/// Storage Access Framework code in `StorageChannel.kt`.
final class PlatformMediaStorage
    implements MediaStorage, MediaViewer, FolderAccess {
  PlatformMediaStorage([this._channel = const MethodChannel(channelName)]);

  static const channelName = 'dev.chandra.chat_media_cleaner/storage';

  /// Thumbnails kept in memory; at about 20 KB each this is a few MB.
  static const _thumbnailCacheSize = 300;

  final MethodChannel _channel;

  /// Insertion-ordered, so the first key is the least recently used.
  final _thumbnails = <String, Uint8List?>{};

  @override
  Future<List<StorageEntry>> listChildren(String treeUri, String dirId) async {
    final rows = await _call<List<Object?>>('listChildren', {
      'treeUri': treeUri,
      'docId': dirId,
    });
    return [
      for (final row in rows ?? const <Object?>[])
        if (row case final Map<Object?, Object?> map)
          StorageEntry(
            id: map['id']! as String,
            name: map['name']! as String,
            isDirectory: map['isDir']! as bool,
            size: (map['size'] as int?) ?? 0,
            modifiedMillis: (map['modified'] as int?) ?? 0,
            mimeType: map['mime'] as String?,
          ),
    ];
  }

  @override
  Future<String> hashFile(String treeUri, String fileId) async =>
      (await _call<String>('hashFile', {'treeUri': treeUri, 'docId': fileId}))!;

  @override
  Future<TrashedItem> moveToTrash(
    String treeUri, {
    required String rootId,
    required String fileId,
    required String parentId,
    required String itemKey,
  }) async {
    final map = await _call<Map<Object?, Object?>>('moveToTrash', {
      'treeUri': treeUri,
      'rootId': rootId,
      'docId': fileId,
      'parentId': parentId,
      'itemKey': itemKey,
    });
    return TrashedItem(
      itemDirId: map!['itemDirId']! as String,
      fileId: map['fileId']! as String,
    );
  }

  @override
  Future<RestoredFile> restoreFromTrash(
    String treeUri, {
    required TrashedItem item,
    required String targetParentId,
  }) async {
    final map = await _call<Map<Object?, Object?>>('restoreFromTrash', {
      'treeUri': treeUri,
      'itemDirId': item.itemDirId,
      'docId': item.fileId,
      'targetParentId': targetParentId,
    });
    return RestoredFile(
      fileId: map!['fileId']! as String,
      name: map['name']! as String,
    );
  }

  @override
  Future<void> deleteTrashItem(String treeUri, String itemDirId) =>
      _call<void>('deleteTrashItem', {'treeUri': treeUri, 'docId': itemDirId});

  @override
  Future<Uint8List?> thumbnail(
    String treeUri,
    String fileId, {
    int size = 256,
  }) async {
    final key = '$treeUri|$fileId|$size';
    if (_thumbnails.containsKey(key)) {
      final cached = _thumbnails.remove(key);
      _thumbnails[key] = cached;
      return cached;
    }
    Uint8List? bytes;
    try {
      bytes = await _call<Uint8List>('thumbnail', {
        'treeUri': treeUri,
        'docId': fileId,
        'size': size,
      });
    } on StorageException catch (e, stack) {
      // A missing thumbnail is not an error worth showing; the tile falls
      // back to an icon.
      developer.log('No thumbnail', error: e, stackTrace: stack);
    }
    _thumbnails[key] = bytes;
    if (_thumbnails.length > _thumbnailCacheSize) {
      _thumbnails.remove(_thumbnails.keys.first);
    }
    return bytes;
  }

  @override
  Future<Uint8List> readBytes(
    String treeUri,
    String fileId, {
    int maxBytes = 30 * 1024 * 1024,
  }) async {
    final bytes = await _call<Uint8List>('readBytes', {
      'treeUri': treeUri,
      'docId': fileId,
      'maxBytes': maxBytes,
    });
    return bytes!;
  }

  @override
  Future<void> openExternally(
    String treeUri,
    String fileId,
    String? mimeType,
  ) => _call<void>('openExternally', {
    'treeUri': treeUri,
    'docId': fileId,
    'mime': mimeType,
  });

  @override
  Future<int> sdkInt() async => (await _call<int>('sdkInt')) ?? 0;

  @override
  Future<PickedFolder?> pickFolder({String? initialDocId}) async {
    final map = await _call<Map<Object?, Object?>>('pickFolder', {
      'initialDocId': initialDocId,
    });
    if (map == null) return null;
    return PickedFolder(
      treeUri: map['treeUri']! as String,
      treeDocId: map['treeDocId']! as String,
    );
  }

  @override
  Future<List<String>> grantedFolders() async {
    final list = await _call<List<Object?>>('grantedFolders');
    return [...?list?.whereType<String>()];
  }

  @override
  Future<void> releaseFolder(String treeUri) =>
      _call<void>('releaseFolder', {'treeUri': treeUri});

  /// Calls the native side and maps its error codes to [StorageException].
  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw StorageException(_errorFor(e.code), '${e.code}: ${e.message}');
    }
  }

  static StorageError _errorFor(String code) => switch (code) {
    'not_found' => StorageError.notFound,
    'target_missing' => StorageError.targetMissing,
    'permission' => StorageError.permissionLost,
    'no_app' => StorageError.noApp,
    'too_large' => StorageError.tooLarge,
    _ => StorageError.failed,
  };
}
