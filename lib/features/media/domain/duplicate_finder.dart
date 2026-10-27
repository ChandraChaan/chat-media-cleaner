import 'cancel_token.dart';
import 'media_file.dart';
import 'media_storage.dart';

/// Files with exactly the same content in one chat media folder, oldest
/// first. The oldest is the one to keep.
final class DuplicateSet {
  DuplicateSet(List<MediaFile> files)
    : files = List<MediaFile>.unmodifiable(
        <MediaFile>[...files]..sort(oldestFirst),
      );

  final List<MediaFile> files;

  MediaFile get keep => files.first;

  /// The extra copies: everything except the oldest.
  List<MediaFile> get copies => files.sublist(1);

  /// Space the extra copies take.
  int get wastedBytes => copies.fold(0, (sum, f) => sum + f.size);

  /// This set limited to the files still in [present] (by key, using the
  /// current version of each file), or null when fewer than two are left.
  DuplicateSet? within(Map<String, MediaFile> present) {
    final remaining = [for (final f in files) ?present[f.key]];
    return remaining.length < 2 ? null : DuplicateSet(remaining);
  }

  static int oldestFirst(MediaFile a, MediaFile b) {
    final byDate = a.modified.compareTo(b.modified);
    return byDate != 0 ? byDate : a.relativePath.compareTo(b.relativePath);
  }
}

/// Finds exact duplicates: files of the same size are hashed (SHA-256, on
/// the platform side) and grouped by hash. Only files in the same source
/// are compared, so WhatsApp and WhatsApp Business each keep their own copy.
final class DuplicateFinder {
  const DuplicateFinder(this._storage, {this.parallel = 2});

  final MediaStorage _storage;

  /// How many files are hashed at the same time.
  final int parallel;

  /// The files that need hashing: those sharing their size with another
  /// file of the same source. Empty files are never duplicates worth
  /// showing.
  static List<MediaFile> candidates(List<MediaFile> files) {
    final bySize = <(String, int), List<MediaFile>>{};
    for (final f in files) {
      if (f.size > 0) (bySize[(f.sourceId, f.size)] ??= []).add(f);
    }
    return [
      for (final group in bySize.values)
        if (group.length > 1) ...group,
    ];
  }

  /// Duplicate sets among [files], most wasted space first. Files that
  /// can't be read are left out.
  Future<List<DuplicateSet>> find(
    List<MediaFile> files, {
    CancelToken? cancel,
    void Function(int hashed, int total)? onProgress,
  }) async {
    final toHash = candidates(files);
    onProgress?.call(0, toHash.length);
    final hashes = <MediaFile, String>{};
    var next = 0;
    var hashed = 0;

    Future<void> worker() async {
      while (next < toHash.length) {
        cancel?.throwIfCancelled();
        final file = toHash[next++];
        try {
          hashes[file] = await _storage.hashFile(file.sourceId, file.id);
        } on StorageException {
          // Gone or unreadable since the listing: not a duplicate we can
          // vouch for.
        }
        onProgress?.call(++hashed, toHash.length);
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    cancel?.throwIfCancelled();

    final byContent = <(String, int, String), List<MediaFile>>{};
    for (final MapEntry(key: file, value: hash) in hashes.entries) {
      (byContent[(file.sourceId, file.size, hash)] ??= []).add(file);
    }
    return [
      for (final group in byContent.values)
        if (group.length > 1) DuplicateSet(group),
    ]..sort((a, b) {
      final byWaste = b.wastedBytes.compareTo(a.wastedBytes);
      return byWaste != 0
          ? byWaste
          : a.keep.relativePath.compareTo(b.keep.relativePath);
    });
  }
}
