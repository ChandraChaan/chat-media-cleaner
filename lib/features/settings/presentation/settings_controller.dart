import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../media/domain/media_source.dart';
import '../../media/domain/media_storage.dart';
import '../domain/app_settings.dart';

/// What happened when the user tried to add a folder.
sealed class AddFolderResult {
  const AddFolderResult();
}

final class FolderAdded extends AddFolderResult {
  const FolderAdded(this.sources);

  final List<MediaSource> sources;
}

final class FolderPickCancelled extends AddFolderResult {
  const FolderPickCancelled();
}

final class FolderNotChatMedia extends AddFolderResult {
  const FolderNotChatMedia();
}

final class FolderPickFailed extends AddFolderResult {
  const FolderPickFailed();
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

final class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final settings = await ref.read(settingsStoreProvider).load();
    // Drop folders whose access was removed outside the app (for example in
    // system settings); the user is asked to choose them again.
    final granted = (await ref.read(folderAccessProvider).grantedFolders())
        .toSet();
    final kept = settings.sources
        .where((s) => granted.contains(s.treeUri))
        .toList();
    if (kept.length == settings.sources.length) return settings;
    final updated = settings.copyWith(sources: kept);
    await ref.read(settingsStoreProvider).save(updated);
    return updated;
  }

  /// Opens the system folder picker for [app] and adds what was picked.
  Future<AddFolderResult> addFolder(ChatApp app) async {
    final access = ref.read(folderAccessProvider);
    final PickedFolder? picked;
    try {
      final sdk = await access.sdkInt();
      picked = await access.pickFolder(
        initialDocId: SourceLocator.initialDocId(app, sdk),
      );
    } on StorageException {
      return const FolderPickFailed();
    }
    if (picked == null) return const FolderPickCancelled();

    final List<MediaSource> found;
    try {
      found = await SourceLocator.resolve(
        ref.read(mediaStorageProvider),
        picked,
      );
    } on NotAChatMediaFolder {
      await _releaseIfUnused(picked.treeUri, await future);
      return const FolderNotChatMedia();
    } on StorageException {
      await _releaseIfUnused(picked.treeUri, await future);
      return const FolderPickFailed();
    }

    final current = await future;
    final roots = {for (final s in found) s.rootId};
    final replaced = current.sources
        .where((s) => roots.contains(s.rootId))
        .map((s) => s.treeUri)
        .toSet();
    final sources = [
      ...current.sources.where((s) => !roots.contains(s.rootId)),
      ...found,
    ]..sort((a, b) => a.app.index.compareTo(b.app.index));
    await _save(current.copyWith(sources: sources));
    // A folder picked again gets a new grant; let go of the old one.
    for (final tree in replaced) {
      await _releaseIfUnused(tree, state.requireValue);
    }
    return FolderAdded(found);
  }

  Future<void> removeSource(MediaSource source) async {
    final current = await future;
    final updated = current.copyWith(
      sources: current.sources.where((s) => s != source).toList(),
    );
    await _save(updated);
    await _releaseIfUnused(source.treeUri, updated);
  }

  Future<void> setTrashDays(int days) async =>
      _save((await future).copyWith(trashDays: days));

  Future<void> setOldAfterMonths(int months) async =>
      _save((await future).copyWith(oldAfterMonths: months));

  Future<void> addFreedBytes(int bytes) async {
    if (bytes <= 0) return;
    final current = await future;
    await _save(current.copyWith(freedBytes: current.freedBytes + bytes));
  }

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsStoreProvider).save(settings);
    if (!ref.mounted) return;
    state = AsyncData(settings);
  }

  Future<void> _releaseIfUnused(String treeUri, AppSettings settings) async {
    if (settings.sources.any((s) => s.treeUri == treeUri)) return;
    await ref.read(folderAccessProvider).releaseFolder(treeUri);
  }
}
