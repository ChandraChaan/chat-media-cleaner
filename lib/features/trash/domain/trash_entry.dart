import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';

/// A file in the app's trash, with everything needed to put it back.
final class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.sourceId,
    required this.originalId,
    required this.originalParentId,
    required this.relativePath,
    required this.name,
    required this.size,
    required this.modified,
    required this.type,
    required this.trashedAt,
    required this.item,
    this.isSent = false,
    this.mimeType,
  });

  factory TrashEntry.fromFile(
    MediaFile file, {
    required String id,
    required DateTime trashedAt,
    required TrashedItem item,
  }) => TrashEntry(
    id: id,
    sourceId: file.sourceId,
    originalId: file.id,
    originalParentId: file.parentId,
    relativePath: file.relativePath,
    name: file.name,
    size: file.size,
    modified: file.modified,
    type: file.type,
    trashedAt: trashedAt.toUtc(),
    item: item,
    isSent: file.isSent,
    mimeType: file.mimeType,
  );

  /// Also the name of the item folder inside the trash.
  final String id;
  final String sourceId;

  /// The file's id before it was moved to the trash.
  final String originalId;
  final String originalParentId;

  /// Where the file was, relative to the `Media` folder.
  final String relativePath;
  final String name;
  final int size;

  /// The file's original modified time, in UTC.
  final DateTime modified;
  final MediaType type;

  /// When it was moved to the trash, in UTC.
  final DateTime trashedAt;
  final TrashedItem item;
  final bool isSent;
  final String? mimeType;

  /// The [MediaFile.key] the file had before it was trashed.
  String get originalKey => '$sourceId|$originalId';

  DateTime expiresAt(Duration retention) => trashedAt.add(retention);

  bool isExpired(DateTime now, Duration retention) =>
      !now.toUtc().isBefore(expiresAt(retention));

  /// The file as it is after being put back as [restored].
  MediaFile toRestoredFile(RestoredFile restored) {
    final slash = relativePath.lastIndexOf('/');
    final folder = slash < 0 ? '' : relativePath.substring(0, slash + 1);
    return MediaFile(
      id: restored.fileId,
      sourceId: sourceId,
      parentId: originalParentId,
      name: restored.name,
      relativePath: '$folder${restored.name}',
      size: size,
      modified: modified,
      type: type,
      isSent: isSent,
      mimeType: mimeType,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'originalId': originalId,
    'originalParentId': originalParentId,
    'relativePath': relativePath,
    'name': name,
    'size': size,
    'modified': modified.millisecondsSinceEpoch,
    'type': type.name,
    'trashedAt': trashedAt.millisecondsSinceEpoch,
    'itemDirId': item.itemDirId,
    'fileId': item.fileId,
    'isSent': isSent,
    'mimeType': mimeType,
  };

  static TrashEntry fromJson(Map<String, Object?> json) => TrashEntry(
    id: json['id']! as String,
    sourceId: json['sourceId']! as String,
    originalId: json['originalId']! as String,
    originalParentId: json['originalParentId']! as String,
    relativePath: json['relativePath']! as String,
    name: json['name']! as String,
    size: json['size']! as int,
    modified: DateTime.fromMillisecondsSinceEpoch(
      json['modified']! as int,
      isUtc: true,
    ),
    type: MediaType.values.asNameMap()[json['type']] ?? MediaType.other,
    trashedAt: DateTime.fromMillisecondsSinceEpoch(
      json['trashedAt']! as int,
      isUtc: true,
    ),
    item: TrashedItem(
      itemDirId: json['itemDirId']! as String,
      fileId: json['fileId']! as String,
    ),
    isSent: json['isSent'] as bool? ?? false,
    mimeType: json['mimeType'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is TrashEntry &&
      other.id == id &&
      other.sourceId == sourceId &&
      other.item.fileId == item.fileId &&
      other.item.itemDirId == item.itemDirId &&
      other.trashedAt == trashedAt;

  @override
  int get hashCode =>
      Object.hash(id, sourceId, item.fileId, item.itemDirId, trashedAt);
}
