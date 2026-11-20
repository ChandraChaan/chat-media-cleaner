import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../access/presentation/access_screen.dart';
import '../../access/presentation/storage_access_controller.dart';
import '../../home/presentation/home_actions.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_source.dart';
import '../../places/presentation/places_controller.dart';
import '../../review/presentation/media_tile.dart';
import '../../review/presentation/review_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../storage/domain/file_category.dart';
import '../../storage/presentation/file_list_screen.dart';
import '../../storage/presentation/storage_screen.dart';
import '../../viewer/presentation/viewer_screen.dart';
import '../domain/browse_entry.dart';
import 'browse_controller.dart';
import 'folder_screen.dart';

/// The Files tab: storage volumes (with all-files access) or the folders
/// the user chose, kinds of files, storage tools, favourites and recent
/// files.
class BrowseHome extends ConsumerWidget {
  const BrowseHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sources = ref.watch(
      settingsControllerProvider.select((s) => s.value?.sources ?? const []),
    );
    final access = ref.watch(allFilesAccessControllerProvider);
    final granted = access.value ?? false;
    final volumes = ref.watch(storageVolumesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filesTitle),
        actions: const [TrashButton(), SettingsButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (granted)
              for (final volume in volumes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: VolumeUsageCard(
                    volume: volume,
                    onTap: () => openFolder(
                      context,
                      BrowseLocation.root(MediaSource.volume(volume)),
                    ),
                  ),
                )
            else if (access.hasValue)
              const _AllFilesCard()
            else
              Text(
                l10n.filesIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            SectionTitle(l10n.chosenFoldersTitle),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SourceCard(source: source),
              ),
            ListTile(
              key: const Key('files-add-folder'),
              leading: const Icon(Icons.add),
              title: Text(l10n.addFolder),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AccessScreen(pushed: true),
                ),
              ),
            ),
            const _Favourites(),
            const _Recent(),
            SectionTitle(l10n.categoriesTitle),
            const _Categories(),
            SectionTitle(l10n.toolsTitle),
            Card.outlined(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('open-storage'),
                    leading: const Icon(Icons.pie_chart_outline),
                    title: Text(l10n.storageTitle),
                    subtitle: Text(l10n.storageSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openStorageScreen(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.straighten),
                    title: Text(l10n.largeFilesTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openFileList(context, const LargeFiles()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.content_copy),
                    title: Text(l10n.duplicateFilesTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openFileList(context, const DuplicateFiles()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains all-files access and asks for it. Without it the app keeps
/// working in the folders the user chose.
class _AllFilesCard extends ConsumerWidget {
  const _AllFilesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.allFilesTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.allFilesBody),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('allow-all-files'),
              onPressed: () => requestAllFiles(context, ref),
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.allowAllFiles),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.allFilesWithout,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for all-files access; once granted, finds the chat apps' folders
/// on their own, so cleaning up needs no folder picking.
Future<void> requestAllFiles(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final granted = await ref
      .read(allFilesAccessControllerProvider.notifier)
      .request();
  if (!context.mounted) return;
  if (!granted) {
    showMessage(context, l10n.allFilesDeclined);
    return;
  }
  final settings = ref.read(settingsControllerProvider.notifier);
  await settings.addDetectedFolders();
  if (!context.mounted) return;
  showMessage(context, l10n.allFilesGranted);
}

class _Categories extends StatelessWidget {
  const _Categories();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in FileCategory.values)
          if (category != FileCategory.other)
            ActionChip(
              key: Key('home-category-${category.name}'),
              avatar: Icon(category.icon, color: scheme.primary),
              label: Text(category.label(l10n)),
              onPressed: () => openFileList(context, CategoryFiles(category)),
            ),
      ],
    );
  }
}

class _Favourites extends ConsumerWidget {
  const _Favourites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favourites =
        ref.watch(placesControllerProvider).value?.favourites ?? const [];
    if (favourites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.favouritesTitle),
        Card.outlined(
          child: Column(
            children: [
              for (final item in favourites)
                _PlaceTile(key: ValueKey('fav-${item.key}'), item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent();

  /// How many recent files the home screen shows; the rest are a tap away.
  static const _shown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recent =
        ref.watch(placesControllerProvider).value?.recent ?? const [];
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.recentTitle),
        Card.outlined(
          child: Column(
            children: [
              for (final r in recent.take(_shown))
                _PlaceTile(key: ValueKey('recent-${r.file.key}'), item: r.file),
              if (recent.length > _shown)
                ListTile(
                  key: const Key('see-all-recent'),
                  title: Text(l10n.seeAll),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openFileList(context, const RecentFiles()),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A favourite or recent file or folder. Opens it when its folder can
/// still be reached.
class _PlaceTile extends ConsumerWidget {
  const _PlaceTile({required this.item, super.key});

  final MediaFile item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final source = ref.watch(
      knownSourcesProvider.select(
        (all) => all.where((s) => s.id == item.sourceId).firstOrNull,
      ),
    );
    final where = [
      ?source?.label(l10n),
      item.folder,
    ].where((p) => p.isNotEmpty).join(' › ').replaceAll('/', ' › ');
    final category = FileCategories.of(item.name, mimeType: item.mimeType);
    return ListTile(
      enabled: source != null,
      leading: SizedBox.square(
        dimension: 48,
        child: item.isFolder
            ? Icon(
                Icons.folder_special,
                color: Theme.of(context).colorScheme.primary,
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    category == FileCategory.images ||
                        category == FileCategory.videos
                    ? FileThumbnail(fileRef: item.ref, type: item.type)
                    : Icon(category.icon),
              ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        source == null
            ? l10n.placeUnavailable
            : item.isFolder
            ? where
            : '$where\n${formatBytes(item.size, locale)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: source == null
          ? null
          : () => item.isFolder
                ? openFolder(context, BrowseLocation.ofFolder(source, item))
                : openViewer(context, files: [item], index: 0),
    );
  }
}

class _SourceCard extends ConsumerWidget {
  const _SourceCard({required this.source});

  final MediaSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final stats = ref.watch(
      folderStatsProvider.select((s) => s[FolderStats.keyOf(source.id, '')]),
    );
    final path = SourceLocator.pathOf(
      source.rootId,
    ).replaceFirst(RegExp('^/'), '').replaceAll('/', ' › ');
    return Card.outlined(
      child: ListTile(
        key: ValueKey('source-${source.id}'),
        leading: Icon(
          Icons.folder,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(source.label(l10n)),
        subtitle: Text(
          [
            if (path.isNotEmpty) path,
            if (stats != null)
              l10n.folderStats(
                stats.count,
                formatCount(stats.count, locale),
                formatBytes(stats.bytes, locale),
              ),
          ].join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openFolder(context, BrowseLocation.root(source)),
      ),
    );
  }
}
