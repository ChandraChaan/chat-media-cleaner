import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../domain/media_storage.dart';

/// [MediaStorage], [MediaViewer], [FolderAccess] and [ScreenControl] backed
/// by the Android
/// Storage Access Framework code in `StorageChannel.kt`.
final class PlatformMediaStorage
    implements MediaStorage, MediaViewer, FolderAccess, ScreenControl {
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
  Future<String> rename(
    String treeUri, {
    required String fileId,
    required String parentId,
    required String newName,
  }) async {
    final map = await _call<Map<Object?, Object?>>('rename', {
      'treeUri': treeUri,
      'docId': fileId,
      'parentId': parentId,
      'name': newName,
    });
    _thumbnails.removeWhere((key, _) => key.startsWith('$treeUri|$fileId|'));
    return map!['id']! as String;
  }

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
    bool truncate = false,
  }) async {
    final bytes = await _call<Uint8List>('readBytes', {
      'treeUri': treeUri,
      'docId': fileId,
      'maxBytes': maxBytes,
      'truncate': truncate,
    });
    return bytes!;
  }

  @override
  Future<String> contentUri(String treeUri, String fileId) async =>
      (await _call<String>('documentUri', {
        'treeUri': treeUri,
        'docId': fileId,
      }))!;

  @override
  Future<MediaInfo> mediaInfo(String treeUri, String fileId) async {
    final map = await _call<Map<Object?, Object?>>('mediaInfo', {
      'treeUri': treeUri,
      'docId': fileId,
    });
    final millis = map?['durationMs'] as int?;
    return MediaInfo(
      width: map?['width'] as int?,
      height: map?['height'] as int?,
      duration: millis == null ? null : Duration(milliseconds: millis),
    );
  }

  @override
  Future<int> pdfPageCount(String treeUri, String fileId) async =>
      (await _call<int>('pdfPageCount', {
        'treeUri': treeUri,
        'docId': fileId,
      })) ??
      0;

  @override
  Future<PdfPageImage> pdfPage(
    String treeUri,
    String fileId,
    int index, {
    required int width,
  }) async {
    final map = await _call<Map<Object?, Object?>>('pdfPage', {
      'treeUri': treeUri,
      'docId': fileId,
      'index': index,
      'width': width,
    });
    return PdfPageImage(
      bytes: map!['bytes']! as Uint8List,
      width: map['width']! as int,
      height: map['height']! as int,
    );
  }

  @override
  Future<void> closePdf() => _call<void>('pdfClose');

  @override
  Future<void> keepScreenOn({required bool on}) =>
      _call<void>('keepScreenOn', {'on': on});

  @override
  Future<double?> brightness() => _call<double>('brightness');

  @override
  Future<void> setBrightness(double? value) =>
      _call<void>('setBrightness', {'value': value});

  @override
  Future<({int current, int max})> volume() async {
    final map = await _call<Map<Object?, Object?>>('volume');
    return (
      current: (map?['current'] as int?) ?? 0,
      max: (map?['max'] as int?) ?? 1,
    );
  }

  @override
  Future<void> setVolume(int value) =>
      _call<void>('setVolume', {'value': value});

  @override
  Future<String> saveVideoFrame(
    String treeUri, {
    required String fileId,
    required String parentId,
    required Duration position,
    required String name,
  }) async {
    final map = await _call<Map<Object?, Object?>>('saveVideoFrame', {
      'treeUri': treeUri,
      'docId': fileId,
      'parentId': parentId,
      'positionMs': position.inMilliseconds,
      'name': name,
    });
    return map!['name']! as String;
  }

  @override
  Future<void> share(
    List<({String treeUri, String fileId})> files, {
    String? mimeType,
  }) => _call<void>('share', {
    'items': [
      for (final f in files) {'treeUri': f.treeUri, 'docId': f.fileId},
    ],
    'mime': mimeType,
  });

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
    'exists' => StorageError.nameTaken,
    'locked' => StorageError.locked,
    'unreadable' => StorageError.unreadable,
    _ => StorageError.failed,
  };
}
