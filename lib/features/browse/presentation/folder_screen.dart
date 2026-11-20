import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_type.dart';
import '../../places/presentation/places_controller.dart';
import '../../review/presentation/media_tile.dart';
import '../../review/presentation/review_controller.dart';
import '../../storage/domain/file_category.dart';
import '../../viewer/domain/view_kind.dart';
import '../../viewer/presentation/file_actions.dart';
import '../../viewer/presentation/viewer_screen.dart';
import '../domain/browse_entry.dart';
import '../domain/file_clipboard.dart';
import 'browse_controller.dart';
import 'file_manager_actions.dart';
import 'item_details.dart';
import 'rename_dialog.dart';

void openFolder(BuildContext context, BrowseLocation location) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FolderScreen(location: location)),
  );
}

enum ItemAction {
  openWith,
  share,
  copy,
  move,
  rename,
  compress,
  extract,
  favourite,
  details,
  trash,
}

enum _FolderMenu { newFolder, showHidden, favourite, details }

enum _SelectionMenu { rename, compress, favourite, details }

/// One folder: its sub-folders and files, with search (here or in every
/// sub-folder), a type filter, sorting, a list or grid, and actions on one
/// item or a selection of files and folders.
class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({required this.location, super.key});

  final BrowseLocation location;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  bool _deep = false;
  String _query = '';
  Set<String> _selected = const {};

  BrowseLocation get _location => widget.location;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(MediaFile item) => setState(
    () => _selected = _selected.contains(item.key)
        ? ({..._selected}..remove(item.key))
        : {..._selected, item.key},
  );

  void _clearSelection() => setState(() => _selected = const {});

  void _closeSearch() => setState(() {
    _searching = false;
    _deep = false;
    _query = '';
    _search.clear();
  });

  /// The folder as an item, for starring it or showing its details.
  MediaFile? get _self {
    if (_location.isRoot) return null;
    final names = _location.path;
    final parentPath = names.sublist(0, names.length - 1).join('/');
    return MediaFile(
      id: _location.dirId,
      sourceId: _location.source.id,
      parentId: '',
      name: names.last,
      relativePath: parentPath.isEmpty
          ? names.last
          : '$parentPath/${names.last}',
      size: 0,
      modified: DateTime.utc(1970),
      type: MediaType.other,
      mimeType: MediaFile.folderMimeType,
    );
  }

  Future<void> _onItemAction(ItemAction action, MediaFile item) async {
    switch (action) {
      case ItemAction.openWith:
        await openWith(context, ref, item);
      case ItemAction.share:
        await shareFiles(context, ref, [item]);
      case ItemAction.copy:
        copyToClipboard(context, ref, ClipboardMode.copy, [item]);
      case ItemAction.move:
        copyToClipboard(context, ref, ClipboardMode.move, [item]);
      case ItemAction.rename:
        await _rename(item);
      case ItemAction.compress:
        await compressItems(context, ref, _location, [item]);
      case ItemAction.extract:
        await extractArchive(context, ref, item);
      case ItemAction.favourite:
        await toggleFavourite(context, ref, item);
      case ItemAction.details:
        await showItemDetails(context, item);
      case ItemAction.trash:
        await trashItems(context, ref, [item]);
    }
  }

  Future<void> _rename(MediaFile item) async {
    final renamed = await showRenameDialog(context, item);
    if (renamed == null || renamed.name == item.name || !mounted) return;
    showMessage(context, context.l10n.renamed(renamed.name));
  }

  Future<void> _onFolderMenu(_FolderMenu action) async {
    switch (action) {
      case _FolderMenu.newFolder:
        await _newFolder();
      case _FolderMenu.showHidden:
        ref.read(showHiddenProvider.notifier).toggle();
      case _FolderMenu.favourite:
        if (_self case final self?) await toggleFavourite(context, ref, self);
      case _FolderMenu.details:
        if (_self case final self?) await showItemDetails(context, self);
    }
  }

  Future<void> _newFolder() async {
    final folder = await showNewFolderDialog(context, _location);
    if (folder == null || !mounted) return;
    showMessage(context, context.l10n.folderCreated(folder.name));
  }

  Future<void> _onSelectionMenu(
    _SelectionMenu action,
    List<MediaFile> selected,
  ) async {
    switch (action) {
      case _SelectionMenu.rename:
        await _rename(selected.single);
      case _SelectionMenu.compress:
        await compressItems(context, ref, _location, selected);
      case _SelectionMenu.favourite:
        await toggleFavourite(context, ref, selected.single);
      case _SelectionMenu.details:
        await showItemDetails(context, selected.single);
    }
    if (mounted) _clearSelection();
  }

  void _openSearchResult(List<MediaFile> results, MediaFile item) {
    if (item.isFolder) {
      openFolder(context, BrowseLocation.ofFolder(_location.source, item));
      return;
    }
    final files = [
      for (final f in results)
        if (!f.isFolder) f,
    ];
    openViewer(context, files: files, index: files.indexOf(item));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final deepSearch = _searching && _deep && _query.trim().isNotEmpty;
    final ShownListingRef shownRef = (location: _location, query: _query);
    final shown = deepSearch
        ? ref
              .watch(deepSearchProvider(shownRef))
              .whenData(
                (found) => FolderListing(
                  folders: const [],
                  files: [
                    for (final f in found)
                      if (!f.isFolder) f,
                  ],
                ),
              )
        : ref.watch(shownListingProvider(shownRef));
    final deepFolders = deepSearch
        ? [
            for (final f
                in ref.watch(deepSearchProvider(shownRef)).value ??
                    const <MediaFile>[])
              if (f.isFolder) f,
          ]
        : const <MediaFile>[];
    final grid = ref.watch(browseGridProvider);
    final clipboard = ref.watch(clipboardProvider);
    final listing = shown.value;
    final items = [
      if (listing != null)
        for (final folder in listing.folders) folder.asItem(_location),
      ...deepFolders,
      ...?listing?.files,
    ];
    // Only items still on screen count as selected, so an action never
    // touches something the user cannot see.
    final selected = [
      for (final item in items)
        if (_selected.contains(item.key)) item,
    ];
    final selecting = selected.isNotEmpty;
    final allSelected = selecting && selected.length == items.length;

    final PreferredSizeWidget appBar;
    if (selecting) {
      appBar = AppBar(
        leading: IconButton(
          key: const Key('cancel-selection'),
          tooltip: l10n.cancelSelection,
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text(
          l10n.selectedCount(
            selected.length,
            formatCount(selected.length, locale),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('select-all'),
            tooltip: allSelected ? l10n.clearSelection : l10n.selectAll,
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            onPressed: () => setState(
              () => _selected = allSelected
                  ? const {}
                  : {for (final item in items) item.key},
            ),
          ),
          PopupMenuButton<_SelectionMenu>(
            key: const Key('selection-menu'),
            tooltip: l10n.moreActions,
            onSelected: (action) => _onSelectionMenu(action, selected),
            itemBuilder: (_) => [
              if (selected.length == 1)
                PopupMenuItem(
                  value: _SelectionMenu.rename,
                  child: Text(l10n.actionRename),
                ),
              PopupMenuItem(
                value: _SelectionMenu.compress,
                child: Text(l10n.actionCompress),
              ),
              if (selected.length == 1) ...[
                PopupMenuItem(
                  value: _SelectionMenu.favourite,
                  child: Text(
                    ref
                                .read(placesControllerProvider)
                                .value
                                ?.isFavourite(selected.single) ??
                            false
                        ? l10n.removeFavourite
                        : l10n.addFavourite,
                  ),
                ),
                PopupMenuItem(
                  value: _SelectionMenu.details,
                  child: Text(l10n.actionDetails),
                ),
              ],
            ],
          ),
        ],
      );
    } else if (_searching) {
      appBar = AppBar(
        leading: IconButton(
          tooltip: l10n.searchClose,
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeSearch,
        ),
        title: TextField(
          key: const Key('search-field'),
          controller: _search,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: _deep ? l10n.searchDeepHint : l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
        actions: [
          IconButton(
            key: const Key('search-deep'),
            tooltip: _deep ? l10n.searchHereOnly : l10n.searchSubfolders,
            isSelected: _deep,
            icon: const Icon(Icons.account_tree_outlined),
            selectedIcon: const Icon(Icons.account_tree),
            onPressed: () => setState(() => _deep = !_deep),
          ),
        ],
      );
    } else {
      final starred =
          _self != null &&
          (ref.watch(placesControllerProvider).value?.isFavourite(_self!) ??
              false);
      final showHidden = ref.watch(showHiddenProvider);
      appBar = AppBar(
        title: Text(
          _location.isRoot ? _location.source.label(l10n) : _location.path.last,
        ),
        actions: [
          IconButton(
            key: const Key('search'),
            tooltip: l10n.searchTooltip,
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            key: const Key('toggle-view'),
            tooltip: grid ? l10n.viewAsList : l10n.viewAsGrid,
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            onPressed: ref.read(browseGridProvider.notifier).toggle,
          ),
          const _SortMenu(),
          PopupMenuButton<_FolderMenu>(
            key: const Key('folder-menu'),
            tooltip: l10n.moreActions,
            onSelected: _onFolderMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const Key('menu-new-folder'),
                value: _FolderMenu.newFolder,
                child: Text(l10n.newFolderTitle),
              ),
              CheckedPopupMenuItem(
                value: _FolderMenu.showHidden,
                checked: showHidden,
                child: Text(l10n.showHiddenFiles),
              ),
              if (_self != null) ...[
                PopupMenuItem(
                  value: _FolderMenu.favourite,
                  child: Text(
                    starred ? l10n.removeFavourite : l10n.addFavourite,
                  ),
                ),
                PopupMenuItem(
                  value: _FolderMenu.details,
                  child: Text(l10n.actionDetails),
                ),
              ],
            ],
          ),
        ],
        bottom: _Breadcrumb(location: _location),
      );
    }

    return PopScope(
      canPop: !selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selecting) {
          _clearSelection();
        } else {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: appBar,
        body: switch (shown) {
          AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () async {
              ref.read(folderRevisionProvider.notifier).bump();
              await ref.read(folderListingProvider(_location).future);
            },
            child: _Listing(
              location: _location,
              folders: deepSearch
                  ? deepFolders
                  : [
                      for (final folder in value.folders)
                        folder.asItem(_location),
                    ],
              files: value.files,
              showPaths: deepSearch,
              query: _query,
              grid: grid,
              selected: _selected,
              selecting: selecting,
              onOpenFolder: (folder) => deepSearch
                  ? _openSearchResult(items, folder)
                  : openFolder(
                      context,
                      BrowseLocation(
                        source: _location.source,
                        dirId: folder.id,
                        path: [..._location.path, folder.name],
                      ),
                    ),
              onOpenFile: (index) => deepSearch
                  ? _openSearchResult(items, value.files[index])
                  : openViewer(context, files: value.files, index: index),
              onToggle: _toggle,
              onAction: _onItemAction,
            ),
          ),
          AsyncError() => ErrorPanel(
            message: l10n.folderLoadFailed,
            onRetry: () => ref.invalidate(folderListingProvider(_location)),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
        floatingActionButton: selecting || _searching || clipboard != null
            ? null
            : FloatingActionButton(
                key: const Key('new-folder'),
                tooltip: l10n.newFolderTitle,
                onPressed: _newFolder,
                child: const Icon(Icons.create_new_folder_outlined),
              ),
        bottomNavigationBar: selecting
            ? _SelectionBar(
                items: selected,
                onCopy: () {
                  copyToClipboard(context, ref, ClipboardMode.copy, selected);
                  _clearSelection();
                },
                onMove: () {
                  copyToClipboard(context, ref, ClipboardMode.move, selected);
                  _clearSelection();
                },
                onShare: () => shareFiles(context, ref, [
                  for (final item in selected)
                    if (!item.isFolder) item,
                ]),
                onTrash: () async {
                  await trashItems(context, ref, selected);
                  if (mounted) _clearSelection();
                },
              )
            : clipboard != null
            ? PasteBar(clipboard: clipboard, target: _location)
            : null,
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sort = ref.watch(browseSortProvider);
    return PopupMenuButton<BrowseSort>(
      key: const Key('sort'),
      tooltip: l10n.sortTooltip,
      icon: const Icon(Icons.sort),
      initialValue: sort,
      onSelected: ref.read(browseSortProvider.notifier).set,
      itemBuilder: (context) => [
        for (final s in BrowseSort.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == sort,
            child: Text(s.label(l10n)),
          ),
      ],
    );
  }
}

/// The way from the chosen folder down to this one; tap a part to go back
/// up to it.
class _Breadcrumb extends StatelessWidget implements PreferredSizeWidget {
  const _Breadcrumb({required this.location});

  final BrowseLocation location;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = [location.source.label(context.l10n), ...location.path];
    final last = crumbs.length - 1;
    return SizedBox(
      height: preferredSize.height,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Starts at the end: the folder you are in matters most.
          reverse: true,
          child: ConstrainedBox(
            // A short path still starts at the leading edge.
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  for (final (i, crumb) in crumbs.indexed) ...[
                    if (i > 0)
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    TextButton(
                      key: Key('crumb-$i'),
                      onPressed: i == last
                          ? null
                          : () {
                              var levels = last - i;
                              Navigator.of(
                                context,
                              ).popUntil((_) => levels-- <= 0);
                            },
                      child: Text(crumb),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips that limit the listing to one kind of file.
class _TypeFilterBar extends ConsumerWidget {
  const _TypeFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(typeFilterProvider);
    final filter = ref.read(typeFilterProvider.notifier);
    return SizedBox(
      height: 56,
      child: ListView(
        key: const Key('type-filters'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              key: const Key('filter-all'),
              label: Text(l10n.filterAll),
              selected: current == null,
              onSelected: (_) => filter.set(null),
            ),
          ),
          for (final category in FileCategory.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: Key('filter-${category.name}'),
                avatar: Icon(category.icon, size: 18),
                label: Text(category.label(l10n)),
                selected: current == category,
                onSelected: (on) => filter.set(on ? category : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _Listing extends StatelessWidget {
  const _Listing({
    required this.location,
    required this.folders,
    required this.files,
    required this.showPaths,
    required this.query,
    required this.grid,
    required this.selected,
    required this.selecting,
    required this.onOpenFolder,
    required this.onOpenFile,
    required this.onToggle,
    required this.onAction,
  });

  final BrowseLocation location;

  /// Folders as items ([MediaFile.isFolder]).
  final List<MediaFile> folders;
  final List<MediaFile> files;

  /// Search results from sub-folders say where they are.
  final bool showPaths;
  final String query;
  final bool grid;
  final Set<String> selected;
  final bool selecting;
  final ValueChanged<MediaFile> onOpenFolder;
  final ValueChanged<int> onOpenFile;
  final ValueChanged<MediaFile> onToggle;
  final void Function(ItemAction action, MediaFile item) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (folders.isEmpty && files.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _TypeFilterBar()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFolder(
              message: query.trim().isEmpty
                  ? l10n.folderEmpty
                  : l10n.searchNoResults(query.trim()),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _TypeFilterBar()),
        SliverList.builder(
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            return _FolderTile(
              key: ValueKey('folder|${folder.id}'),
              folder: folder,
              showPath: showPaths,
              selected: selected.contains(folder.key),
              selecting: selecting,
              onTap: selecting
                  ? () => onToggle(folder)
                  : () => onOpenFolder(folder),
              onLongPress: () => onToggle(folder),
              onAction: (action) => onAction(action, folder),
            );
          },
        ),
        if (files.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.browseHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 128,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return _FileGridTile(
                  key: ValueKey(file.key),
                  file: file,
                  selected: selected.contains(file.key),
                  onTap: selecting
                      ? () => onToggle(file)
                      : () => onOpenFile(index),
                  onLongPress: () => onToggle(file),
                );
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 96),
            sliver: SliverList.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return _FileListTile(
                  key: ValueKey(file.key),
                  file: file,
                  showPath: showPaths,
                  selected: selected.contains(file.key),
                  selecting: selecting,
                  onTap: selecting
                      ? () => onToggle(file)
                      : () => onOpenFile(index),
                  onLongPress: () => onToggle(file),
                  onAction: (action) => onAction(action, file),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The actions offered for one file or folder.
class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({required this.item, required this.onAction});

  final MediaFile item;
  final ValueChanged<ItemAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final starred =
        ref.watch(placesControllerProvider).value?.isFavourite(item) ?? false;
    PopupMenuItem<ItemAction> entry(ItemAction action, String text) =>
        PopupMenuItem(value: action, child: Text(text));
    return PopupMenuButton<ItemAction>(
      key: ValueKey('menu|${item.name}'),
      tooltip: l10n.fileMenuTooltip(item.name),
      onSelected: onAction,
      itemBuilder: (_) => [
        if (!item.isFolder) ...[
          entry(ItemAction.openWith, l10n.openWith),
          entry(ItemAction.share, l10n.actionShare),
        ],
        entry(ItemAction.copy, l10n.actionCopy),
        entry(ItemAction.move, l10n.actionMove),
        entry(ItemAction.rename, l10n.actionRename),
        entry(ItemAction.compress, l10n.actionCompress),
        if (!item.isFolder && FileCategories.isZip(item.name))
          entry(ItemAction.extract, l10n.actionExtract),
        entry(
          ItemAction.favourite,
          starred ? l10n.removeFavourite : l10n.addFavourite,
        ),
        entry(ItemAction.details, l10n.actionDetails),
        entry(ItemAction.trash, l10n.moveToTrash),
      ],
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({
    required this.folder,
    required this.showPath,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
    super.key,
  });

  final MediaFile folder;
  final bool showPath;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<ItemAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(
      folderStatsProvider.select(
        (s) => s[FolderStats.keyOf(folder.sourceId, folder.relativePath)],
      ),
    );
    final starred =
        ref.watch(placesControllerProvider).value?.isFavourite(folder) ?? false;
    final detail = stats == null
        ? formatDate(folder.modified, locale)
        : l10n.folderStats(
            stats.count,
            formatCount(stats.count, locale),
            formatBytes(stats.bytes, locale),
          );
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: SizedBox.square(
        dimension: 48,
        child: Icon(
          starred ? Icons.folder_special : Icons.folder,
          size: 36,
          color: scheme.primary,
        ),
      ),
      title: Text(folder.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        showPath && folder.folder.isNotEmpty
            ? '${folder.folder.replaceAll('/', ' › ')}\n$detail'
            : detail,
      ),
      trailing: selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              semanticLabel: folder.name,
            )
          : _ItemMenu(item: folder, onAction: onAction),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// A picture of the file where it has one, otherwise an icon for its kind.
class _FilePicture extends StatelessWidget {
  const _FilePicture({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    final kind = ViewKinds.of(name: file.name, mimeType: file.mimeType);
    final category = FileCategories.of(file.name, mimeType: file.mimeType);
    return switch (kind) {
      ViewKind.image ||
      ViewKind.video => FileThumbnail(fileRef: file.ref, type: file.type),
      _ when category == FileCategory.apps => FileThumbnail(
        fileRef: file.ref,
        type: file.type,
      ),
      _ => Center(
        child: Icon(
          category == FileCategory.archives ? category.icon : kind.icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    };
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required this.file,
    required this.showPath,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
    super.key,
  });

  final MediaFile file;
  final bool showPath;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<ItemAction> onAction;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeName;
    final scheme = Theme.of(context).colorScheme;
    final detail =
        '${formatBytes(file.size, locale)} · '
        '${formatDate(file.modified, locale)}';
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: SizedBox.square(
        dimension: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: _FilePicture(file: file),
          ),
        ),
      ),
      title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        showPath && file.folder.isNotEmpty
            ? '${file.folder.replaceAll('/', ' › ')}\n$detail'
            : detail,
      ),
      trailing: selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              semanticLabel: file.name,
            )
          : _ItemMenu(item: file, onAction: onAction),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _FileGridTile extends StatelessWidget {
  const _FileGridTile({
    required this.file,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final MediaFile file;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = formatBytes(file.size, context.localeName);
    return Semantics(
      selected: selected,
      button: true,
      label: '${file.name}, $size',
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(child: _FilePicture(file: file)),
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: ColoredBox(
                    color: scheme.inverseSurface.withValues(alpha: 0.75),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (selected) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 4),
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.check, size: 18, color: scheme.onPrimary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.items,
    required this.onCopy,
    required this.onMove,
    required this.onShare,
    required this.onTrash,
  });

  final List<MediaFile> items;
  final VoidCallback onCopy;
  final VoidCallback onMove;
  final VoidCallback onShare;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final bytes = items.fold(0, (sum, f) => sum + f.size);
    final hasFiles = items.any((item) => !item.isFolder);
    return BottomAppBar(
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.selectedSummary(
                items.length,
                formatCount(items.length, locale),
                formatBytes(bytes, locale),
              ),
              key: const Key('selection-summary'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            key: const Key('browse-copy'),
            tooltip: l10n.actionCopy,
            icon: const Icon(Icons.copy_outlined),
            onPressed: onCopy,
          ),
          IconButton(
            key: const Key('browse-move'),
            tooltip: l10n.actionMove,
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: onMove,
          ),
          IconButton(
            key: const Key('browse-share'),
            tooltip: l10n.actionShare,
            icon: const Icon(Icons.share_outlined),
            onPressed: hasFiles ? onShare : null,
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            key: const Key('browse-trash'),
            tooltip: l10n.moveToTrash,
            icon: const Icon(Icons.delete_outline),
            onPressed: onTrash,
          ),
        ],
      ),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
