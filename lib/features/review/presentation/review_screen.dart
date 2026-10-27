import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import 'media_tile.dart';
import 'move_to_trash_flow.dart';
import 'preview_screen.dart';
import 'review_controller.dart';

void openReview(BuildContext context, ReviewTarget target) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => ReviewScreen(target: target)));
}

/// A grid of files to pick from. Tap selects, touch and hold previews.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({required this.target, super.key});

  final ReviewTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final files = ref.watch(reviewFilesProvider(target));
    final selected = ref.watch(selectionProvider(target));
    final months = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.oldAfterMonths ?? AppSettings.defaultOldAfterMonths,
      ),
    );
    final allSelected = files.isNotEmpty && selected.length == files.length;
    final title = switch (target) {
      GroupReview(:final group) => group.title(l10n),
      TypeReview(:final type) => type.label(l10n),
    };
    final description = switch (target) {
      GroupReview(:final group) => group.description(
        l10n,
        oldAfterMonths: months,
      ),
      TypeReview() => null,
    };
    final selection = ref.read(selectionProvider(target).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (files.isNotEmpty)
            IconButton(
              key: const Key('select-all'),
              tooltip: allSelected ? l10n.clearSelection : l10n.selectAll,
              onPressed: () =>
                  allSelected ? selection.clear() : selection.selectAll(files),
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            ),
          _SortMenu(target: target),
        ],
      ),
      body: files.isEmpty
          ? _EmptyGroup(message: l10n.reviewEmpty)
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description != null) ...[
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          l10n.reviewHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 128,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return MediaTile(
                        key: ValueKey(file.key),
                        file: file,
                        selected: selected.contains(file.key),
                        onTap: () => selection.toggle(file),
                        onLongPress: () => _preview(context, file),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: selected.isEmpty
          ? null
          // The flow gets this screen's context and ref: the selection bar
          // itself goes away once the files have left the list.
          : _SelectionBar(
              target: target,
              onMove: (files) => moveToTrashFlow(context, ref, files),
            ),
    );
  }

  void _preview(BuildContext context, MediaFile file) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(file: file, target: target),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.target});

  final ReviewTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final order = ref.watch(sortOrderProvider(target));
    return PopupMenuButton<SortOrder>(
      tooltip: l10n.sortTooltip,
      icon: const Icon(Icons.sort),
      initialValue: order,
      onSelected: ref.read(sortOrderProvider(target).notifier).set,
      itemBuilder: (context) => [
        for (final o in SortOrder.values)
          PopupMenuItem(
            value: o,
            child: Text(switch (o) {
              SortOrder.largest => l10n.sortLargest,
              SortOrder.oldest => l10n.sortOldest,
              SortOrder.newest => l10n.sortNewest,
            }),
          ),
      ],
    );
  }
}

class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.target, required this.onMove});

  final ReviewTarget target;
  final ValueChanged<List<MediaFile>> onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final files = ref.watch(selectedFilesProvider(target));
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
          FilledButton.icon(
            key: const Key('move-to-trash'),
            onPressed: files.isEmpty ? null : () => onMove(files),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.moveToTrash),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
