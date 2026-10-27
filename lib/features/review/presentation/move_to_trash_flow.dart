import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../media/domain/media_file.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../trash/presentation/trash_controller.dart';

/// Confirms, moves [files] to the trash with progress, then offers to free
/// the space right away. [context] and [ref] belong to the review screen.
Future<void> moveToTrashFlow(
  BuildContext context,
  WidgetRef ref,
  List<MediaFile> files,
) async {
  final l10n = context.l10n;
  final locale = context.localeName;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final trash = ref.read(trashControllerProvider.notifier);
  final days =
      ref.read(settingsControllerProvider).value?.trashDays ??
      AppSettings.defaultTrashDays;
  final bytes = files.fold(0, (sum, f) => sum + f.size);
  final count = formatCount(files.length, locale);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.moveConfirmTitle(files.length, count)),
      content: Text(l10n.moveConfirmBody(formatBytes(bytes, locale), days)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('confirm-move'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.moveToTrash),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final progress = ValueNotifier<int>(0);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, done, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.movingProgress(done, files.length)),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: done / files.length),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  final result = await trash
      .moveToTrash(files, onProgress: (done, _) => progress.value = done)
      .whenComplete(() {
        navigator.pop();
        progress.dispose();
      });

  if (result.done.isEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.moveFailed(result.failed.length))),
    );
    return;
  }

  if (!context.mounted) return;
  final movedBytes = formatBytes(result.bytes, locale);
  final deleteNow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n.movedTitle(
          result.done.length,
          formatCount(result.done.length, locale),
          movedBytes,
        ),
      ),
      content: Text(
        [
          l10n.movedBody(days),
          if (result.failed.isNotEmpty) l10n.someNotMoved(result.failed.length),
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          key: const Key('keep-in-trash'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.keepInTrash(days)),
        ),
        FilledButton(
          key: const Key('delete-now'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.deleteNow),
        ),
      ],
    ),
  );
  if (deleteNow != true) return;

  final deleted = await trash.deleteForever(result.done);
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.freed(formatBytes(deleted.bytes, locale)))),
  );
}
