import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../media/domain/media_file.dart';
import '../domain/places.dart';

/// Favourite files and folders, and recently opened files.
final placesControllerProvider =
    AsyncNotifierProvider<PlacesController, Places>(PlacesController.new);

final class PlacesController extends AsyncNotifier<Places> {
  @override
  Future<Places> build() => ref.read(placesStoreProvider).load();

  /// Stars [item], or takes its star away.
  Future<void> toggleFavourite(MediaFile item) async =>
      _save((await future).toggleFavourite(item));

  /// Remembers that [file] was just opened.
  Future<void> opened(MediaFile file) async {
    if (file.isFolder) return;
    await _save((await future).opened(file, ref.read(clockProvider)()));
  }

  /// Forgets items that were moved to the trash.
  Future<void> forget(Set<String> keys) async {
    final current = await future;
    final updated = current.without(keys);
    if (updated.favourites.length != current.favourites.length ||
        updated.recent.length != current.recent.length) {
      await _save(updated);
    }
  }

  /// Follows an item that was renamed or moved.
  Future<void> replace(String oldKey, MediaFile item) async =>
      _save((await future).replace(oldKey, item));

  Future<void> clearRecent() async => _save((await future).clearRecent());

  Future<void> _save(Places places) async {
    if (ref.mounted) state = AsyncData(places);
    await ref.read(placesStoreProvider).save(places);
  }
}
