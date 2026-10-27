import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';
import '../../review/presentation/media_tile.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/trash_entry.dart';
import 'trash_controller.dart';

/// What is in the trash, with restore and delete-for-good.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  Set<String> _selected = const {};
  bool _busy = false;

  void _toggle(TrashEntry e) => setState(
    () => _selected = _selected.contains(e.id)
        ? ({..._selected}..remove(e.id))
        : {..._selected, e.id},
  );

  Future<void> _restore(List<TrashEntry> entries) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final result = await ref
        .read(trashControllerProvider.notifier)
        .restore(entries);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected = const {};
    });
    final missing = result.failed.where(
      (f) => f.$2 == StorageError.targetMissing,
    );
    showMessage(
      context,
      [
        if (result.done.isNotEmpty) l10n.restored(result.done.length),
        if (missing.isNotEmpty) l10n.restoreFolderGone(missing.length),
        if (result.failed.length > missing.length)
          l10n.restoreFailed(result.failed.length - missing.length),
      ].join(' '),
    );
  }

  Future<void> _delete(List<TrashEntry> entries, {required bool all}) async {
    final l10n = context.l10n;
    final locale = context.localeName;
    final bytes = entries.fold(0, (sum, e) => sum + e.size);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deleteConfirmTitle(
            entries.length,
            formatCount(entries.length, locale),
          ),
        ),
        content: Text(l10n.deleteConfirmBody(formatBytes(bytes, locale))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteForever),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final trash = ref.read(trashControllerProvider.notifier);
    final result = all
        ? await trash.deleteAll()
        : await trash.deleteForever(entries);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected = const {};
    });
    showMessage(
      context,
      [
        l10n.freed(formatBytes(result.bytes, locale)),
        if (result.failed.isNotEmpty) l10n.deleteFailed(result.failed.length),
      ].join(' '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trash = ref.watch(trashControllerProvider);
    final days = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.trashDays ?? AppSettings.defaultTrashDays,
      ),
    );
    final entries = trash.value ?? const <TrashEntry>[];
    final selected = entries.where((e) => _selected.contains(e.id)).toList();
    final allSelected = entries.isNotEmpty && selected.length == entries.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          if (entries.isNotEmpty) ...[
            IconButton(
              tooltip: allSelected ? l10n.clearSelection : l10n.selectAll,
              onPressed: () => setState(
                () => _selected = allSelected
                    ? const {}
                    : {for (final e in entries) e.id},
              ),
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            ),
            TextButton(
              key: const Key('empty-trash'),
              onPressed: _busy ? null : () => _delete(entries, all: true),
              child: Text(l10n.emptyTrash),
            ),
          ],
        ],
      ),
      body: switch (trash) {
        AsyncError() => ErrorPanel(
          onRetry: () => ref.invalidate(trashControllerProvider),
        ),
        AsyncData() when entries.isEmpty => _EmptyTrash(days: days),
        AsyncData() => Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.trashInfo(days),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _TrashTile(
                    key: ValueKey(entry.id),
                    entry: entry,
                    days: days,
                    selected: _selected.contains(entry.id),
                    onTap: _busy ? null : () => _toggle(entry),
                  );
                },
              ),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: selected.isEmpty
          ? null
          : BottomAppBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('delete-selected'),
                      onPressed: _busy
                          ? null
                          : () => _delete(selected, all: false),
                      child: Text(l10n.deleteForever),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('restore-selected'),
                      onPressed: _busy ? null : () => _restore(selected),
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.restoreCount(selected.length)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TrashTile extends ConsumerWidget {
  const _TrashTile({
    required this.entry,
    required this.days,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final TrashEntry entry;
  final int days;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final now = DateTime.now().toUtc();
    final left = entry.expiresAt(Duration(days: days)).difference(now);
    final daysLeft = (left.inHours / 24).ceil().clamp(0, days);
    final folder = entry.relativePath.contains('/')
        ? entry.relativePath.substring(0, entry.relativePath.lastIndexOf('/'))
        : '';
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: SizedBox.square(
        dimension: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: entry.type.hasPicture
                ? FileThumbnail(
                    fileRef: (
                      treeUri: entry.sourceId,
                      fileId: entry.item.fileId,
                    ),
                    type: entry.type,
                  )
                : Icon(entry.type.icon),
          ),
        ),
      ),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$folder · ${formatBytes(entry.size, locale)}\n'
        '${l10n.deletedForGoodIn(daysLeft)}',
      ),
      isThreeLine: true,
      trailing: Checkbox(
        value: selected,
        onChanged: onTap == null ? null : (_) => onTap!(),
        semanticLabel: entry.name,
      ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.trashEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.trashInfo(days), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
