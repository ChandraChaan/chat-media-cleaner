import 'media_type.dart';

/// One file found in a chat app's media folder.
///
/// [id] and [parentId] are opaque storage ids (Storage Access Framework
/// document ids on Android). [relativePath] is the path below the `Media`
/// folder, for example `WhatsApp Images/Sent/IMG-20240101-WA0001.jpg`.
final class MediaFile {
  const MediaFile({
    required this.id,
    required this.sourceId,
    required this.parentId,
    required this.name,
    required this.relativePath,
    required this.size,
    required this.modified,
    required this.type,
    this.isSent = false,
    this.mimeType,
  });

  final String id;

  /// The [MediaSource] (granted folder) this file was found in.
  final String sourceId;
  final String parentId;
  final String name;
  final String relativePath;

  /// Size in bytes.
  final int size;

  /// Last modified time, in UTC.
  final DateTime modified;
  final MediaType type;
  final bool isSent;
  final String? mimeType;

  /// Unique across all sources; use it for selection and list keys.
  String get key => '$sourceId|$id';

  /// The folder the file is in, relative to the `Media` folder.
  String get folder {
    final slash = relativePath.lastIndexOf('/');
    return slash < 0 ? '' : relativePath.substring(0, slash);
  }

  MediaFile copyWith({
    String? id,
    String? parentId,
    String? name,
    String? relativePath,
    int? size,
    DateTime? modified,
    MediaType? type,
    bool? isSent,
  }) => MediaFile(
    id: id ?? this.id,
    sourceId: sourceId,
    parentId: parentId ?? this.parentId,
    name: name ?? this.name,
    relativePath: relativePath ?? this.relativePath,
    size: size ?? this.size,
    modified: modified ?? this.modified,
    type: type ?? this.type,
    isSent: isSent ?? this.isSent,
    mimeType: mimeType,
  );

  @override
  bool operator ==(Object other) =>
      other is MediaFile &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.parentId == parentId &&
      other.name == name &&
      other.relativePath == relativePath &&
      other.size == size &&
      other.modified == modified &&
      other.type == type &&
      other.isSent == isSent &&
      other.mimeType == mimeType;

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    parentId,
    name,
    relativePath,
    size,
    modified,
    type,
    isSent,
    mimeType,
  );

  @override
  String toString() => 'MediaFile($relativePath, $size B)';
}
