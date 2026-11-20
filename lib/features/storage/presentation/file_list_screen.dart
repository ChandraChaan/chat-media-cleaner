import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../browse/presentation/file_manager_actions.dart';
import '../../media/domain/media_file.dart';
import '../../places/domain/places.dart';
import '../../places/presentation/places_controller.dart';
import '../../review/presentation/media_tile.dart';
import '../../review/presentation/review_controller.dart';
import '../../viewer/domain/view_kind.dart';
import '../../viewer/presentation/file_actions.dart';
import '../../viewer/presentation/viewer_screen.dart';
import '../domain/file_category.dart';
import 'storage_scan_controller.dart';
import 'storage_screen.dart';

/// Which files a [FileListScreen] shows.
sealed class FileListTarget {
  const FileListTarget();

  @override
  bool operator ==(Object other) =>
      other is FileListTarget &&
      other.runtimeType == runtimeType &&
      other.id == id;

  @override
  int get hashCode => id.hashCode;

  String get id;

  /// Whether the list comes from a storage scan.
  bool get needsScan => true;
}

final class CategoryFiles extends FileListTarget {
  const CategoryFiles(this.category);

  final FileCategory category;

  @override
  String get id => 'category:${category.name}';
}

final class LargeFiles extends FileListTarget {
  const LargeFiles();

  @override
  String get id => 'large';
}

/// The extra copies of each duplicate; the oldest copy is never listed.
final class DuplicateFiles extends FileListTarget {
  const DuplicateFiles();

  @override
  String get id => 'duplicates';
}

final class RecentFiles extends FileListTarget {
  const RecentFiles();

  @override
  String get id => 'recent';

  @override
  bool get needsScan => false;
}

/// The files a list shows, or null while a scan is needed first.
final fileListProvider = Provider.autoDispose
    .family<List<MediaFile>?, FileListTarget>((ref, target) {
      switch (target) {
        case RecentFiles():
          final places = ref.watch(placesControllerProvider).value;
          return [
            for (final r in places?.recent ?? const <RecentFile>[]) r.file,
          ];
        case CategoryFiles(:final category):
          return ref.watch(storageReportProvider)?.ofCategory(category);
        case LargeFiles():
          return ref.watch(storageReportProvider)?.largest;
        case DuplicateFiles():
          return ref.watch(storageReportProvider)?.duplicateCopies;
      }
    });

extension FileListTargetLabels on FileListTarget {
  String title(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      CategoryFiles(:final category) => category.label(l10n),
      LargeFiles() => l10n.largeFilesTitle,
      DuplicateFiles() => l10n.duplicateFilesTitle,
      RecentFiles() => l10n.recentTitle,
    };
  }
}

void openFileList(BuildContext context, FileListTarget target) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => FileListScreen(target: target)));

/// A flat list of files from anywhere: one kind of file, the largest
/// files, duplicate copies, or recently opened files. Select to share or
/// move to the trash.
class FileListScreen extends ConsumerStatefulWidget {
  const FileListScreen({required this.target, super.key});

  final FileListTarget target;

  @override
  ConsumerState<FileListScreen> createState() => _FileListScreenState();
}

class _FileListScreenState extends ConsumerState<FileListScreen> {
  Set<String> _selected = const {};

  void _toggle(MediaFile file) => setState(
    () => _selected = _selected.contains(file.key)
        ? ({..._selected}..remove(file.key))
        : {..._selected, file.key},
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final files = ref.watch(fileListProvider(widget.target));
    final shown = files ?? const <MediaFile>[];
    final selected = [
      for (final f in shown)
        if (_selected.contains(f.key)) f,
    ];
    final selecting = selected.isNotEmpty;
    final bytes = shown.fold(0, (sum, f) => sum + f.size);
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selected = const {});
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selecting
              ? IconButton(
                  tooltip: l10n.cancelSelection,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selected = const {}),
                )
              : null,
          title: Text(
            selecting
                ? l10n.selectedCount(
                    selected.length,
                    formatCount(selected.length, locale),
                  )
                : widget.target.title(context),
          ),
          actions: [
            if (shown.isNotEmpty)
              IconButton(
                key: const Key('list-select-all'),
                tooltip: selected.length == shown.length
                    ? l10n.clearSelection
                    : l10n.selectAll,
                icon: Icon(
                  selected.length == shown.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                onPressed: () => setState(
                  () => _selected = selected.length == shown.length
                      ? const {}
                      : {for (final f in shown) f.key},
                ),
              ),
            if (widget.target is RecentFiles && shown.isNotEmpty && !selecting)
              IconButton(
                key: const Key('clear-recent'),
                tooltip: l10n.clearRecent,
                icon: const Icon(Icons.history_toggle_off),
                onPressed: () =>
                    ref.read(placesControllerProvider.notifier).clearRecent(),
              ),
          ],
        ),
        body: switch (files) {
          null => const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: StorageScanCard(),
          ),
          [] => _EmptyList(target: widget.target),
          _ => ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: shown.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.listSummary(
                      shown.length,
                      formatCount(shown.length, locale),
                      formatBytes(bytes, locale),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final file = shown[index - 1];
              return _FileRow(
                key: ValueKey(file.key),
                file: file,
                selected: _selected.contains(file.key),
                selecting: selecting,
                onTap: selecting
                    ? () => _toggle(file)
                    : () => openViewer(context, files: shown, index: index - 1),
                onLongPress: () => _toggle(file),
              );
            },
          ),
        },
        bottomNavigationBar: selecting
            ? BottomAppBar(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.selectedSummary(
                          selected.length,
                          formatCount(selected.length, locale),
                          formatBytes(
                            selected.fold(0, (sum, f) => sum + f.size),
                            locale,
                          ),
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.actionShare,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => shareFiles(context, ref, selected),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      key: const Key('list-trash'),
                      tooltip: l10n.moveToTrash,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await trashItems(context, ref, selected);
                        if (mounted) setState(() => _selected = const {});
                      },
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final MediaFile file;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeName;
    final scheme = Theme.of(context).colorScheme;
    final kind = ViewKinds.of(name: file.name, mimeType: file.mimeType);
    final category = FileCategories.of(file.name, mimeType: file.mimeType);
    final picture =
        kind == ViewKind.image ||
        kind == ViewKind.video ||
        category == FileCategory.apps;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: SizedBox.square(
        dimension: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: picture
                ? FileThumbnail(fileRef: file.ref, type: file.type)
                : Icon(category.icon, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (file.folder.isNotEmpty) file.folder.replaceAll('/', ' › '),
          '${formatBytes(file.size, locale)} · '
              '${formatDate(file.modified, locale)}',
        ].join('\n'),
      ),
      trailing: selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTap(),
              semanticLabel: file.name,
            )
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.target});

  final FileListTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(switch (target) {
              RecentFiles() => l10n.recentEmpty,
              DuplicateFiles() => l10n.noDuplicates,
              _ => l10n.listEmpty,
            }, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
