import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../review/presentation/review_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/share_mime.dart';
import 'viewer_controller.dart';

/// The most files handed to the share sheet in one go; more can make
/// Android refuse the request.
const maxSharedFiles = 100;

/// Hands [file] to another app.
Future<void> openWith(
  BuildContext context,
  WidgetRef ref,
  MediaFile file,
) async {
  final l10n = context.l10n;
  try {
    await ref
        .read(mediaViewerProvider)
        .openExternally(file.sourceId, file.id, file.mimeType);
  } on StorageException catch (e, stack) {
    developer.log('Open with failed', error: e, stackTrace: stack);
    if (!context.mounted) return;
    showMessage(
      context,
      e.error == StorageError.noApp ? l10n.noAppToOpen : l10n.errorGeneric,
    );
  }
}

/// Opens the system share sheet for [files].
Future<void> shareFiles(
  BuildContext context,
  WidgetRef ref,
  List<MediaFile> files,
) async {
  if (files.isEmpty) return;
  final l10n = context.l10n;
  if (files.length > maxSharedFiles) {
    showMessage(context, l10n.shareTooMany(maxSharedFiles));
    return;
  }
  try {
    await ref.read(mediaViewerProvider).share([
      for (final f in files) f.ref,
    ], mimeType: ShareMime.of(files.map((f) => f.mimeType)));
  } on StorageException catch (e, stack) {
    developer.log('Share failed', error: e, stackTrace: stack);
    if (!context.mounted) return;
    showMessage(
      context,
      e.error == StorageError.noApp ? l10n.noAppToOpen : l10n.errorGeneric,
    );
  }
}

/// Shows everything known about [file] in a bottom sheet.
Future<void> showFileDetails(BuildContext context, MediaFile file) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DetailsSheet(file: file),
    );

class _DetailsSheet extends ConsumerWidget {
  const _DetailsSheet({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final source = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.sources.where((x) => x.id == file.sourceId).firstOrNull,
      ),
    );
    final info = ref.watch(mediaInfoProvider(file.ref)).value;
    final folder = [
      ?source?.label(l10n),
      file.folder,
    ].where((part) => part.isNotEmpty).join(' › ').replaceAll('/', ' › ');
    final mime = file.mimeType;
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
            DetailRow(label: l10n.detailName, value: file.name),
            if (folder.isNotEmpty)
              DetailRow(label: l10n.detailFolder, value: folder),
            DetailRow(
              label: l10n.detailSize,
              value: formatBytes(file.size, locale),
            ),
            DetailRow(
              label: l10n.detailDate,
              value: formatDateTime(file.modified, locale),
            ),
            DetailRow(
              label: l10n.detailType,
              value: mime == null
                  ? file.type.label(l10n)
                  : '${file.type.label(l10n)} ($mime)',
            ),
            if (info case MediaInfo(:final width?, :final height?))
              DetailRow(
                label: l10n.detailDimensions,
                value: l10n.dimensions(width, height),
              ),
            if (info?.duration case final duration?)
              DetailRow(
                label: l10n.detailDuration,
                value: formatDuration(duration),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label and its value on one line of a details list.
class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
