import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../access/presentation/storage_access_controller.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../viewer/presentation/file_actions.dart';
import 'browse_controller.dart';

/// How much a folder holds, measured when its details are shown.
final folderSizeProvider = FutureProvider.autoDispose
    .family<FolderSize?, MediaFile>(
      (ref, folder) => ref.read(fileOpsProvider).measure(folder),
    );

/// Shows the properties of a file or a folder in a bottom sheet.
Future<void> showItemDetails(BuildContext context, MediaFile item) {
  if (!item.isFolder) return showFileDetails(context, item);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FolderDetailsSheet(folder: item),
  );
}

class _FolderDetailsSheet extends ConsumerWidget {
  const _FolderDetailsSheet({required this.folder});

  final MediaFile folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final source = ref.watch(
      knownSourcesProvider.select(
        (all) => all.where((s) => s.id == folder.sourceId).firstOrNull,
      ),
    );
    final size = ref.watch(folderSizeProvider(folder));
    final location = [
      ?source?.label(l10n),
      folder.folder,
    ].where((part) => part.isNotEmpty).join(' › ').replaceAll('/', ' › ');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.actionDetails,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            DetailRow(label: l10n.detailName, value: folder.name),
            if (location.isNotEmpty)
              DetailRow(label: l10n.detailFolder, value: location),
            DetailRow(label: l10n.detailType, value: l10n.detailTypeFolder),
            switch (size) {
              AsyncData(:final value?) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DetailRow(
                    label: l10n.detailSize,
                    value: formatBytes(value.bytes, locale),
                  ),
                  DetailRow(
                    label: l10n.detailContains,
                    value: l10n.folderContents(
                      value.files,
                      formatCount(value.files, locale),
                      value.folders,
                      formatCount(value.folders, locale),
                    ),
                  ),
                ],
              ),
              AsyncData() || AsyncError() => DetailRow(
                label: l10n.detailSize,
                value: l10n.folderSizeUnknown,
              ),
              _ => DetailRow(label: l10n.detailSize, value: l10n.measuring),
            },
            DetailRow(
              label: l10n.detailDate,
              value: formatDateTime(folder.modified, locale),
            ),
          ],
        ),
      ),
    );
  }
}
