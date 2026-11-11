import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../review/presentation/media_tile.dart';
import '../../review/presentation/move_to_trash_flow.dart';
import '../../review/presentation/review_controller.dart';
import '../../viewer/domain/view_kind.dart';
import '../../viewer/presentation/file_actions.dart';
import '../../viewer/presentation/viewer_screen.dart';
import '../domain/browse_entry.dart';
import 'browse_controller.dart';
import 'rename_dialog.dart';

void openFolder(BuildContext context, BrowseLocation location) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FolderScreen(location: location)),
  );
}

enum _FileAction { openWith, share, rename, details, trash }

/// One folder: its sub-folders and files, with search, sorting, a list or
/// grid, and actions on one file or a selection.
class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({required this.location, super.key});

  final BrowseLocation location;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';
  Set<String> _selected = const {};

  BrowseLocation get _location => widget.location;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(MediaFile file) => setState(
    () => _selected = _selected.contains(file.key)
        ? ({..._selected}..remove(file.key))
        : {..._selected, file.key},
  );

  void _closeSearch() => setState(() {
    _searching = false;
    _query = '';
    _search.clear();
  });

  Future<void> _trash(List<MediaFile> files) async {
    await moveToTrashFlow(context, ref, files);
    if (mounted) setState(() => _selected = const {});
  }

  Future<void> _rename(MediaFile file) async {
    final renamed = await showRenameDialog(context, file);
    if (renamed == null || renamed.name == file.name || !mounted) return;
    showMessage(context, context.l10n.renamed(renamed.name));
  }

  void _onFileAction(_FileAction action, MediaFile file) {
    switch (action) {
      case _FileAction.openWith:
        openWith(context, ref, file);
      case _FileAction.share:
        shareFiles(context, ref, [file]);
      case _FileAction.rename:
        _rename(file);
      case _FileAction.details:
        showFileDetails(context, file);
      case _FileAction.trash:
        _trash([file]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final shown = ref.watch(
      shownListingProvider((location: _location, query: _query)),
    );
    final grid = ref.watch(browseGridProvider);
    final files = shown.value?.files ?? const <MediaFile>[];
    // Only files still on screen count as selected, so an action never
    // touches something the user cannot see.
    final selected = [
      for (final f in files)
        if (_selected.contains(f.key)) f,
    ];
    final selecting = selected.isNotEmpty;
    final allSelected = selecting && selected.length == files.length;

    final PreferredSizeWidget appBar;
    if (selecting) {
      appBar = AppBar(
        leading: IconButton(
          key: const Key('cancel-selection'),
          tooltip: l10n.cancelSelection,
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _selected = const {}),
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
                  : {for (final f in files) f.key},
            ),
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
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
      );
    } else {
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
        ],
        bottom: _Breadcrumb(location: _location),
      );
    }

    return PopScope(
      canPop: !selecting && !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selecting) {
          setState(() => _selected = const {});
        } else {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: appBar,
        body: switch (shown) {
          AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () =>
                ref.refresh(folderListingProvider(_location).future),
            child: _Listing(
              location: _location,
              listing: value,
              query: _query,
              grid: grid,
              selected: _selected,
              selecting: selecting,
              onOpenFolder: (folder) =>
                  openFolder(context, _location.child(folder)),
              onOpenFile: (index) =>
                  openViewer(context, files: value.files, index: index),
              onToggle: _toggle,
              onAction: _onFileAction,
            ),
          ),
          AsyncError() => ErrorPanel(
            message: l10n.folderLoadFailed,
            onRetry: () => ref.invalidate(folderListingProvider(_location)),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
        bottomNavigationBar: selecting
            ? _SelectionBar(
                files: selected,
                onShare: () => shareFiles(context, ref, selected),
                onTrash: () => _trash(selected),
              )
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

class _Listing extends StatelessWidget {
  const _Listing({
    required this.location,
    required this.listing,
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
  final FolderListing listing;
  final String query;
  final bool grid;
  final Set<String> selected;
  final bool selecting;
  final ValueChanged<BrowseFolder> onOpenFolder;
  final ValueChanged<int> onOpenFile;
  final ValueChanged<MediaFile> onToggle;
  final void Function(_FileAction action, MediaFile file) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final files = listing.files;
    if (listing.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
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
        SliverList.builder(
          itemCount: listing.folders.length,
          itemBuilder: (context, index) {
            final folder = listing.folders[index];
            return _FolderTile(
              key: ValueKey('folder|${folder.id}'),
              location: location,
              folder: folder,
              onTap: selecting ? null : () => onOpenFolder(folder),
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
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
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return _FileListTile(
                  key: ValueKey(file.key),
                  file: file,
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

class _FolderTile extends ConsumerWidget {
  const _FolderTile({
    required this.location,
    required this.folder,
    required this.onTap,
    super.key,
  });

  final BrowseLocation location;
  final BrowseFolder folder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final path = location.isRoot
        ? folder.name
        : '${location.relativePath}/${folder.name}';
    final stats = ref.watch(
      folderStatsProvider.select(
        (s) => s[FolderStats.keyOf(location.source.id, path)],
      ),
    );
    return ListTile(
      enabled: onTap != null,
      leading: SizedBox.square(
        dimension: 48,
        child: Icon(
          Icons.folder,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(folder.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        stats == null
            ? formatDate(folder.modified, locale)
            : l10n.folderStats(
                stats.count,
                formatCount(stats.count, locale),
                formatBytes(stats.bytes, locale),
              ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
    return switch (kind) {
      ViewKind.image ||
      ViewKind.video => FileThumbnail(fileRef: file.ref, type: file.type),
      _ => Center(
        child: Icon(
          kind.icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    };
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required this.file,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
    super.key,
  });

  final MediaFile file;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<_FileAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final scheme = Theme.of(context).colorScheme;
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
        '${formatBytes(file.size, locale)} · '
        '${formatDate(file.modified, locale)}',
      ),
      trailing: selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              semanticLabel: file.name,
            )
          : PopupMenuButton<_FileAction>(
              key: ValueKey('menu|${file.name}'),
              tooltip: l10n.fileMenuTooltip(file.name),
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _FileAction.openWith,
                  child: Text(l10n.openWith),
                ),
                PopupMenuItem(
                  value: _FileAction.share,
                  child: Text(l10n.actionShare),
                ),
                PopupMenuItem(
                  value: _FileAction.rename,
                  child: Text(l10n.actionRename),
                ),
                PopupMenuItem(
                  value: _FileAction.details,
                  child: Text(l10n.actionDetails),
                ),
                PopupMenuItem(
                  value: _FileAction.trash,
                  child: Text(l10n.moveToTrash),
                ),
              ],
            ),
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
    required this.files,
    required this.onShare,
    required this.onTrash,
  });

  final List<MediaFile> files;
  final VoidCallback onShare;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final bytes = files.fold(0, (sum, f) => sum + f.size);
    return BottomAppBar(
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.selectedSummary(
                files.length,
                formatCount(files.length, locale),
                formatBytes(bytes, locale),
              ),
              key: const Key('selection-summary'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            key: const Key('browse-share'),
            tooltip: l10n.actionShare,
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
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
