import '../../media/domain/media_file.dart';

/// A file the user opened in the app, and when.
final class RecentFile {
  const RecentFile({required this.file, required this.openedAt});

  final MediaFile file;

  /// In UTC.
  final DateTime openedAt;

  @override
  bool operator ==(Object other) =>
      other is RecentFile && other.file == file && other.openedAt == openedAt;

  @override
  int get hashCode => Object.hash(file, openedAt);
}

/// Starred files and folders, and the files opened most recently.
final class Places {
  const Places({this.favourites = const [], this.recent = const []});

  static const empty = Places();

  /// The longest recent list kept.
  static const maxRecent = 30;

  /// Files and folders ([MediaFile.isFolder]), in the order they were
  /// starred.
  final List<MediaFile> favourites;

  /// Most recent first, one entry per file.
  final List<RecentFile> recent;

  bool isFavourite(MediaFile item) => favourites.any((f) => f.key == item.key);

  Places toggleFavourite(MediaFile item) => Places(
    favourites: isFavourite(item)
        ? [
            for (final f in favourites)
              if (f.key != item.key) f,
          ]
        : [...favourites, item],
    recent: recent,
  );

  Places opened(MediaFile file, DateTime at) => Places(
    favourites: favourites,
    recent: [
      RecentFile(file: file, openedAt: at.toUtc()),
      for (final r in recent)
        if (r.file.key != file.key) r,
    ].take(maxRecent).toList(),
  );

  /// Forgets items that are gone (trashed or moved) by their keys.
  Places without(Set<String> keys) => Places(
    favourites: [
      for (final f in favourites)
        if (!keys.contains(f.key)) f,
    ],
    recent: [
      for (final r in recent)
        if (!keys.contains(r.file.key)) r,
    ],
  );

  /// Swaps an item for its renamed or moved self.
  Places replace(String oldKey, MediaFile item) => Places(
    favourites: [for (final f in favourites) f.key == oldKey ? item : f],
    recent: [
      for (final r in recent)
        r.file.key == oldKey ? RecentFile(file: item, openedAt: r.openedAt) : r,
    ],
  );

  Places clearRecent() => Places(favourites: favourites);
}

abstract interface class PlacesStore {
  Future<Places> load();
  Future<void> save(Places places);
}
