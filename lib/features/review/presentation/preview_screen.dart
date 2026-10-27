import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/widgets.dart';
import '../../../core/format.dart';
import '../../../core/l10n.dart';
import '../../../core/media_labels.dart';
import '../../media/domain/media_file.dart';
import '../../media/domain/media_storage.dart';
import '../../media/domain/media_type.dart';
import 'media_tile.dart';
import 'review_controller.dart';

/// A bigger look at one file, with its details, "open with" and a select
/// switch for the review screen it came from.
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({required this.file, required this.target, super.key});

  final MediaFile file;
  final ReviewTarget target;

  bool get _isPhoto =>
      (file.mimeType?.startsWith('image/') ?? false) &&
      file.mimeType != 'image/gif';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = context.localeName;
    final theme = Theme.of(context);
    final selected = ref.watch(
      selectionProvider(target).select((s) => s.contains(file.key)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(file.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: _isPhoto
                    ? _FullPhoto(file: file)
                    : file.type.hasPicture
                    ? FileThumbnail(fileRef: file.ref, type: file.type)
                    : Center(
                        child: Icon(
                          file.type.icon,
                          size: 96,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Detail(label: l10n.detailFolder, value: file.folder),
                  _Detail(
                    label: l10n.detailSize,
                    value: formatBytes(file.size, locale),
                  ),
                  _Detail(
                    label: l10n.detailDate,
                    value: formatDate(file.modified, locale),
                  ),
                  _Detail(label: l10n.detailType, value: file.type.label(l10n)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _open(context, ref),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.openWith),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('preview-select'),
                        onPressed: () => ref
                            .read(selectionProvider(target).notifier)
                            .toggle(file),
                        icon: Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                        ),
                        label: Text(selected ? l10n.selected : l10n.select),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      await ref
          .read(mediaViewerProvider)
          .openExternally(file.sourceId, file.id, file.mimeType);
    } on StorageException catch (e) {
      if (!context.mounted) return;
      showMessage(
        context,
        e.error == StorageError.noApp ? l10n.noAppToOpen : l10n.errorGeneric,
      );
    }
  }
}

class _FullPhoto extends ConsumerWidget {
  const _FullPhoto({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(previewBytesProvider(file.ref));
    return switch (bytes) {
      AsyncData(:final value) => InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.memory(
            value,
            semanticLabel: file.name,
            errorBuilder: (_, _, _) =>
                FileThumbnail(fileRef: file.ref, type: file.type),
          ),
        ),
      ),
      // Too large or unreadable: the thumbnail still shows what it is.
      AsyncError() => FileThumbnail(fileRef: file.ref, type: file.type),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
