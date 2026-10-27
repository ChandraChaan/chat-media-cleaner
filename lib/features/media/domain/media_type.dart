/// What kind of chat media a file is, decided by the folder it lives in.
enum MediaType {
  video,
  image,
  voiceNote,
  audio,
  document,
  sticker,
  gif,
  status,
  other,
}

/// Maps a file's path inside a chat app's `Media` folder to a [MediaType].
///
/// WhatsApp keeps each kind of media in its own folder, for example
/// `WhatsApp Images`, `WhatsApp Video` or `WhatsApp Voice Notes`.
/// WhatsApp Business uses the same names with `WhatsApp Business` in front.
/// Files you sent are kept in a `Sent` sub-folder.
abstract final class MediaClassifier {
  static const _folderTypes = <String, MediaType>{
    'images': MediaType.image,
    'profile photos': MediaType.image,
    'video': MediaType.video,
    'video notes': MediaType.video,
    'animated gifs': MediaType.gif,
    'voice notes': MediaType.voiceNote,
    'audio': MediaType.audio,
    'documents': MediaType.document,
    'stickers': MediaType.sticker,
    '.statuses': MediaType.status,
  };

  static const _prefixes = ['whatsapp business ', 'whatsapp '];

  /// The type of the file at [relativePath] (segments separated by `/`,
  /// relative to the `Media` folder). Falls back to [mimeType] for files
  /// outside the known folders.
  static MediaType classify(String relativePath, {String? mimeType}) {
    final segments = relativePath.split('/');
    if (segments.length > 1) {
      final type = _folderTypes[_normalizeFolder(segments.first)];
      if (type != null) return type;
    }
    return _fromMime(mimeType);
  }

  /// Whether the file is a copy of something you sent (it sits in a `Sent`
  /// folder below the media type folder).
  static bool isSent(String relativePath) {
    final segments = relativePath.split('/');
    for (var i = 1; i < segments.length - 1; i++) {
      if (segments[i].toLowerCase() == 'sent') return true;
    }
    return false;
  }

  /// Whether a file should be left out of a scan entirely: Android and
  /// WhatsApp housekeeping files rather than media.
  static bool isIgnoredFile(String name) =>
      name == '.nomedia' || name.startsWith('.trashed-');

  static String _normalizeFolder(String folder) {
    final lower = folder.toLowerCase();
    for (final prefix in _prefixes) {
      if (lower.startsWith(prefix)) return lower.substring(prefix.length);
    }
    return lower;
  }

  static MediaType _fromMime(String? mimeType) {
    if (mimeType == null) return MediaType.other;
    if (mimeType == 'image/gif') return MediaType.gif;
    if (mimeType == 'image/webp') return MediaType.sticker;
    if (mimeType.startsWith('image/')) return MediaType.image;
    if (mimeType.startsWith('video/')) return MediaType.video;
    if (mimeType.startsWith('audio/')) return MediaType.audio;
    if (mimeType.startsWith('application/') || mimeType.startsWith('text/')) {
      return MediaType.document;
    }
    return MediaType.other;
  }
}

extension MediaTypeTraits on MediaType {
  /// Whether a picture of the file can be shown (photo, video frame,
  /// sticker or GIF).
  bool get hasPicture => switch (this) {
    MediaType.video ||
    MediaType.image ||
    MediaType.sticker ||
    MediaType.gif ||
    MediaType.status => true,
    MediaType.voiceNote ||
    MediaType.audio ||
    MediaType.document ||
    MediaType.other => false,
  };
}
