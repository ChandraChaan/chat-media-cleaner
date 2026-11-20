/// Broad kinds of files, the way a file manager groups storage: by what a
/// file is, wherever it lives.
enum FileCategory { images, videos, audio, documents, archives, apps, other }

abstract final class FileCategories {
  static const _images = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp', 'dng', //
    'avif', 'svg', 'tif', 'tiff',
  };
  static const _videos = {
    'mp4', 'mkv', 'webm', '3gp', '3gpp', 'mov', 'avi', 'm4v', 'ts', 'wmv', //
    'flv', 'mpg', 'mpeg',
  };
  static const _audio = {
    'mp3', 'm4a', 'aac', 'opus', 'ogg', 'oga', 'wav', 'flac', 'amr', 'mid', //
    'midi', 'wma', '3ga',
  };
  static const _documents = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', //
    'txt', 'rtf', 'csv', 'md', 'json', 'xml', 'html', 'htm', 'epub', 'vcf',
    'log',
  };
  static const _archives = {
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', //
  };
  static const _apps = {'apk', 'apks', 'xapk', 'apkm'};

  /// The category of a file called [name], from its extension, or from
  /// [mimeType] when the extension says nothing.
  static FileCategory of(String name, {String? mimeType}) {
    final dot = name.lastIndexOf('.');
    final ext = dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (_images.contains(ext)) return FileCategory.images;
    if (_videos.contains(ext)) return FileCategory.videos;
    if (_audio.contains(ext)) return FileCategory.audio;
    if (_documents.contains(ext)) return FileCategory.documents;
    if (_archives.contains(ext)) return FileCategory.archives;
    if (_apps.contains(ext)) return FileCategory.apps;
    final mime = mimeType ?? '';
    if (mime.startsWith('image/')) return FileCategory.images;
    if (mime.startsWith('video/')) return FileCategory.videos;
    if (mime.startsWith('audio/')) return FileCategory.audio;
    if (mime.startsWith('text/') || mime == 'application/pdf') {
      return FileCategory.documents;
    }
    if (mime == 'application/zip') return FileCategory.archives;
    if (mime == 'application/vnd.android.package-archive') {
      return FileCategory.apps;
    }
    return FileCategory.other;
  }

  /// Whether [name] is a ZIP archive the app can unpack.
  static bool isZip(String name) => name.toLowerCase().endsWith('.zip');
}
