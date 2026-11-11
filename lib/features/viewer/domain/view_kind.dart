/// How the app can show a file by itself.
enum ViewKind {
  /// Photos, stickers and animated images.
  image,
  video,
  audio,
  pdf,

  /// Plain text of any flavour: notes, contacts, CSV, JSON, logs.
  text,

  /// Nothing the app can draw; it is handed to another app.
  other,
}

/// Decides the [ViewKind] of a file from its MIME type and, because chat
/// apps and file providers often report a vague type, its extension.
abstract final class ViewKinds {
  static const _imageExt = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
  };
  static const _videoExt = {'mp4', 'm4v', '3gp', 'mkv', 'webm', 'mov'};
  static const _audioExt = {
    'opus',
    'ogg',
    'oga',
    'mp3',
    'm4a',
    'aac',
    'wav',
    'amr',
    'flac',
  };
  static const _textExt = {
    'txt',
    'csv',
    'tsv',
    'json',
    'xml',
    'log',
    'md',
    'vcf',
    'ics',
    'html',
    'htm',
    'yaml',
    'yml',
    'srt',
    'ini',
    'conf',
  };
  static const _textMimes = {
    'application/json',
    'application/xml',
    'application/x-yaml',
    'application/x-subrip',
  };

  static ViewKind of({required String name, String? mimeType}) {
    final ext = extensionOf(name);
    // The extension wins where it is clear: WhatsApp's "GIFs" are MP4
    // files and its voice notes are sometimes typed application/ogg.
    if (ext == 'pdf') return ViewKind.pdf;
    if (_imageExt.contains(ext)) return ViewKind.image;
    if (_videoExt.contains(ext)) return ViewKind.video;
    if (_audioExt.contains(ext)) return ViewKind.audio;
    if (_textExt.contains(ext)) return ViewKind.text;

    final mime = mimeType?.toLowerCase();
    if (mime == null) return ViewKind.other;
    if (mime == 'application/pdf') return ViewKind.pdf;
    if (mime.startsWith('image/')) return ViewKind.image;
    if (mime.startsWith('video/')) return ViewKind.video;
    if (mime.startsWith('audio/') || mime == 'application/ogg') {
      return ViewKind.audio;
    }
    if (mime.startsWith('text/') || _textMimes.contains(mime)) {
      return ViewKind.text;
    }
    return ViewKind.other;
  }

  /// The lowercase extension without the dot, or '' when there is none.
  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}
