import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../media/domain/media_file.dart';
import '../../places/presentation/places_controller.dart';
import '../../review/presentation/move_to_trash_flow.dart';
import '../domain/browse_entry.dart';
import '../domain/file_clipboard.dart';
import 'browse_controller.dart';
import 'rename_dialog.dart';

/// Puts [items] on the clipboard, to be pasted into another folder.
void copyToClipboard(
  BuildContext context,
  WidgetRef ref,
  ClipboardMode mode,
  List<MediaFile> items,
) {
  if (items.isEmpty) return;
  ref.read(clipboardProvider.notifier).set(mode, items);
  final l10n = context.l10n;
  showMessage(
    context,
    mode == ClipboardMode.copy
        ? l10n.clipboardCopyHint(items.length)
        : l10n.clipboardMoveHint(items.length),
  );
}

/// Asks for a name and packs [items] into a ZIP archive in [location].
Future<void> compressItems(
  BuildContext context,
  WidgetRef ref,
  BrowseLocation location,
  List<MediaFile> items,
) async {
  final archive = await showCompressDialog(context, location, items);
  if (archive == null || !context.mounted) return;
  showMessage(context, context.l10n.compressed(archive.name));
}

/// Unpacks the ZIP archive [file] into a folder next to it.
Future<void> extractArchive(
  BuildContext context,
  WidgetRef ref,
  MediaFile file,
) async {
  final l10n = context.l10n;
  final folder = await _withProgress(
    context,
    l10n.extracting,
    () => ref.read(fileOpsProvider).extract(file),
  );
  if (!context.mounted) return;
  showMessage(
    context,
    folder == null ? l10n.extractFailed : l10n.extracted(folder.name),
  );
}

/// Stars [item], or takes its star away.
Future<void> toggleFavourite(
  BuildContext context,
  WidgetRef ref,
  MediaFile item,
) async {
  final l10n = context.l10n;
  final places = ref.read(placesControllerProvider.notifier);
  final wasStarred =
      ref.read(placesControllerProvider).value?.isFavourite(item) ?? false;
  await places.toggleFavourite(item);
  if (!context.mounted) return;
  showMessage(
    context,
    wasStarred
        ? l10n.favouriteRemoved(item.name)
        : l10n.favouriteAdded(item.name),
  );
}

/// Moves files and folders to the app's trash, measuring folders first so
/// the confirmation says how much space they take.
Future<void> trashItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaFile> items,
) async {
  final measured = items.any((item) => item.isFolder)
      ? await _withProgress(
          context,
          context.l10n.measuring,
          () => ref.read(fileOpsProvider).withFolderSizes(items),
        )
      : items;
  if (!context.mounted) return;
  await moveToTrashFlow(context, ref, measured);
}

/// Runs [work] behind a dialog that can't be dismissed.
Future<T> _withProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() work,
) async {
  final navigator = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    navigator.pop();
  }
}

/// Shown at the bottom of a folder while items wait on the clipboard: what
/// is waiting, and a button to paste it here.
class PasteBar extends ConsumerStatefulWidget {
  const PasteBar({required this.clipboard, required this.target, super.key});

  final FileClipboard clipboard;
  final BrowseLocation target;

  @override
  ConsumerState<PasteBar> createState() => _PasteBarState();
}

class _PasteBarState extends ConsumerState<PasteBar> {
  int? _done;

  Future<void> _paste() async {
    final l10n = context.l10n;
    final locale = context.localeName;
    final clipboard = widget.clipboard;
    if (clipboard.wouldNestInto(widget.target.source.id, widget.target.dirId)) {
      showMessage(context, l10n.pasteIntoItself);
      return;
    }
    setState(() => _done = 0);
    final result = await ref
        .read(fileOpsProvider)
        .paste(
          clipboard,
          widget.target,
          onProgress: (done, _) {
            if (mounted) setState(() => _done = done);
          },
        );
    if (!mounted) return;
    setState(() => _done = null);
    final count = formatCount(result.done.length, locale);
    final text = clipboard.mode == ClipboardMode.copy
        ? l10n.pastedCopies(result.done.length, count)
        : l10n.pastedMoves(result.done.length, count);
    showMessage(
      context,
      result.failed == 0 ? text : '$text ${l10n.pasteFailed(result.failed)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final clipboard = widget.clipboard;
    final count = formatCount(clipboard.count, locale);
    final done = _done;
    return BottomAppBar(
      child: Row(
        children: [
          Expanded(
            child: done == null
                ? Text(
                    clipboard.mode == ClipboardMode.copy
                        ? l10n.clipboardCopyCount(clipboard.count, count)
                        : l10n.clipboardMoveCount(clipboard.count, count),
                    key: const Key('clipboard-summary'),
                    style: Theme.of(context).textTheme.titleSmall,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.pasteProgress(done, clipboard.count)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: clipboard.count == 0
                            ? null
                            : done / clipboard.count,
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('clipboard-cancel'),
            onPressed: done == null
                ? ref.read(clipboardProvider.notifier).clear
                : null,
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const Key('paste-here'),
            onPressed: done == null ? _paste : null,
            child: Text(
              clipboard.mode == ClipboardMode.copy
                  ? l10n.pasteHere
                  : l10n.moveHere,
            ),
          ),
        ],
      ),
    );
  }
}
