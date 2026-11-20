import '../../media/domain/duplicate_finder.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_scanner.dart';
import 'file_category.dart';

/// Space and file count of one [FileCategory].
final class CategoryUsage {
  const CategoryUsage({this.count = 0, this.bytes = 0});

  final int count;
  final int bytes;
}

/// What a storage scan found: space used by each kind of file, the largest
/// files and exact duplicates, across everything the app can read.
final class StorageReport {
  StorageReport._({
    required this.files,
    required this.usage,
    required this.largest,
    required this.duplicates,
    required this.skippedFolders,
  });

  /// Files at least this big are "large".
  static const largeFileBytes = 10 * 1000 * 1000;

  /// The longest list of large files shown.
  static const maxLargest = 200;

  /// Builds the report from the files of a scan. Files in the app's own
  /// trash are left out: they are already on their way out.
  factory StorageReport.from(
    List<MediaFile> scanned, {
    List<DuplicateSet> duplicates = const [],
    int skippedFolders = 0,
  }) {
    final files = [
      for (final f in scanned)
        if (!isInAppTrash(f.relativePath)) f,
    ];
    final counts = <FileCategory, int>{};
    final bytes = <FileCategory, int>{};
    for (final f in files) {
      final category = FileCategories.of(f.name, mimeType: f.mimeType);
      counts[category] = (counts[category] ?? 0) + 1;
      bytes[category] = (bytes[category] ?? 0) + f.size;
    }
    final big = [
      for (final f in files)
        if (f.size >= largeFileBytes) f,
    ]..sort((a, b) => b.size.compareTo(a.size));
    final largest = big.take(maxLargest).toList();
    final present = {for (final f in files) f.key: f};
    return StorageReport._(
      files: List.unmodifiable(files),
      usage: {
        for (final c in FileCategory.values)
          c: CategoryUsage(count: counts[c] ?? 0, bytes: bytes[c] ?? 0),
      },
      largest: List.unmodifiable(largest),
      duplicates: List.unmodifiable([
        for (final set in duplicates) ?set.within(present),
      ]),
      skippedFolders: skippedFolders,
    );
  }

  /// Every file found, outside the app's trash.
  final List<MediaFile> files;
  final Map<FileCategory, CategoryUsage> usage;

  /// Files of [largeFileBytes] or more, biggest first.
  final List<MediaFile> largest;
  final List<DuplicateSet> duplicates;

  /// Folders that could not be read (for example `Android/data`).
  final int skippedFolders;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);

  /// The extra copies of every duplicate set; the oldest copy is kept.
  List<MediaFile> get duplicateCopies => [
    for (final set in duplicates) ...set.copies,
  ];

  int get duplicateBytes =>
      duplicates.fold(0, (sum, set) => sum + set.wastedBytes);

  /// Files of [category], biggest first.
  List<MediaFile> ofCategory(FileCategory category) => [
    for (final f in files)
      if (FileCategories.of(f.name, mimeType: f.mimeType) == category) f,
  ]..sort((a, b) => b.size.compareTo(a.size));

  /// The report without the files whose [MediaFile.key] is in [keys], after
  /// they were moved to the trash.
  StorageReport without(Set<String> keys) => StorageReport.from(
    [
      for (final f in files)
        if (!keys.contains(f.key)) f,
    ],
    duplicates: duplicates,
    skippedFolders: skippedFolders,
  );

  /// Whether [relativePath] is inside a trash folder of this app.
  static bool isInAppTrash(String relativePath) =>
      relativePath.startsWith('${MediaScanner.trashFolderName}/') ||
      relativePath.contains('/${MediaScanner.trashFolderName}/');
}
