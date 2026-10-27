import 'media_storage.dart';

/// Which chat app a media folder belongs to.
enum ChatApp { whatsapp, whatsappBusiness, other }

/// A granted chat media folder: the `Media` folder of one app.
final class MediaSource {
  const MediaSource({
    required this.treeUri,
    required this.rootId,
    required this.app,
  });

  /// The persisted folder grant. Unique, so it doubles as the source id.
  final String treeUri;

  /// Document id of the `Media` folder (the grant may be a parent of it).
  final String rootId;
  final ChatApp app;

  String get id => treeUri;

  Map<String, Object?> toJson() => {
    'treeUri': treeUri,
    'rootId': rootId,
    'app': app.name,
  };

  static MediaSource fromJson(Map<String, Object?> json) => MediaSource(
    treeUri: json['treeUri']! as String,
    rootId: json['rootId']! as String,
    app: ChatApp.values.asNameMap()[json['app']] ?? ChatApp.other,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaSource &&
      other.treeUri == treeUri &&
      other.rootId == rootId &&
      other.app == app;

  @override
  int get hashCode => Object.hash(treeUri, rootId, app);
}

/// The folder picked does not contain chat media.
final class NotAChatMediaFolder implements Exception {
  const NotAChatMediaFolder(this.path);

  final String path;

  @override
  String toString() => 'NotAChatMediaFolder($path)';
}

/// Known places of chat media folders, and turning a picked folder into one
/// or more [MediaSource]s.
abstract final class SourceLocator {
  /// The primary shared-storage volume in Storage Access Framework ids.
  static const primaryVolume = 'primary';

  /// Android 11 and newer keep app media under `Android/media`.
  static const _modern = <ChatApp, String>{
    ChatApp.whatsapp: 'Android/media/com.whatsapp/WhatsApp/Media',
    ChatApp.whatsappBusiness:
        'Android/media/com.whatsapp.w4b/WhatsApp Business/Media',
  };

  /// Android 10 and older (and phones that kept the old layout).
  static const _legacy = <ChatApp, String>{
    ChatApp.whatsapp: 'WhatsApp/Media',
    ChatApp.whatsappBusiness: 'WhatsApp Business/Media',
  };

  /// Android 11 is SDK 30.
  static const _scopedStorageSdk = 30;

  /// The document id the folder picker should open at for [app].
  static String initialDocId(ChatApp app, int sdkInt) {
    final paths = sdkInt >= _scopedStorageSdk ? _modern : _legacy;
    final path = paths[app] ?? paths[ChatApp.whatsapp]!;
    return '$primaryVolume:$path';
  }

  /// The path part of a `volume:path` document id.
  static String pathOf(String docId) {
    final colon = docId.indexOf(':');
    return colon < 0 ? docId : docId.substring(colon + 1);
  }

  /// Finds the chat media folders inside (or at) the picked folder.
  ///
  /// Accepts the `Media` folder itself or any parent of it on a known path
  /// (for example `Android/media/com.whatsapp` or even `Android/media`, which
  /// can hold both apps). A folder elsewhere is accepted when it directly
  /// contains WhatsApp-style media folders, for example a copy on an SD card.
  /// Throws [NotAChatMediaFolder] otherwise.
  static Future<List<MediaSource>> resolve(
    MediaStorage storage,
    PickedFolder picked,
  ) async {
    final path = _trimSlashes(pathOf(picked.treeDocId));
    final known = {
      for (final e in _modern.entries) e.value: e.key,
      for (final e in _legacy.entries) e.value: e.key,
    };

    final sources = <MediaSource>[];
    for (final MapEntry(key: mediaPath, value: app) in known.entries) {
      if (path == mediaPath) {
        return [
          MediaSource(
            treeUri: picked.treeUri,
            rootId: picked.treeDocId,
            app: app,
          ),
        ];
      }
      if (path.isEmpty || mediaPath.startsWith('$path/')) {
        final remaining = path.isEmpty
            ? mediaPath.split('/')
            : mediaPath.substring(path.length + 1).split('/');
        final rootId = await _descend(
          storage,
          picked.treeUri,
          picked.treeDocId,
          remaining,
        );
        if (rootId != null) {
          sources.add(
            MediaSource(treeUri: picked.treeUri, rootId: rootId, app: app),
          );
        }
      }
    }
    if (sources.isNotEmpty) return _onePerApp(sources);

    if (await _looksLikeMediaFolder(storage, picked)) {
      return [
        MediaSource(
          treeUri: picked.treeUri,
          rootId: picked.treeDocId,
          app: _guessApp(path),
        ),
      ];
    }
    throw NotAChatMediaFolder(path);
  }

  /// If both the modern and the legacy folder of an app are inside the
  /// picked folder, keep the modern one: that is where the app writes now.
  static List<MediaSource> _onePerApp(List<MediaSource> sources) {
    final seen = <ChatApp>{};
    return [
      for (final s in sources)
        if (seen.add(s.app)) s,
    ];
  }

  static Future<String?> _descend(
    MediaStorage storage,
    String treeUri,
    String fromId,
    List<String> names,
  ) async {
    var current = fromId;
    for (final name in names) {
      final List<StorageEntry> children;
      try {
        children = await storage.listChildren(treeUri, current);
      } on StorageException {
        return null;
      }
      final next = children
          .where((c) => c.isDirectory && c.name == name)
          .firstOrNull;
      if (next == null) return null;
      current = next.id;
    }
    return current;
  }

  static Future<bool> _looksLikeMediaFolder(
    MediaStorage storage,
    PickedFolder picked,
  ) async {
    final children = await storage.listChildren(
      picked.treeUri,
      picked.treeDocId,
    );
    return children.any(
      (c) =>
          c.isDirectory &&
          (c.name.startsWith('WhatsApp ') || c.name == '.Statuses'),
    );
  }

  static ChatApp _guessApp(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('com.whatsapp.w4b') ||
        lower.contains('whatsapp business')) {
      return ChatApp.whatsappBusiness;
    }
    if (lower.contains('whatsapp')) return ChatApp.whatsapp;
    return ChatApp.other;
  }

  static String _trimSlashes(String path) {
    var p = path;
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
